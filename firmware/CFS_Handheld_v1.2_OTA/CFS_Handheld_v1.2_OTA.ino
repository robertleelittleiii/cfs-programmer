/*
 * CFS Programmer - ESP32 / ESP32-S3 + PN532
 * Version: 1.3.1
 *
 * Complete firmware with tag read/write capabilities + OTA
 *
 * Board pins are selected automatically from the compile target (FQBN).
 * See BOARD PROFILES below to force a profile when switching hardware.
 *
 * GitHub: srobinson9305/cfs-programmer
 */

#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Update.h>
#include <Adafruit_PN532.h>
#include <U8g2lib.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Adafruit_NeoPixel.h>
#include <AESLib.h>
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════════════
// FIRMWARE VERSION
// ═══════════════════════════════════════════════════════════
#define FIRMWARE_VERSION "1.3.6"
#define FIRMWARE_BUILD_DATE __DATE__
#define FIRMWARE_BUILD_TIME __TIME__

// GitHub release check URL
#define GITHUB_API_URL "https://api.github.com/repos/srobinson9305/cfs-programmer/releases/latest"

AESLib aesLib;

// ═══════════════════════════════════════════════════════════
// BOARD PROFILES
// Pins are picked from the active profile. Default follows FQBN:
//   esp32:esp32:esp32s3:*  -> CFS_BOARD_PROFILE_ESP32S3
//   esp32:esp32:esp32:*    -> CFS_BOARD_PROFILE_ESP32
//
// To override (e.g. test S3 pin map on a classic build), uncomment ONE:
//   #define CFS_FORCE_BOARD_PROFILE CFS_BOARD_PROFILE_ESP32S3
//   #define CFS_FORCE_BOARD_PROFILE CFS_BOARD_PROFILE_ESP32
// ═══════════════════════════════════════════════════════════
#define CFS_BOARD_PROFILE_ESP32S3  1
#define CFS_BOARD_PROFILE_ESP32    2

// IMPORTANT: This MCU is classic ESP32-D0WD (not S3).
// GPIO 6-11 are SPI flash on classic ESP32 — never use 8/9 for I2C or the board
// will fail to boot. GPIO 48 does not exist on classic ESP32.
// Do NOT force the S3 pin profile on this chip.
// #define CFS_FORCE_BOARD_PROFILE CFS_BOARD_PROFILE_ESP32S3
// #define CFS_FORCE_BOARD_PROFILE CFS_BOARD_PROFILE_ESP32

#if defined(CFS_FORCE_BOARD_PROFILE)
  #define CFS_ACTIVE_BOARD_PROFILE CFS_FORCE_BOARD_PROFILE
#elif CONFIG_IDF_TARGET_ESP32S3
  #define CFS_ACTIVE_BOARD_PROFILE CFS_BOARD_PROFILE_ESP32S3
#else
  #define CFS_ACTIVE_BOARD_PROFILE CFS_BOARD_PROFILE_ESP32
#endif

#if CFS_ACTIVE_BOARD_PROFILE == CFS_BOARD_PROFILE_ESP32S3
  #define CFS_BOARD_NAME         "ESP32-S3"
  #define CFS_BOARD_LABEL        "ESP32-S3 + PN532"
  #define CFS_I2C_SDA            8
  #define CFS_I2C_SCL            9
  #define CFS_WS2812_PIN        48
  #define CFS_WS2812_COUNT       1   // single onboard LED; use 8 for NeoPixel ring
  #define CFS_WS2812_BRIGHTNESS 255
  #define CFS_WS2812_PIXEL_TYPE (NEO_GRB + NEO_KHZ800)
  #define CFS_PN532_IRQ         -1
#elif CFS_ACTIVE_BOARD_PROFILE == CFS_BOARD_PROFILE_ESP32
  // GPIO 6-11 are flash pins on classic ESP32 — do not use 8/9 for I2C
  #define CFS_BOARD_NAME         "ESP32"
  #define CFS_BOARD_LABEL        "ESP32 + PN532"
  #define CFS_I2C_SDA           21
  #define CFS_I2C_SCL           22
  #define CFS_WS2812_PIN         4
  #define CFS_WS2812_COUNT       1   // single onboard LED; use 8 for NeoPixel ring
  #define CFS_WS2812_BRIGHTNESS 255
  #define CFS_WS2812_PIXEL_TYPE (NEO_GRB + NEO_KHZ800)
  #define CFS_PN532_IRQ         -1
#else
  #error "Unknown CFS board profile — set CFS_FORCE_BOARD_PROFILE or use a supported FQBN"
#endif

// Optional overrides — uncomment to switch hardware without editing profiles
// #define CFS_WS2812_PIN_OVERRIDE 48
// #define CFS_WS2812_COUNT_OVERRIDE 8

#ifdef CFS_WS2812_PIN_OVERRIDE
#undef CFS_WS2812_PIN
#define CFS_WS2812_PIN CFS_WS2812_PIN_OVERRIDE
#endif

#ifdef CFS_WS2812_COUNT_OVERRIDE
#undef CFS_WS2812_COUNT
#define CFS_WS2812_COUNT CFS_WS2812_COUNT_OVERRIDE
#endif

// Aliases used throughout this sketch
#define I2C_SDA         CFS_I2C_SDA
#define I2C_SCL         CFS_I2C_SCL
#define WS2812_PIN      CFS_WS2812_PIN
#define PN532_IRQ       CFS_PN532_IRQ

// ═══════════════════════════════════════════════════════════
// HARDWARE
// ═══════════════════════════════════════════════════════════
U8G2_SH1106_128X64_NONAME_F_HW_I2C display(U8G2_R0, U8X8_PIN_NONE);
Adafruit_PN532 nfc(PN532_IRQ, -1);
Adafruit_NeoPixel led(CFS_WS2812_COUNT, WS2812_PIN, CFS_WS2812_PIXEL_TYPE);

// ═══════════════════════════════════════════════════════════
// BLE
// ═══════════════════════════════════════════════════════════
BLEServer* pServer = NULL;
BLECharacteristic* txChar = NULL;
BLECharacteristic* rxChar = NULL;
bool bleConnected = false;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TX_CHAR_UUID        "1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e"
#define RX_CHAR_UUID        "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ═══════════════════════════════════════════════════════════
// WiFi Credentials (for OTA updates)
// ═══════════════════════════════════════════════════════════
String wifiSSID = "";
String wifiPassword = "";
bool wifiConfigured = false;

// ═══════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════
enum State { STATE_IDLE, STATE_READING, STATE_WRITING, STATE_UPDATING };
State currentState = STATE_IDLE;

// ═══════════════════════════════════════════════════════════
// AES KEYS (from Creality firmware)
// ═══════════════════════════════════════════════════════════
uint8_t u_key[16] = {113, 51, 98, 117, 94, 116, 49, 110, 113, 102, 90, 40, 112, 102, 36, 49};
uint8_t d_key[16] = {72, 64, 67, 70, 107, 82, 110, 122, 64, 75, 65, 116, 66, 74, 112, 50};

// ═══════════════════════════════════════════════════════════
// GLOBAL UID STORAGE
// ═══════════════════════════════════════════════════════════
uint8_t currentUID[7];
uint8_t currentUIDLength = 0;
uint8_t mifareKey[6];

// ═══════════════════════════════════════════════════════════
// WRITE STATE
// ═══════════════════════════════════════════════════════════
String pendingCFSData = "";
int writeTagCount = 0;
enum WritePhase { WRITE_PHASE_TAG1, WRITE_PHASE_REMOVE, WRITE_PHASE_TAG2 };
WritePhase writePhase = WRITE_PHASE_TAG1;
uint8_t writeTag1UID[7];
uint8_t writeTag1UIDLen = 0;
unsigned long tagAbsentSince = 0;
String rxAccumulator = "";
bool readingSessionReset = false;
bool awaitingWriteData = false;
bool writeSessionReset = false;

#define NOTIFY_Q_SIZE 8
String notifyQueue[NOTIFY_Q_SIZE];
uint8_t notifyQueueCount = 0;

// ═══════════════════════════════════════════════════════════
// LED CONTROL
// ═══════════════════════════════════════════════════════════
enum WS2812Color { WS_OFF, WS_RED, WS_GREEN, WS_BLUE, WS_YELLOW, WS_CYAN, WS_MAGENTA, WS_PURPLE };

static WS2812Color activeLedColor = WS_OFF;
static WS2812Color pendingLedColor = WS_OFF;
static bool ledHardwareReady = false;
static unsigned long bootLedHoldUntil = 0;

#if defined(ESP32)
#include "driver/gpio.h"

// Bit-bang WS2812 — avoids RMT, which BLE holds busy during active connections.
static inline uint32_t ledCycleCount() {
  uint32_t ccount;
  __asm__ __volatile__("rsr %0,ccount" : "=a"(ccount));
  return ccount;
}

static void IRAM_ATTR bitbangWs2812(gpio_num_t pin, const uint8_t* pixels, uint32_t numBytes) {
  const uint32_t time0 = F_CPU / 2500000;  // 0.4us T0H
  const uint32_t time1 = F_CPU / 1250000;  // 0.8us T1H
  const uint32_t period = F_CPU / 800000;  // 1.25us per bit

  const uint8_t* end = pixels + numBytes;
  uint8_t pix = *pixels++;
  uint8_t mask = 0x80;
  uint32_t startTime = 0;

  portDISABLE_INTERRUPTS();
  gpio_set_direction(pin, GPIO_MODE_OUTPUT);

  for (uint32_t t = time0;; t = time0) {
    if (pix & mask) {
      t = time1;
    }
    uint32_t c;
    while (((c = ledCycleCount()) - startTime) < period);
    gpio_set_level(pin, 1);
    startTime = c;
    while (((c = ledCycleCount()) - startTime) < t);
    gpio_set_level(pin, 0);
    if (!(mask >>= 1)) {
      if (pixels >= end) {
        break;
      }
      pix = *pixels++;
      mask = 0x80;
    }
  }

  gpio_set_level(pin, 0);
  portENABLE_INTERRUPTS();
  delayMicroseconds(60);
}
#endif

bool bootLedLocked() {
  return bootLedHoldUntil != 0 && millis() < bootLedHoldUntil;
}

void initLED();

void ledPinWiggleTest() {
  // Slow toggle so a multimeter can see the pin move (proves firmware owns GPIO)
  Serial.print("[LED] Pin wiggle test on GPIO ");
  Serial.println(CFS_WS2812_PIN);
  pinMode(CFS_WS2812_PIN, OUTPUT);
  for (uint8_t i = 0; i < 6; i++) {
    digitalWrite(CFS_WS2812_PIN, HIGH);
    delay(250);
    digitalWrite(CFS_WS2812_PIN, LOW);
    delay(250);
  }
  digitalWrite(CFS_WS2812_PIN, LOW);
}

bool pushLED() {
  if (!ledHardwareReady) {
    initLED();
  }
#if defined(ESP32)
  // GPIO bit-bang works while BLE is connected; RMT show() does not.
  uint8_t* pixels = led.getPixels();
  uint32_t numBytes = led.numPixels() * 3;  // brightness is always 255
  bitbangWs2812((gpio_num_t)CFS_WS2812_PIN, pixels, numBytes);
  return true;
#else
  led.show();
  return true;
#endif
}

void writeLedPixels(WS2812Color color) {
  uint32_t pixel = 0;
  switch (color) {
    case WS_OFF:     pixel = led.Color(0, 0, 0); break;
    case WS_RED:     pixel = led.Color(255, 0, 0); break;
    case WS_GREEN:   pixel = led.Color(0, 255, 0); break;
    case WS_BLUE:    pixel = led.Color(0, 0, 255); break;
    case WS_YELLOW:  pixel = led.Color(255, 255, 0); break;
    case WS_CYAN:    pixel = led.Color(0, 255, 255); break;
    case WS_MAGENTA: pixel = led.Color(255, 0, 255); break;
    case WS_PURPLE:  pixel = led.Color(140, 0, 255); break;
  }
  for (uint16_t i = 0; i < led.numPixels(); i++) {
    led.setPixelColor(i, pixel);
  }
}

bool setLED(WS2812Color color) {
  pendingLedColor = color;
  writeLedPixels(color);
  if (pushLED()) {
    activeLedColor = color;
    pendingLedColor = WS_OFF;
    return true;
  }
  return false;
}

bool forceLedColor(WS2812Color color, uint8_t maxAttempts) {
  for (uint8_t attempt = 0; attempt < maxAttempts; attempt++) {
    if (setLED(color)) {
      return true;
    }
    delay(10);
  }
  return false;
}

void blinkLed(WS2812Color onColor, WS2812Color offColor, uint8_t times, uint16_t onMs, uint16_t offMs) {
  for (uint8_t i = 0; i < times; i++) {
    setLED(onColor);
    delay(onMs);
    setLED(offColor);
    if (i < times - 1) {
      delay(offMs);
    }
  }
}

void signalReadError() {
  blinkLed(WS_RED, WS_OFF, 3, 250, 250);
  setLED(WS_RED);
}

void signalWriteSuccess() {
  blinkLed(WS_GREEN, WS_OFF, 3, 250, 250);
}

void initLED() {
  gpio_reset_pin((gpio_num_t)CFS_WS2812_PIN);
  pinMode(CFS_WS2812_PIN, OUTPUT);
  digitalWrite(CFS_WS2812_PIN, LOW);
  led.setPin(CFS_WS2812_PIN);
  led.updateType(CFS_WS2812_PIXEL_TYPE);
  ledHardwareReady = led.begin();
  led.setBrightness(CFS_WS2812_BRIGHTNESS);
  led.clear();
  pushLED();
  activeLedColor = WS_OFF;
  Serial.print("      LED ready on GPIO ");
  Serial.print(CFS_WS2812_PIN);
  Serial.print(" (");
  Serial.print(led.numPixels());
  Serial.print(" pixels, begin=");
  Serial.println(ledHardwareReady ? "OK" : "FAIL");
}

void ledSelfTest() {
  for (uint16_t i = 0; i < led.numPixels(); i++) {
    led.setPixelColor(i, led.Color(255, 255, 255));
  }
  pushLED();
  delay(400);

  setLED(WS_RED);
  delay(800);
  setLED(WS_GREEN);
  delay(800);
  setLED(WS_BLUE);
  delay(800);
}

void showMessage(String line1, String line2, String line3);

void markBleClientReady(const char* reason) {
  bool wasConnected = bleConnected;
  bleConnected = true;

  if (!wasConnected) {
    Serial.print("✅ BLE client ready (");
    Serial.print(reason);
    Serial.println(")");
  }

  // Mac app considers "connected" only after TX notify is enabled — end boot
  // hold early so we don't stay blue for the full 3s (or forever if onConnect missed).
  if (bootLedHoldUntil != 0) {
    bootLedHoldUntil = 0;
    Serial.println("   Boot LED hold ended — client subscribed");
  }

  if (currentState == STATE_IDLE) {
    if (!forceLedColor(WS_GREEN, 40)) {
      Serial.println("[LED] Could not apply green yet — will keep retrying in loop");
    }
    if (!wasConnected) {
      showMessage("Connected!", "Mac app ready", "");
    }
  }
}

void applyConnectionLED() {
  if (bootLedLocked()) {
    return;
  }
  if (bleConnected) {
    setLED(WS_GREEN);
  } else {
    setLED(WS_BLUE);
  }
}

void endBootLedHoldIfNeeded() {
  if (bootLedHoldUntil == 0 || millis() < bootLedHoldUntil) {
    return;
  }
  bootLedHoldUntil = 0;
  Serial.println("Boot LED hold ended — applying status LED");
  applyConnectionLED();
}

void syncBleConnectionState() {
  if (!pServer) {
    return;
  }

  // Only use count to detect missed connects — onDisconnect handles disconnect.
  // getConnectedCount() is unreliable on ESP32 and was clearing bleConnected
  // right after onConnect, leaving the LED stuck blue.
  bool linked = pServer->getConnectedCount() > 0;
  if (linked && !bleConnected) {
    markBleClientReady("state sync");
  }
}

void updateIdleLED() {
  if (currentState != STATE_IDLE) {
    return;
  }
  if (bootLedLocked()) {
    if (activeLedColor != WS_BLUE) {
      setLED(WS_BLUE);
    }
    return;
  }
  WS2812Color target = bleConnected ? WS_GREEN : WS_BLUE;
  static unsigned long lastRefresh = 0;
  bool pending = (pendingLedColor != WS_OFF && activeLedColor != pendingLedColor);
  bool mismatch = (activeLedColor != target);
  bool due = (millis() - lastRefresh) > 500;
  if (pending || mismatch || due) {
    setLED(target);
    lastRefresh = millis();
  }
}

// Forward declarations
void showMessage(String line1, String line2, String line3);
void notifyMac(String message);
void processNotifyQueue();
void checkForUpdate();
void performOTAUpdate(String firmwareURL);
bool waitForTag();
String readTag();
void writeTag();

// ═══════════════════════════════════════════════════════════
// BLE CALLBACKS
// ═══════════════════════════════════════════════════════════
class NotifyEnableCallbacks: public BLEDescriptorCallbacks {
  void onWrite(BLEDescriptor* pDescriptor) {
    BLE2902* cccd = (BLE2902*)pDescriptor;
    if (cccd->getNotifications() || cccd->getIndications()) {
      Serial.println("📲 TX notify/indicate enabled by client");
      markBleClientReady("CCCD write");
    }
  }
};

class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    Serial.println("✅ BLE Client Connected (GATT link)");

    // ⭐ SEND FIRMWARE VERSION IMMEDIATELY
    String versionMsg = "VERSION:" + String(FIRMWARE_VERSION);
    if (txChar) {
      txChar->setValue(versionMsg.c_str());
      txChar->notify();
      Serial.print("📤 Sent version: ");
      Serial.println(FIRMWARE_VERSION);
    }

    // LED turns green when Mac enables TX notifications (CCCD) — matches Mac app.
    // Don't touch status LED here; onConnect often races ahead of CCCD subscribe.
  }

  void onDisconnect(BLEServer* pServer) {
    bleConnected = false;
    Serial.println("❌ BLE Client Disconnected");
    showMessage("Disconnected", "Waiting", "");
    pServer->startAdvertising();
    Serial.println("🔄 Restarted BLE advertising");
    if (!bootLedLocked()) {
      setLED(WS_BLUE);
    }
  }
};

void clearNotifyQueue() {
  notifyQueueCount = 0;
}

void flushNotifyQueue() {
  while (notifyQueueCount > 0) {
    processNotifyQueue();
  }
}

void processBLECommand(const String& cmd) {
  if (cmd == "READ") {
    currentState = STATE_READING;
    readingSessionReset = true;
    clearNotifyQueue();
    nfc.SAMConfig();
    showMessage("Place tag", "to read", "");
    sendNotifyChunks("READY");

  } else if (cmd == "WRITE") {
    awaitingWriteData = true;
    currentState = STATE_WRITING;
    writeTagCount = 0;
    writePhase = WRITE_PHASE_TAG1;
    writeTag1UIDLen = 0;
    tagAbsentSince = 0;
    writeSessionReset = true;
    pendingCFSData = "";
    rxAccumulator = "";
    clearNotifyQueue();
    nfc.SAMConfig();
    showMessage("Writing...", "Tag 1 of 2", "");
    Serial.println("✍️ WRITE mode - waiting for 48-byte data");

  } else if (cmd.startsWith("WRITE:")) {
    // Legacy single-packet write command
    pendingCFSData = cmd.substring(6);
    if (pendingCFSData.length() != 48) {
      Serial.print("❌ Invalid CFS data length: ");
      Serial.println(pendingCFSData.length());
      sendNotifyChunks("ERROR:Invalid data length");
      return;
    }
    awaitingWriteData = false;
    currentState = STATE_WRITING;
    writeTagCount = 0;
    writePhase = WRITE_PHASE_TAG1;
    writeTag1UIDLen = 0;
    tagAbsentSince = 0;
    writeSessionReset = true;
    clearNotifyQueue();
    nfc.SAMConfig();
    Serial.print("Writing CFS data: ");
    Serial.println(pendingCFSData);
    showMessage("Writing...", "Tag 1 of 2", "");
    sendNotifyChunks("WRITE_READY");

  } else if (cmd == "GET_VERSION") {
    notifyMac("VERSION:" + String(FIRMWARE_VERSION));

  } else if (cmd.startsWith("WIFI_CONFIG:")) {
    String config = cmd.substring(12);
    int commaPos = config.indexOf(',');
    if (commaPos > 0) {
      wifiSSID = config.substring(0, commaPos);
      wifiPassword = config.substring(commaPos + 1);
      wifiConfigured = true;
      Serial.println("WiFi configured: " + wifiSSID);
      notifyMac("WIFI_OK");
    }

  } else if (cmd == "CHECK_UPDATE") {
    checkForUpdate();

  } else if (cmd.startsWith("OTA_UPDATE:")) {
    String firmwareURL = cmd.substring(11);
    performOTAUpdate(firmwareURL);

  } else if (cmd == "CANCEL") {
    currentState = STATE_IDLE;
    readingSessionReset = true;
    writeSessionReset = true;
    awaitingWriteData = false;
    writeTagCount = 0;
    writePhase = WRITE_PHASE_TAG1;
    writeTag1UIDLen = 0;
    tagAbsentSince = 0;
    pendingCFSData = "";
    rxAccumulator = "";
    clearNotifyQueue();
    showMessage("Cancelled", "", "");
  }
}

void completeWriteDataReceive(const String& data) {
  if (data.length() != 48) {
    Serial.print("❌ Invalid write data length: ");
    Serial.println(data.length());
    awaitingWriteData = false;
    currentState = STATE_IDLE;
    sendNotifyChunks("ERROR:Invalid data length");
    return;
  }

  awaitingWriteData = false;
  pendingCFSData = data;
  Serial.print("✅ Write data received: ");
  Serial.println(pendingCFSData);
  sendNotifyChunks("WRITE_READY");
}

void processBLEAccumulator() {
  while (rxAccumulator.length() > 0) {
    if (rxAccumulator == "READ" ||
        rxAccumulator == "WRITE" ||
        rxAccumulator == "GET_VERSION" ||
        rxAccumulator == "CHECK_UPDATE" ||
        rxAccumulator == "CANCEL") {
      String cmd = rxAccumulator;
      rxAccumulator = "";
      processBLECommand(cmd);
      continue;
    }

    if (rxAccumulator.startsWith("WRITE:")) {
      if (rxAccumulator.length() < 54) {
        return;
      }
      String cmd = rxAccumulator.substring(0, 54);
      rxAccumulator = rxAccumulator.substring(54);
      processBLECommand(cmd);
      continue;
    }

    if (rxAccumulator.startsWith("WIFI_CONFIG:")) {
      int commaPos = rxAccumulator.indexOf(',');
      if (commaPos < 0) {
        return;
      }
      int end = rxAccumulator.indexOf('\n', commaPos);
      if (end < 0) {
        end = rxAccumulator.length();
      }
      String cmd = rxAccumulator.substring(0, end);
      rxAccumulator = rxAccumulator.substring(end);
      processBLECommand(cmd);
      continue;
    }

    if (rxAccumulator.startsWith("OTA_UPDATE:")) {
      int end = rxAccumulator.indexOf('\n');
      if (end < 0) {
        return;
      }
      String cmd = rxAccumulator.substring(0, end);
      rxAccumulator = rxAccumulator.substring(end + 1);
      processBLECommand(cmd);
      continue;
    }

    Serial.print("⚠️ Unknown BLE data, clearing: ");
    Serial.println(rxAccumulator);
    rxAccumulator = "";
    break;
  }
}

class RxCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String chunk = String(pCharacteristic->getValue().c_str());
    if (chunk.length() == 0) {
      return;
    }

    markBleClientReady("RX write");

    Serial.print("BLE RX chunk (");
    Serial.print(chunk.length());
    Serial.print("): ");
    Serial.println(chunk);

    // Short commands replace any partial data (e.g. leftover chunks)
    if (chunk == "READ" || chunk == "WRITE" || chunk == "CANCEL" || chunk == "GET_VERSION" || chunk == "CHECK_UPDATE") {
      rxAccumulator = chunk;
      processBLEAccumulator();
      return;
    }

    if (awaitingWriteData) {
      rxAccumulator += chunk;
      Serial.print("   Write data accum (");
      Serial.print(rxAccumulator.length());
      Serial.println("/48)");
      if (rxAccumulator.length() >= 48) {
        String data = rxAccumulator.substring(0, 48);
        rxAccumulator = rxAccumulator.substring(48);
        completeWriteDataReceive(data);
      }
      return;
    }

    rxAccumulator += chunk;
    processBLEAccumulator();
  }
};

void sendNotifyChunks(const String& message) {
  if (!bleConnected || !txChar) {
    return;
  }

  String framed = message + "\n";
  const size_t chunkSize = 20;

  for (size_t offset = 0; offset < framed.length(); offset += chunkSize) {
    size_t len = framed.length() - offset;
    if (len > chunkSize) {
      len = chunkSize;
    }
    String chunk = framed.substring(offset, offset + len);
    txChar->setValue(chunk.c_str());
    txChar->notify();
    if (offset + len < framed.length()) {
      delay(5);
    }
  }

  Serial.print("BLE TX: ");
  Serial.println(message);
}

void notifyMac(String message) {
  if (notifyQueueCount < NOTIFY_Q_SIZE) {
    notifyQueue[notifyQueueCount++] = message;
  } else {
    Serial.println("⚠️ Notify queue full, dropping message");
  }
}

void processNotifyQueue() {
  if (notifyQueueCount == 0) {
    return;
  }

  sendNotifyChunks(notifyQueue[0]);
  for (uint8_t i = 0; i < notifyQueueCount - 1; i++) {
    notifyQueue[i] = notifyQueue[i + 1];
  }
  notifyQueueCount--;
}

// ═══════════════════════════════════════════════════════════
// CFS AES-128-ECB (Creality format — 3 independent 16-byte blocks)
// ═══════════════════════════════════════════════════════════
void cfsAesEncryptBlock(const uint8_t* key, const uint8_t* plain, uint8_t* cipher) {
  AES aes;
  aes.set_key(key, 128);
  aes.encrypt(plain, cipher);
}

void cfsAesDecryptBlock(const uint8_t* key, const uint8_t* cipher, uint8_t* plain) {
  AES aes;
  aes.set_key(key, 128);
  aes.decrypt(cipher, plain);
}

void cfsEncrypt48(const uint8_t* plain, uint8_t* encrypted) {
  for (int i = 0; i < 3; i++) {
    cfsAesEncryptBlock(d_key, plain + (i * 16), encrypted + (i * 16));
  }
}

void cfsDecrypt48(const uint8_t* encrypted, uint8_t* plain) {
  for (int i = 0; i < 3; i++) {
    cfsAesDecryptBlock(d_key, encrypted + (i * 16), plain + (i * 16));
  }
}

bool cfsLooksLikePlaintext(const uint8_t* data) {
  return data[0] == 'A' && data[1] == 'B' && (data[17] == '0' || data[17] == '#');
}

bool cfsFilmIdIsValid(const uint8_t* cfs) {
  for (int i = 11; i < 17; i++) {
    char c = (char)cfs[i];
    if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) {
      return false;
    }
  }
  return true;
}

// ═══════════════════════════════════════════════════════════
// KEY GENERATION FROM UID (using correct AESLib API)
// ═══════════════════════════════════════════════════════════
void generateKeyFromUID(uint8_t* outputKey) {
  Serial.println("🔐 Generating MIFARE key from UID...");

  // Create 16-byte buffer by repeating UID
  uint8_t uid16[16];
  int x = 0;
  for (int i = 0; i < 16; i++) {
    if (x >= currentUIDLength) x = 0;
    uid16[i] = currentUID[x];
    x++;
  }

  // Creality derives MIFARE Key A with AES-128-ECB(u_key, uid×4)
  uint8_t bufOut[16];
  cfsAesEncryptBlock(u_key, uid16, bufOut);

  // Use first 6 bytes as MIFARE key
  memcpy(outputKey, bufOut, 6);

  Serial.print("   MIFARE Key: ");
  for (int i = 0; i < 6; i++) {
    if (outputKey[i] < 0x10) Serial.print("0");
    Serial.print(outputKey[i], HEX);
    Serial.print(" ");
  }
  Serial.println();
}

// ═══════════════════════════════════════════════════════════
// AUTHENTICATION WITH RETRY
// ═══════════════════════════════════════════════════════════
bool authenticateWithRetry(uint8_t block, uint8_t keyNumber, uint8_t* key) {
  const int MAX_RETRIES = 5;

  for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, currentUID, &currentUIDLength, 120);
    delay(10);

    if (nfc.mifareclassic_AuthenticateBlock(currentUID, currentUIDLength, block, keyNumber, key)) {
      return true;
    }

    delay(25);
  }

  return false;
}

// Authenticate sector 1 for read/write. Sets blankTag=true when factory default key worked.
bool authenticateSector1(uint8_t* customKey, bool* blankTag, uint8_t* activeKey, uint8_t* activeKeyNum) {
  uint8_t defaultKey[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
  *blankTag = false;

  auto trySequence = [&](bool slowI2C) -> bool {
    Wire.setClock(slowI2C ? 100000 : 100000);
    delay(5);

    Serial.println(slowI2C ? "🔑 Auth (slow I2C)..." : "🔑 Authenticating...");

    if (authenticateWithRetry(7, 0, defaultKey)) {
      *blankTag = true;
      memcpy(activeKey, defaultKey, 6);
      *activeKeyNum = 0;
      return true;
    }
    if (authenticateWithRetry(7, 0, customKey)) {
      memcpy(activeKey, customKey, 6);
      *activeKeyNum = 0;
      return true;
    }
    if (authenticateWithRetry(7, 1, customKey)) {
      memcpy(activeKey, customKey, 6);
      *activeKeyNum = 1;
      return true;
    }
    if (authenticateWithRetry(7, 1, defaultKey)) {
      *blankTag = true;
      memcpy(activeKey, defaultKey, 6);
      *activeKeyNum = 1;
      return true;
    }
    if (authenticateWithRetry(4, 0, customKey)) {
      memcpy(activeKey, customKey, 6);
      *activeKeyNum = 0;
      return true;
    }
    if (authenticateWithRetry(4, 1, customKey)) {
      memcpy(activeKey, customKey, 6);
      *activeKeyNum = 1;
      return true;
    }
    return false;
  };

  if (trySequence(false)) {
    Serial.println("✅ AUTH OK");
    return true;
  }

  if (trySequence(true)) {
    Serial.println("✅ AUTH OK (slow I2C)");
    return true;
  }

  Serial.println("❌ AUTHENTICATION FAILED");
  return false;
}

// ═══════════════════════════════════════════════════════════
// WAIT FOR TAG
// ═══════════════════════════════════════════════════════════
bool pollTagPresent(uint8_t* uid, uint8_t* uidLen) {
  return nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, uidLen, 50);
}

bool uidsEqual(const uint8_t* a, uint8_t aLen, const uint8_t* b, uint8_t bLen) {
  if (aLen == 0 || bLen == 0 || aLen != bLen) {
    return false;
  }
  return memcmp(a, b, aLen) == 0;
}

void resetWriteSessionState() {
  writeTagCount = 0;
  writePhase = WRITE_PHASE_TAG1;
  writeTag1UIDLen = 0;
  tagAbsentSince = 0;
}

bool waitForTag() {
  bool success = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, currentUID, &currentUIDLength, 100);

  if (!success) {
    return false;
  }

  Serial.println("\n═══════════════════════════════════════");
  Serial.print("✅ TAG DETECTED! UID (");
  Serial.print(currentUIDLength);
  Serial.print(" bytes): ");
  for (uint8_t i = 0; i < currentUIDLength; i++) {
    if (currentUID[i] < 0x10) Serial.print("0");
    Serial.print(currentUID[i], HEX);
    Serial.print(" ");
  }
  Serial.println();
  Serial.println("═══════════════════════════════════════");

  String uidStr = "UID:";
  for (uint8_t i = 0; i < currentUIDLength; i++) {
    if (currentUID[i] < 0x10) uidStr += "0";
    uidStr += String(currentUID[i], HEX);
  }
  notifyMac(uidStr);

  return true;
}

void logHexDump(const char* label, uint8_t* data, int len) {
  Serial.print(label);
  for (int i = 0; i < len; i++) {
    if (data[i] < 0x10) Serial.print("0");
    Serial.print(data[i], HEX);
    Serial.print(" ");
  }
  Serial.println();
}

void dumpCFSFields(const String& cfsData) {
  Serial.println("─── CFS Field Dump ───");
  Serial.print("  Full (48): ");
  Serial.println(cfsData);
  if (cfsData.length() >= 48) {
    Serial.print("  Date:    ");
    Serial.println(cfsData.substring(0, 5));
    Serial.print("  Vendor:  ");
    Serial.println(cfsData.substring(5, 9));
    Serial.print("  Batch:   ");
    Serial.println(cfsData.substring(9, 11));
    Serial.print("  FilmID:  ");
    Serial.println(cfsData.substring(11, 17));
    Serial.print("  Color:   ");
    Serial.println(cfsData.substring(17, 24));
    Serial.print("  Length:  ");
    Serial.println(cfsData.substring(24, 28));
    Serial.print("  Serial:  ");
    Serial.println(cfsData.substring(28, 34));
    Serial.print("  Reserve: ");
    Serial.println(cfsData.substring(34, 48));
  }
  Serial.println("─────────────────────");
}

// ═══════════════════════════════════════════════════════════
// TAG READING (using correct AESLib API)
// ═══════════════════════════════════════════════════════════
String readTag() {
  Serial.println("📖 Reading Creality CFS tag...");

  uint8_t customKey[6];
  generateKeyFromUID(customKey);

  bool blankAuth = false;
  uint8_t activeKey[6];
  uint8_t activeKeyNum = 0;
  if (!authenticateSector1(customKey, &blankAuth, activeKey, &activeKeyNum)) {
    Serial.println("   Did you add #define SLOWDOWN 1?");
    return "ERROR:Auth failed - hold tag steady";
  }

  // Read blocks 4, 5, 6
  Serial.println("📄 Reading data blocks...");

  uint8_t raw[48];
  memset(raw, 0, sizeof(raw));

  for (uint8_t blockNum = 4; blockNum <= 6; blockNum++) {
    uint8_t data[16];

    Serial.print("   Block ");
    Serial.print(blockNum);
    Serial.print(": ");

    bool readSuccess = false;
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        delay(20);
        authenticateWithRetry(7, activeKeyNum, activeKey);
      }

      if (nfc.mifareclassic_ReadDataBlock(blockNum, data)) {
        readSuccess = true;
        break;
      }
    }

    if (!readSuccess) {
      Serial.println("❌ READ FAILED");
      return "ERROR:Read failed on block " + String(blockNum);
    }

    for (int i = 0; i < 16; i++) {
      if (data[i] < 0x10) Serial.print("0");
      Serial.print(data[i], HEX);
      Serial.print(" ");
    }
    Serial.println("✅");

    memcpy(raw + ((blockNum - 4) * 16), data, 16);
  }

  // Detect blank/uninitialized tags before attempting decryption
  bool allZero = true;
  bool allFF = true;
  for (int i = 0; i < 48; i++) {
    if (raw[i] != 0x00) allZero = false;
    if (raw[i] != 0xFF) allFF = false;
  }
  if (allZero || allFF) {
    Serial.println("✅ BLANK TAG DETECTED");
    return "BLANK_TAG";
  }

  logHexDump("   Raw tag data: ", raw, 48);

  uint8_t cfs[48];
  if (cfsLooksLikePlaintext(raw)) {
    Serial.println("   Data appears unencrypted");
    memcpy(cfs, raw, 48);
  } else {
    Serial.println("🔓 Decrypting with d_key (AES-128-ECB)...");
    cfsDecrypt48(raw, cfs);
  }

  logHexDump("   Decrypted:    ", cfs, 48);

  String cfsData;
  cfsData.reserve(48);
  for (int i = 0; i < 48; i++) {
    cfsData += (char)cfs[i];
  }
  dumpCFSFields(cfsData);

  if (cfsData.length() != 48) {
    return "ERROR:Invalid data length";
  }

  // Parse CFS format:
  // [0-4] date  [5-8] vendor  [9-10] batch  [11-16] filmID  [17-23] color
  // [24-27] length  [28-33] serial  [34-47] reserve
  String vendor = cfsData.substring(5, 9);
  String filmID = cfsData.substring(11, 17);
  String color = cfsData.substring(17, 24);
  String length = cfsData.substring(24, 28);
  String serial = cfsData.substring(28, 34);

  if (!cfsFilmIdIsValid(cfs)) {
    Serial.print("❌ Invalid filmID after decrypt: [");
    Serial.print(filmID);
    Serial.println("]");
    return "ERROR:Decrypt failed - filmID=" + filmID;
  }

  // Coarse type label for older Mac apps / serial log only.
  // Mac resolves full product name from film ID + vendor against the material catalog.
  String material = filmID;
  if (filmID == "101001" || filmID == "E00003") material = "PLA";
  else if (filmID == "101002") material = "PETG";
  else if (filmID == "101003") material = "ABS";
  else if (filmID == "101004") material = "TPU";
  else if (filmID == "101005") material = "Nylon";

  int lengthMeters = 0;
  for (int i = 0; i < length.length(); i++) {
    char c = length.charAt(i);
    lengthMeters = lengthMeters * 16;
    if (c >= '0' && c <= '9') lengthMeters += (c - '0');
    else if (c >= 'A' && c <= 'F') lengthMeters += (c - 'A' + 10);
    else if (c >= 'a' && c <= 'f') lengthMeters += (c - 'a' + 10);
  }

  Serial.println("✅ TAG READ COMPLETE!");
  Serial.print("   Vendor:    ");
  Serial.println(vendor);
  Serial.print("   FilmID:    ");
  Serial.println(filmID);
  Serial.print("   Material:  ");
  Serial.println(material);
  Serial.print("   Length:    ");
  Serial.print(lengthMeters);
  Serial.println(" meters");
  String colorHex = color;
  if (colorHex.startsWith("0")) {
    colorHex = colorHex.substring(1);
  }
  colorHex.replace("#", "");
  colorHex.toUpperCase();
  if (colorHex.length() != 6) {
    colorHex = "CCCCCC";
  }

  Serial.print("   Color:     #");
  Serial.println(colorHex);

  // Mac maps ID: + VENDOR: against the material/brand catalog.
  return material + "|" + String(lengthMeters) + "m|#" + colorHex + "|S/N:" + serial
         + "|ID:" + filmID + "|VENDOR:" + vendor;
}

// ═══════════════════════════════════════════════════════════
// TAG WRITING (using correct AESLib API)
// ═══════════════════════════════════════════════════════════
void writeTag() {
  static bool writeUiShown = false;

  if (pendingCFSData.length() != 48) {
    Serial.print("❌ Invalid CFS data length: ");
    Serial.println(pendingCFSData.length());
    notifyMac("ERROR:Invalid data length");
    currentState = STATE_IDLE;
    writeUiShown = false;
    flushNotifyQueue();
    return;
  }

  if (writeTagCount == 1 && writePhase != WRITE_PHASE_TAG2) {
    return;
  }

  if (!writeUiShown) {
    setLED(WS_BLUE);
    if (writeTagCount == 0) {
      showMessage("Tag 1 of 2", "Place tag", "");
    } else {
      showMessage("Tag 2 of 2", "Place tag", "");
    }
    writeUiShown = true;
  }

  if (!waitForTag()) {
    return; // No tag present
  }

  writeUiShown = false;

  if (writeTagCount == 1 &&
      uidsEqual(currentUID, currentUIDLength, writeTag1UID, writeTag1UIDLen)) {
    Serial.println("⚠️  Same tag detected — waiting for tag 2");
    notifyMac("ERROR:Same tag - remove and place tag 2");
    showMessage("Tag 1 OK!", "Place different tag", "");
    setLED(WS_BLUE);
    writeUiShown = false;
    return;
  }

  Serial.println("✅ Tag " + String(writeTagCount + 1) + " detected");

  uint8_t customKey[6];
  generateKeyFromUID(customKey);

  bool blankTag = false;
  uint8_t activeKey[6];
  uint8_t activeKeyNum = 0;
  if (!authenticateSector1(customKey, &blankTag, activeKey, &activeKeyNum)) {
    notifyMac("ERROR:Auth failed - hold tag steady");
    setLED(WS_RED);
    currentState = STATE_IDLE;
    writeUiShown = false;
    flushNotifyQueue();
    return;
  }

  setLED(WS_PURPLE);
  showMessage("Writing...", "Keep tag still", "");

  Serial.println("📝 Writing CFS plaintext:");
  dumpCFSFields(pendingCFSData);

  // Mac app sends 48-byte ASCII CFS string (same format as decrypted read data)
  uint8_t cfsBytes[48];
  for (int i = 0; i < 48; i++) {
    cfsBytes[i] = (uint8_t)pendingCFSData.charAt(i);
  }

  // Encrypt with d_key using Creality AES-128-ECB (3 independent blocks)
  uint8_t encrypted[48];
  cfsEncrypt48(cfsBytes, encrypted);

  // Sanity-check encrypt/decrypt roundtrip before touching the tag
  uint8_t roundtrip[48];
  cfsDecrypt48(encrypted, roundtrip);
  if (!cfsFilmIdIsValid(roundtrip) || memcmp(roundtrip, cfsBytes, 48) != 0) {
    Serial.println("❌ AES roundtrip failed before write");
    logHexDump("   Expected:     ", cfsBytes, 48);
    logHexDump("   Roundtrip:    ", roundtrip, 48);
    notifyMac("ERROR:Encrypt roundtrip failed");
    setLED(WS_RED);
    currentState = STATE_IDLE;
    writeUiShown = false;
    flushNotifyQueue();
    return;
  }

  // Write blocks 4, 5, 6
  bool writeSuccess = true;
  for (int block = 4; block <= 6; block++) {
    Serial.print("✍️ Writing block ");
    Serial.print(block);
    Serial.print("...");

    if (nfc.mifareclassic_WriteDataBlock(block, encrypted + ((block - 4) * 16))) {
      Serial.println(" ✅");
    } else {
      Serial.println(" ❌");
      writeSuccess = false;
      break;
    }
  }

  if (!writeSuccess) {
    notifyMac("ERROR:Write failed");
    setLED(WS_RED);
    currentState = STATE_IDLE;
    writeUiShown = false;
    flushNotifyQueue();
    return;
  }

  logHexDump("   Encrypted:    ", encrypted, 48);

  // Blank tags need sector trailer updated with this tag's UID-derived key
  if (blankTag) {
    Serial.println("🔑 Re-auth before sector trailer update...");
    if (!authenticateWithRetry(7, activeKeyNum, activeKey)) {
      Serial.println("❌ Trailer auth failed");
      notifyMac("ERROR:Trailer auth failed");
      setLED(WS_RED);
      currentState = STATE_IDLE;
      writeUiShown = false;
      flushNotifyQueue();
      return;
    }

    uint8_t trailer[16];
    if (nfc.mifareclassic_ReadDataBlock(7, trailer)) {
      logHexDump("   Trailer before: ", trailer, 16);
      for (int i = 0; i < 6; i++) {
        trailer[i] = customKey[i];
        trailer[10 + i] = customKey[i];
      }
      if (!nfc.mifareclassic_WriteDataBlock(7, trailer)) {
        Serial.println("❌ Failed to write sector trailer");
        notifyMac("ERROR:Trailer write failed");
        setLED(WS_RED);
        currentState = STATE_IDLE;
        writeUiShown = false;
        flushNotifyQueue();
        return;
      }
      logHexDump("   Trailer after:  ", trailer, 16);
      Serial.println("✅ Sector trailer updated with UID key");
    } else {
      Serial.println("❌ Failed to read sector trailer");
      notifyMac("ERROR:Trailer read failed");
      setLED(WS_RED);
      currentState = STATE_IDLE;
      writeUiShown = false;
      flushNotifyQueue();
      return;
    }
  }

  // Verify write by reading back
  Serial.println("🔍 Verifying write...");
  uint8_t verifyKey[6];
  uint8_t verifyKeyNum = activeKeyNum;
  if (blankTag) {
    memcpy(verifyKey, customKey, 6);
    verifyKeyNum = 0;
  } else {
    memcpy(verifyKey, activeKey, 6);
  }
  authenticateWithRetry(7, verifyKeyNum, verifyKey);
  uint8_t verify[48];
  bool verifyOk = true;
  for (int block = 4; block <= 6; block++) {
    uint8_t data[16];
    if (!nfc.mifareclassic_ReadDataBlock(block, data)) {
      verifyOk = false;
      break;
    }
    memcpy(verify + (block - 4) * 16, data, 16);
  }
  if (verifyOk) {
    logHexDump("   Read back:    ", verify, 48);
    if (memcmp(verify, encrypted, 48) != 0) {
      Serial.println("❌ Verify mismatch - ciphertext differs");
      notifyMac("ERROR:Write verify failed");
      setLED(WS_RED);
      currentState = STATE_IDLE;
      writeUiShown = false;
      flushNotifyQueue();
      return;
    }

    uint8_t decrypted[48];
    cfsDecrypt48(verify, decrypted);
    logHexDump("   Decrypted:    ", decrypted, 48);
    dumpCFSFields(String((char*)decrypted).substring(0, 48));

    if (!cfsFilmIdIsValid(decrypted) || memcmp(decrypted, cfsBytes, 48) != 0) {
      Serial.println("❌ Verify decrypt failed - tag data invalid");
      notifyMac("ERROR:Write verify decrypt failed");
      setLED(WS_RED);
      currentState = STATE_IDLE;
      writeUiShown = false;
      flushNotifyQueue();
      return;
    }

    Serial.println("✅ Write verified OK (ciphertext + decrypt)");
  } else {
    Serial.println("❌ Could not read back for verify");
    notifyMac("ERROR:Write verify read failed");
    setLED(WS_RED);
    currentState = STATE_IDLE;
    writeUiShown = false;
    flushNotifyQueue();
    return;
  }

  writeTagCount++;

  if (writeTagCount == 1) {
    memcpy(writeTag1UID, currentUID, currentUIDLength);
    writeTag1UIDLen = currentUIDLength;
    writePhase = WRITE_PHASE_REMOVE;
    tagAbsentSince = 0;

    signalWriteSuccess();
    notifyMac("TAG1_WRITTEN");
    Serial.println("✅ Tag 1 complete!");
    showMessage("Tag 1 OK!", "Remove tag", "");
    setLED(WS_BLUE);
    writeUiShown = false;
    writeSessionReset = true;
  } else {
    signalWriteSuccess();
    setLED(WS_GREEN);
    notifyMac("TAG2_WRITTEN");
    flushNotifyQueue();
    Serial.println("✅ Tag 2 complete! Both tags written!");
    showMessage("Complete!", "Both tags OK", "");
    delay(2000);
    currentState = STATE_IDLE;
    resetWriteSessionState();
    pendingCFSData = "";
    writeUiShown = false;
    showMessage("Ready!", "Waiting", "");
  }
}

// ═══════════════════════════════════════════════════════════
// OTA UPDATE FUNCTIONS (same as before)
// ═══════════════════════════════════════════════════════════
void checkForUpdate() {
  if (!wifiConfigured) {
    notifyMac("ERROR:WiFi not configured");
    return;
  }

  Serial.println("\n🔍 Checking for firmware updates...");
  showMessage("Checking...", "for updates", "");

  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n❌ WiFi connection failed");
    notifyMac("ERROR:WiFi connection failed");
    showMessage("WiFi Error", "Check settings", "");
    WiFi.disconnect();
    return;
  }

  Serial.println("\n✅ WiFi connected");

  HTTPClient http;
  http.begin(GITHUB_API_URL);
  http.addHeader("User-Agent", "CFS-Programmer");

  int httpCode = http.GET();

  if (httpCode == 200) {
    String payload = http.getString();

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (!error) {
      String latestVersion = doc["tag_name"].as<String>();
      latestVersion.replace("fw-v", "");
      latestVersion.replace("v", "");

      String downloadURL = doc["assets"][0]["browser_download_url"].as<String>();

      Serial.print("Current version: ");
      Serial.println(FIRMWARE_VERSION);
      Serial.print("Latest version:  ");
      Serial.println(latestVersion);

      if (latestVersion != String(FIRMWARE_VERSION)) {
        Serial.println("🆕 Update available!");
        notifyMac("UPDATE_AVAILABLE:" + latestVersion + "," + downloadURL);
        showMessage("Update found!", latestVersion, "");
      } else {
        Serial.println("✅ Firmware is up to date");
        notifyMac("UP_TO_DATE");
        showMessage("Up to date", FIRMWARE_VERSION, "");
      }
    } else {
      Serial.println("❌ JSON parsing failed");
      notifyMac("ERROR:JSON parse error");
    }
  } else {
    Serial.print("❌ HTTP error: ");
    Serial.println(httpCode);
    notifyMac("ERROR:GitHub API error");
  }

  http.end();
  WiFi.disconnect();

  delay(3000);
  showMessage("Ready!", "Waiting", "");
}

void performOTAUpdate(String firmwareURL) {
  if (!wifiConfigured) {
    notifyMac("ERROR:WiFi not configured");
    return;
  }

  currentState = STATE_UPDATING;

  Serial.println("\n🔄 Starting OTA update...");
  Serial.print("URL: ");
  Serial.println(firmwareURL);

  showMessage("Updating...", "Please wait", "");
  setLED(WS_MAGENTA);

  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  HTTPClient http;
  http.begin(firmwareURL);

  int httpCode = http.GET();

  if (httpCode == 200) {
    int contentLength = http.getSize();

    Serial.print("Firmware size: ");
    Serial.print(contentLength);
    Serial.println(" bytes");

    bool canBegin = Update.begin(contentLength);

    if (canBegin) {
      WiFiClient *client = http.getStreamPtr();

      size_t written = Update.writeStream(*client);

      if (written == contentLength) {
        Serial.println("✅ Written : " + String(written) + " bytes");
      } else {
        Serial.println("❌ Written only : " + String(written) + "/" + String(contentLength));
      }

      if (Update.end()) {
        if (Update.isFinished()) {
          Serial.println("✅ OTA UPDATE SUCCESSFUL!");
          notifyMac("UPDATE_SUCCESS");
          showMessage("Success!", "Rebooting...", "");
          delay(2000);
          ESP.restart();
        } else {
          Serial.println("❌ Update not finished");
          notifyMac("ERROR:Update incomplete");
        }
      } else {
        Serial.println("❌ Error: " + String(Update.getError()));
        notifyMac("ERROR:Update failed");
      }
    } else {
      Serial.println("❌ Not enough space");
      notifyMac("ERROR:Not enough space");
    }
  } else {
    Serial.println("❌ HTTP error: " + String(httpCode));
    notifyMac("ERROR:Download failed");
  }

  http.end();
  WiFi.disconnect();

  currentState = STATE_IDLE;
  showMessage("Update failed", "Try again", "");
  delay(3000);
  showMessage("Ready!", "Waiting", "");
}

// ═══════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  delay(2000);

  Serial.println("\n\n");
  Serial.println("╔════════════════════════════════════════╗");
  Serial.println("║   CFS Programmer v" + String(FIRMWARE_VERSION) + "               ║");
  Serial.println("║   " + String(CFS_BOARD_LABEL) + "                    ║");
  Serial.print("      Board profile: ");
  Serial.print(CFS_BOARD_NAME);
  Serial.print(" | I2C ");
  Serial.print(CFS_I2C_SDA);
  Serial.print("/");
  Serial.print(CFS_I2C_SCL);
  Serial.print(" | LED ");
  Serial.println(CFS_WS2812_PIN);
  Serial.println("╚════════════════════════════════════════╝");
  Serial.print("Built: ");
  Serial.print(FIRMWARE_BUILD_DATE);
  Serial.print(" ");
  Serial.println(FIRMWARE_BUILD_TIME);
  Serial.println();

  // I2C
  Serial.println("[1/5] Initializing I2C bus...");
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(100000);
  Serial.println("      ✅ I2C ready");

  // OLED
  Serial.println("[2/5] Initializing OLED...");
  display.begin();
  Serial.println("      ✅ OLED ready");
  showMessage("CFS Programmer", "v" + String(FIRMWARE_VERSION), "Booting...");

  // LED first — full color test before BLE advertises (Mac app auto-connects fast)
  Serial.println("[3/5] Initializing RGB LED...");
  ledPinWiggleTest();
  initLED();
  ledSelfTest();

  // PN532
  Serial.println("[4/5] Initializing PN532...");
  nfc.begin();

  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    Serial.println("      ❌ PN532 NOT FOUND — BLE will still start");
    setLED(WS_RED);
    delay(1500);
    showMessage("WARN", "PN532 not found", "BLE active");
  } else {
    Serial.print("      ✅ PN532 v");
    Serial.print((versiondata>>24) & 0xFF, DEC);
    Serial.print('.');
    Serial.println((versiondata>>16) & 0xFF, DEC);
    nfc.SAMConfig();
  }

  // BLE — advertising starts last so boot LED sequence is visible
  Serial.println("[5/5] Initializing BLE...");
  BLEDevice::init("CFS-Programmer");
  BLEDevice::setMTU(517);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  txChar = pService->createCharacteristic(
    TX_CHAR_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  BLE2902* notifyDesc = new BLE2902();
  notifyDesc->setCallbacks(new NotifyEnableCallbacks());
  txChar->addDescriptor(notifyDesc);

  rxChar = pService->createCharacteristic(
    RX_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  rxChar->setCallbacks(new RxCallbacks());

  pService->start();

  initLED();
  setLED(WS_BLUE);
  bootLedHoldUntil = millis() + 3000;

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("      ✅ BLE advertising (blue LED for 3s, then green if connected)");

  Serial.println();
  Serial.println("🎉 READY!");
  showMessage("Ready!", "v" + String(FIRMWARE_VERSION), "Waiting...");
}

// ═══════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════
void loop() {
  endBootLedHoldIfNeeded();
  syncBleConnectionState();

  static unsigned long readingStartTime = 0;
  static unsigned long lastNfcReinit = 0;

  if (currentState == STATE_READING) {
    if (readingSessionReset) {
      readingStartTime = 0;
      readingSessionReset = false;
      lastNfcReinit = 0;
    }

    if (readingStartTime == 0) {
      readingStartTime = millis();
      setLED(WS_BLUE);
      Serial.println("📖 READ mode - place tag");
    }

    if (millis() - readingStartTime > 30000) {
      Serial.println("⏱️  Timeout");
      notifyMac("ERROR:Timeout");
      flushNotifyQueue();
      currentState = STATE_IDLE;
      readingStartTime = 0;
      showMessage("Timeout", "", "");
      delay(2000);
      showMessage("Ready!", "Waiting", "");
      return;
    }

    if (millis() - lastNfcReinit > 2000) {
      nfc.SAMConfig();
      lastNfcReinit = millis();
    }

    if (waitForTag()) {
      readingStartTime = 0;
      setLED(WS_YELLOW);
      showMessage("Reading...", "Please wait", "");

      delay(50);
      nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, currentUID, &currentUIDLength, 100);

      String result = readTag();

      if (result == "BLANK_TAG") {
        setLED(WS_GREEN);
        notifyMac("BLANK_TAG");
        showMessage("Blank tag", "Ready to write", "");
        Serial.println("✅ Blank tag reported to app");
        delay(2000);
      } else if (result.startsWith("ERROR:")) {
        signalReadError();
        notifyMac(result);
        String errMsg = result.substring(6);
        showMessage("Error", errMsg.substring(0, 20), "");
        Serial.print("❌ ");
        Serial.println(result);
        delay(3000);
      } else {
        setLED(WS_GREEN);
        notifyMac("TAG_DATA:" + result);
        showMessage("Success!", "Check Mac app", "");
        Serial.println("✅ Success!");
        delay(2000);
      }

      flushNotifyQueue();
      currentState = STATE_IDLE;
      showMessage("Ready!", "Waiting", "");
    } else {
      delay(5);
    }
  } else if (currentState == STATE_WRITING) {
    static unsigned long writeStartTime = 0;

    if (writeSessionReset) {
      writeStartTime = 0;
      writeSessionReset = false;
    }

    if (pendingCFSData.length() == 48) {
      if (writeStartTime == 0) {
        writeStartTime = millis();
        Serial.println("✍️ Waiting for tag to write...");
      }

      if (millis() - writeStartTime > 60000) {
        Serial.println("⏱️  Write timeout");
        notifyMac("ERROR:Write timeout");
        flushNotifyQueue();
        currentState = STATE_IDLE;
        writeStartTime = 0;
        awaitingWriteData = false;
        pendingCFSData = "";
        resetWriteSessionState();
        setLED(WS_RED);
        showMessage("Timeout", "Place tag sooner", "");
        delay(2000);
        showMessage("Ready!", "Waiting", "");
      } else if (writePhase == WRITE_PHASE_REMOVE) {
        uint8_t uid[7];
        uint8_t uidLen = 0;
        if (pollTagPresent(uid, &uidLen)) {
          tagAbsentSince = 0;
          setLED(WS_BLUE);
          showMessage("Tag 1 OK!", "Remove tag...", "");
        } else {
          if (tagAbsentSince == 0) {
            tagAbsentSince = millis();
          } else if (millis() - tagAbsentSince >= 500) {
            writePhase = WRITE_PHASE_TAG2;
            writeStartTime = millis();
            writeSessionReset = true;
            tagAbsentSince = 0;
            Serial.println("✍️ Tag 1 removed — waiting for tag 2...");
            showMessage("Tag 1 OK!", "Place Tag 2", "");
            setLED(WS_BLUE);
          }
        }
      } else {
        writeTag();
      }
    }

    processNotifyQueue();
  } else {
    processNotifyQueue();
    updateIdleLED();
    delay(100);
  }
}

// ═══════════════════════════════════════════════════════════
// DISPLAY HELPER
// ═══════════════════════════════════════════════════════════
void showMessage(String line1, String line2, String line3) {
  display.clearBuffer();
  display.setFont(u8g2_font_6x10_tr);
  display.drawStr(0, 12, line1.c_str());
  display.drawStr(0, 30, line2.c_str());
  display.drawStr(0, 48, line3.c_str());
  display.sendBuffer();
}
