//
//  ContentView.swift
//  CFS Programmer
//
//  Updated: 2025-12-26
//  Version: 1.3.0
//
//  FIXES:
//  - Updated to use FilamentMaterial instead of old Material struct
//  - Fixed type mismatches with MaterialDatabase
//  - All compilation errors resolved

import SwiftUI
import CoreBluetooth
import Combine

enum BuildConfig {
    static let githubRepo = "srobinson9305/cfs-programmer"
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var db: DatabaseManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            // Sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("CFS Programmer")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding()

                // Connection Status
                ConnectionStatusView()

                Divider()

                // Navigation
                List(selection: $selectedTab) {
                    Label("Dashboard", systemImage: "gauge")
                        .tag(0)
                    Label("Read Tag", systemImage: "doc.text.magnifyingglass")
                        .tag(1)
                    Label("Write Tags", systemImage: "pencil.circle")
                        .tag(2)
                    Label("Materials", systemImage: "doc.text")
                        .tag(3)
                    Label("Settings", systemImage: "gearshape")
                        .tag(4)
                    Label("Debug Log", systemImage: "terminal")
                        .tag(5)
                }
                .listStyle(.sidebar)

                Spacer()

                // Device Status
                if bluetooth.isConnected {
                    DeviceStatusView()
                }
            }
            .frame(width: 250)

            // Main Content
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(selectedTab: $selectedTab)
                case 1:
                    ReadTagView(selectedTab: $selectedTab)
                case 2:
                    WriteTagView()
                case 3:
                    MaterialDatabaseView()
                case 4:
                    SettingsView()
                case 5:
                    DebugLogView()
                default:
                    DashboardView(selectedTab: $selectedTab)
                }
            }
        }
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    @EnvironmentObject var bluetooth: BluetoothManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(bluetooth.isConnected ? Color.green : (bluetooth.isScanning ? Color.orange : Color.gray))
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !bluetooth.isConnected && !bluetooth.isScanning {
                Button("Connect") {
                    bluetooth.startScanning()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    var statusText: String {
        if bluetooth.isConnected {
            return "Connected"
        } else if bluetooth.isScanning {
            return "Scanning..."
        } else {
            return "Disconnected"
        }
    }
}

// MARK: - Device Status View
struct DeviceStatusView: View {
    @EnvironmentObject var bluetooth: BluetoothManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Device Status")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(bluetooth.deviceName)
                        .font(.caption)
                }

                HStack {
                    Image(systemName: "memorychip")
                        .font(.caption2)
                    Text("FW: \(bluetooth.firmwareVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @Binding var selectedTab: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("CFS Programmer")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if bluetooth.isConnected {
                    HStack(spacing: 20) {
                        VStack {
                            Text("Device Connected")
                                .foregroundColor(.green)
                                .font(.headline)
                            Text("Firmware: \(bluetooth.firmwareVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if bluetooth.updateAvailable {
                            Button(action: { selectedTab = 4 }) {
                                Label("Update Available!", systemImage: "arrow.down.circle.fill")
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text("Searching for device...")
                        .foregroundColor(.orange)
                }

                Divider()
                    .padding(.vertical)

                // Quick Actions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    Button(action: { selectedTab = 1 }) {
                        QuickActionCard(
                            title: "Read Tag",
                            icon: "doc.text.magnifyingglass",
                            color: .blue,
                            description: "Scan and decode tag data"
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { selectedTab = 2 }) {
                        QuickActionCard(
                            title: "Write Tags",
                            icon: "pencil.circle",
                            color: .green,
                            description: "Program dual tag set"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                Spacer()
            }
            .padding()
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Read Tag Result
struct CFSReadTagInfo: Equatable {
    /// Raw material field from firmware (coarse type, film ID, or error text).
    let material: String
    /// Resolved product name from catalog (e.g. "Hyper PLA"), else best effort.
    let displayMaterial: String
    /// Resolved brand/vendor name (e.g. "Creality"), else code or "Unknown".
    let displayVendor: String
    /// Polymer type from catalog (e.g. "PLA"), when known.
    let displayType: String?
    /// 6-char RFID film ID when firmware provides `|ID:xxxxxx`.
    let filmID: String?
    /// 4-char RFID vendor code when firmware provides `|VENDOR:xxxx`.
    let vendorCode: String?
    let length: String
    let color: String
    let serial: String
    let isBlank: Bool
    /// Successfully decoded CFS payload (not a blank / error).
    let isValidCFS: Bool
    /// Vendor is official Creality (`0276`) — informational only; Generic tags still work on the printer.
    let isCrealityBrand: Bool

    /// Legacy alias used by older call sites.
    var isCreality: Bool { isCrealityBrand }
}

struct WriteFormSnapshot: Equatable {
    let materialID: String
    let weight: FilamentWeight
    let colorHex: String
    let useCustomSerial: Bool
    let customSerial: String
    let lengthHexOverride: String?
}

struct WritePrefill: Equatable {
    let materialName: String
    let lengthDisplay: String
    let lengthHex: String?
    let colorHex: String
    let serial: String
    let useReadSerial: Bool

    static func from(read info: CFSReadTagInfo) -> WritePrefill {
        if info.isBlank {
            return WritePrefill(
                materialName: "PLA",
                lengthDisplay: FilamentWeight.kilograms1.lengthMeters,
                lengthHex: nil,
                colorHex: "FFFFFF",
                serial: "",
                useReadSerial: false
            )
        }
        let serial = info.serial == "N/A" ? "" : info.serial
        let useSerial = serial.count == 6 && serial.allSatisfy(\.isNumber)
        let meters = Int(info.length.filter(\.isNumber))
        let lengthHex = meters.map { String(format: "%04X", $0) }
        // Prefer film ID for exact catalog match; else resolved/display name; else raw.
        let materialKey = info.filmID ?? info.displayMaterial
        return WritePrefill(
            materialName: materialKey,
            lengthDisplay: info.length,
            lengthHex: lengthHex,
            colorHex: info.color,
            serial: serial,
            useReadSerial: useSerial
        )
    }
}

// MARK: - Read Tag View
struct ReadTagView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var db: DatabaseManager
    @Binding var selectedTab: Int
    @State private var isReading = false
    @State private var tagInfo: CFSReadTagInfo?

    var body: some View {
        VStack(spacing: 20) {
            Text("Read Tag")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Scan and decode CFS tag information")
                .foregroundColor(.secondary)

            Divider()

            if let info = tagInfo {
                ScrollView {
                    VStack(spacing: 20) {
                        if info.isBlank {
                            StatusBanner(
                                icon: "doc",
                                title: "Blank Tag Detected - Ready to Write",
                                color: .blue
                            )
                        } else if !info.isValidCFS {
                            StatusBanner(
                                icon: "exclamationmark.triangle.fill",
                                title: "Could Not Decode CFS Tag",
                                color: .orange
                            )

                            GroupBox {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(info.displayMaterial)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text("This usually means decrypt failed, wrong key, or a non-CFS tag — not that the brand is wrong.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        } else {
                            StatusBanner(
                                icon: "checkmark.circle.fill",
                                title: info.isCrealityBrand
                                    ? "Valid CFS Tag (Creality brand)"
                                    : "Valid CFS Tag (works on Creality printers)",
                                color: .green
                            )

                            GroupBox {
                                VStack(alignment: .leading, spacing: 16) {
                                    InfoRow(label: "Brand / Vendor", value: info.displayVendor)
                                    Divider()
                                    InfoRow(label: "Material", value: info.displayMaterial)
                                    if let type = info.displayType {
                                        Divider()
                                        InfoRow(label: "Type", value: type)
                                    }
                                    if let vendorCode = info.vendorCode {
                                        Divider()
                                        InfoRow(label: "Vendor code", value: vendorCode, mono: true)
                                    }
                                    if let filmID = info.filmID {
                                        Divider()
                                        InfoRow(label: "Film ID", value: filmID, mono: true)
                                    }
                                    Divider()
                                    InfoRow(label: "Length", value: info.length)
                                    Divider()
                                    HStack {
                                        Text("Color:")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        HStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(hex: info.color) ?? .gray)
                                                .frame(width: 30, height: 30)
                                            Text("#\(info.color)")
                                                .font(.system(.body, design: .monospaced))
                                        }
                                    }
                                    Divider()
                                    InfoRow(label: "Serial", value: info.serial, mono: true)
                                }
                                .padding()
                            }

                            if !info.isCrealityBrand {
                                Text("Generic / third-party brand codes are normal. The K2 material database includes Generic TPU, PLA, PETG, etc. — the printer accepts them when the film ID matches a profile.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        if info.isBlank || info.isValidCFS {
                            Button {
                                bluetooth.writePrefill = WritePrefill.from(read: info)
                                selectedTab = 2
                            } label: {
                                Label(
                                    info.isBlank ? "Write Tags" : "Write Tags with This Info",
                                    systemImage: "square.on.square"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }

                        Button("Read Another Tag") {
                            tagInfo = nil
                            isReading = false
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            } else {
                Spacer()

                VStack(spacing: 30) {
                    Image(systemName: isReading ? "wave.3.forward.circle.fill" : "wave.3.forward.circle")
                        .font(.system(size: 80))
                        .foregroundColor(isReading ? .blue : .gray)
                        .symbolEffect(.pulse, isActive: isReading)

                    Text(isReading ? "Waiting for tag..." : "Ready to read")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: startReading) {
                    Label(isReading ? "Reading..." : "Read Tag", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isReading || !bluetooth.isConnected)

                if isReading {
                    Button("Cancel") {
                        isReading = false
                        tagInfo = nil
                        bluetooth.sendCommand("CANCEL")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .padding()
        .onChange(of: bluetooth.messageSequence) { _, _ in
            handleMessage(bluetooth.lastMessage)
        }
    }

    func startReading() {
        isReading = true
        tagInfo = nil
        bluetooth.log("READ", "Starting read — CANCEL then READ")
        // Clear any stale firmware state (e.g. leftover write mode) before reading
        bluetooth.sendCommand("CANCEL")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            bluetooth.sendCommand("READ")
        }
    }

    func handleMessage(_ message: String) {
        bluetooth.log("READ", message)

        // Intermediate status messages from firmware — not final results
        if message == "READY" || message.hasPrefix("UID:") {
            return
        }

        if message == "BLANK_TAG" || message.hasPrefix("BLANK_TAG") {
            tagInfo = CFSReadTagInfo(
                material: "Blank",
                displayMaterial: "Blank",
                displayVendor: "—",
                displayType: nil,
                filmID: nil,
                vendorCode: nil,
                length: "0m",
                color: "CCCCCC",
                serial: "N/A",
                isBlank: true,
                isValidCFS: false,
                isCrealityBrand: false
            )
            isReading = false
            return
        }

        if message.hasPrefix("TAG_DATA:") {
            let data = message.replacingOccurrences(of: "TAG_DATA:", with: "")
            let parts = data.split(separator: "|", omittingEmptySubsequences: false).map(String.init)

            let material = parts.count > 0 ? parts[0] : "Unknown"
            let length = parts.count > 1 ? parts[1] : "?"
            let colorHex = parts.count > 2
                ? parts[2].replacingOccurrences(of: "#", with: "")
                : "CCCCCC"
            let serial = parts.count > 3
                ? parts[3].replacingOccurrences(of: "S/N:", with: "")
                : "N/A"

            // Optional tagged fields: ID:101001  VENDOR:0276
            var filmID: String? = nil
            var vendorCode: String? = nil
            for part in parts.dropFirst(4) {
                let upper = part.uppercased()
                if upper.hasPrefix("ID:") {
                    filmID = String(part.dropFirst(3))
                } else if upper.hasPrefix("VENDOR:") {
                    vendorCode = String(part.dropFirst(7))
                } else if part.count == 6, filmID == nil {
                    filmID = part
                } else if part.count == 4, vendorCode == nil {
                    vendorCode = part
                }
            }
            // Older firmware: material may itself be the film ID
            if filmID == nil, material.count == 6, material.uppercased().allSatisfy(\.isHexDigit) {
                filmID = material
            }

            let resolved = db.resolveMaterial(rawMaterial: material, filmID: filmID)
            let displayMaterial = resolved?.name
                ?? (db.displayName(forReadMaterial: material, filmID: filmID).components(separatedBy: "·").last?
                    .trimmingCharacters(in: .whitespaces) ?? material)
            let displayVendor = db.displayVendor(code: vendorCode, material: resolved)
            let displayType = resolved?.materialType
            let isCrealityBrand = (vendorCode?.uppercased() == "0276")
                || (resolved?.brandId.uppercased() == "0276")
                || displayVendor.caseInsensitiveCompare("Creality") == .orderedSame

            tagInfo = CFSReadTagInfo(
                material: material,
                displayMaterial: displayMaterial,
                displayVendor: displayVendor,
                displayType: displayType,
                filmID: filmID,
                vendorCode: vendorCode,
                length: length,
                color: colorHex,
                serial: serial,
                isBlank: false,
                isValidCFS: true,
                isCrealityBrand: isCrealityBrand
            )
            isReading = false
            return
        }

        if message.hasPrefix("ERROR:") {
            let error = message.replacingOccurrences(of: "ERROR:", with: "")
            tagInfo = CFSReadTagInfo(
                material: error,
                displayMaterial: error,
                displayVendor: "—",
                displayType: nil,
                filmID: nil,
                vendorCode: nil,
                length: "",
                color: "FF0000",
                serial: "",
                isBlank: false,
                isValidCFS: false,
                isCrealityBrand: false
            )
            isReading = false
            return
        }

        if message == "DISCONNECTED" {
            isReading = false
        }
    }
}

// MARK: - Write Tag View
struct WriteTagView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var db: DatabaseManager

    @State private var selectedBrandID: String? = nil
    @State private var selectedMaterialID: String? // Changed from UUID to String
    @State private var prefillNotice = ""
    @State private var selectedWeight: FilamentWeight = .kilograms1
    @State private var selectedColor = Color.white
    @State private var customSerial = ""
    @State private var useCustomSerial = false
    @State private var isWriting = false
    @State private var writeStep = 0
    @State private var generatedSerial = ""
    @State private var cfsDataToWrite = ""
    @State private var writeError = ""
    @State private var writeTimeoutWork: DispatchWorkItem?
    @State private var lengthHexOverride: String?

    private var selectedMaterial: FilamentMaterial? {
        db.database.materials.first(where: { $0.id == selectedMaterialID })
    }

    private var brands: [Brand] {
        db.brandsForPicker()
    }

    /// Materials for the selected brand (all materials if no brand chosen).
    private var materialsForBrand: [FilamentMaterial] {
        let all = db.materialsForPicker()
        guard let brandID = selectedBrandID else { return all }
        return all.filter { $0.brandId == brandID }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Write Dual Tag Set")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Configure and write matching front/back tags")
                .foregroundColor(.secondary)

            Divider()

            if writeStep == 0 {
                if !prefillNotice.isEmpty {
                    StatusBanner(
                        icon: "arrow.down.doc.fill",
                        title: prefillNotice,
                        color: .blue
                    )
                }

                if !writeError.isEmpty {
                    StatusBanner(
                        icon: "exclamationmark.triangle.fill",
                        title: "Write Failed",
                        color: .red
                    )
                    Text(writeError)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                ScrollView {
                    Form {
                        Section("Material") {
                            Picker("Brand / Vendor", selection: $selectedBrandID) {
                                Text("All brands").tag(Optional<String>.none)
                                ForEach(brands) { brand in
                                    Text(brand.name).tag(Optional(brand.id))
                                }
                            }
                            .onChange(of: selectedBrandID) { _, newBrand in
                                // Clear material if it no longer belongs to the brand filter
                                if let mat = selectedMaterial,
                                   let newBrand,
                                   mat.brandId != newBrand {
                                    selectedMaterialID = nil
                                }
                            }

                            Picker("Material", selection: $selectedMaterialID) {
                                Text("Select material...").tag(Optional<String>.none)
                                ForEach(materialsForBrand) { material in
                                    Text("\(material.name) (\(material.materialType))")
                                        .tag(Optional(material.id))
                                }
                            }

                            if db.database.materials.isEmpty {
                                Text("No materials loaded. Open Materials tab or restart the app to seed the K2 catalog.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("\(materialsForBrand.count) materials available\(selectedBrandID == nil ? "" : " for this brand") · \(brands.count) brands")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Section("Specifications") {
                            Picker("Weight", selection: $selectedWeight) {
                                ForEach(FilamentWeight.allCases) { weight in
                                    Text(weight.displayName).tag(weight)
                                }
                            }
                            .onChange(of: selectedWeight) { _, _ in
                                lengthHexOverride = nil
                            }

                            ColorPicker("Color", selection: $selectedColor)

                            Toggle("Use Custom Serial", isOn: $useCustomSerial)

                            if useCustomSerial {
                                TextField("Serial (6 digits)", text: $customSerial)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: customSerial) { _, newValue in
                                        customSerial = String(newValue.prefix(6))
                                    }
                            }
                        }

                        if selectedMaterial != nil {
                            Section("Preview") {
                                VStack(alignment: .leading, spacing: 8) {
                                    InfoRow(label: "Material", value: selectedMaterial?.name ?? "")
                                    // Fixed: FilamentMaterial doesn't have filmamentID directly
                                    InfoRow(label: "Brand", value: selectedMaterial?.brandName ?? "")
                                    InfoRow(label: "Type", value: selectedMaterial?.materialType ?? "")
                                    InfoRow(label: "Weight", value: selectedWeight.displayName)
                                    InfoRow(label: "Length", value: selectedWeight.lengthMeters)
                                    HStack {
                                        Text("Color:")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        HStack {
                                            Circle()
                                                .fill(selectedColor)
                                                .frame(width: 20, height: 20)
                                            Text(selectedColor.toHex() ?? "FFFFFF")
                                                .font(.system(.caption, design: .monospaced))
                                        }
                                    }
                                    if useCustomSerial && customSerial.count == 6 {
                                        InfoRow(label: "Serial", value: customSerial, mono: true)
                                    } else {
                                        InfoRow(label: "Serial", value: "Auto-generated", mono: false)
                                    }
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                }

                HStack(spacing: 12) {
                    Spacer()

                    Button(action: startWriting) {
                        Label("Write Both Tags", systemImage: "square.on.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canWrite)

                    if !canWrite {
                        Text(writeDisabledReason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()

            } else if writeStep < 3 {
                Spacer()

                VStack(spacing: 30) {
                    ProgressView(value: Double(writeStep), total: 2)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 300)

                    Image(systemName: "wave.3.forward.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .symbolEffect(.pulse)

                    Text(writeStepText)
                        .font(.title2)

                    Text(writeInstructionText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Cancel") {
                    writeStep = 0
                    isWriting = false
                    cancelWriteTimeout()
                    bluetooth.sendCommand("CANCEL")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding()

            } else {
                Spacer()

                VStack(spacing: 30) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text("Complete!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Both tags written successfully")
                        .foregroundColor(.secondary)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Material", value: selectedMaterial?.name ?? "")
                            InfoRow(label: "Serial", value: generatedSerial, mono: true)
                        }
                        .padding()
                    }
                    .frame(maxWidth: 400)
                }

                Spacer()

                Button("Write Another Set") {
                    writeStep = 0
                    isWriting = false
                    writeError = ""
                    cancelWriteTimeout()
                    // Keep material/weight/color/serial so Write Both Tags stays enabled
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
        .padding()
        .onAppear {
            applyWritePrefillIfNeeded()
            restoreLastWriteFormIfNeeded()
        }
        .onChange(of: bluetooth.writePrefill) { _, _ in applyWritePrefillIfNeeded() }
        .onChange(of: bluetooth.messageSequence) { _, _ in
            handleMessage(bluetooth.lastMessage)
        }
    }

    func applyWritePrefillIfNeeded() {
        guard let prefill = bluetooth.writePrefill else { return }
        bluetooth.writePrefill = nil

        writeStep = 0
        isWriting = false
        writeError = ""
        cancelWriteTimeout()

        selectedMaterialID = matchMaterialID(for: prefill.materialName)
        selectedWeight = FilamentWeight.from(lengthDisplay: prefill.lengthDisplay)
        lengthHexOverride = prefill.lengthHex
        selectedColor = Color(hex: prefill.colorHex) ?? .white

        if prefill.useReadSerial {
            useCustomSerial = true
            customSerial = prefill.serial
        } else {
            useCustomSerial = false
            customSerial = ""
        }

        prefillNotice = "Loaded from read tag — review settings, then write"
        bluetooth.log("WRITE", "Prefill applied: \(prefill.materialName) \(prefill.lengthDisplay) #\(prefill.colorHex)")
    }

    func matchMaterialID(for materialName: String) -> String? {
        let key = materialName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Film ID (from newer firmware / WritePrefill)
        if let match = db.material(forFilmID: key) {
            selectedBrandID = match.brandId
            return match.id
        }
        // "Brand · Name" display form
        let bareName = key.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? key
        let upper = bareName.uppercased()
        if let match = db.database.materials.first(where: {
            $0.name.uppercased() == upper ||
            $0.materialType.uppercased() == upper
        }) {
            selectedBrandID = match.brandId
            return match.id
        }
        if let match = db.database.materials.first(where: {
            $0.name.uppercased().contains(upper) || upper.contains($0.name.uppercased())
        }) {
            selectedBrandID = match.brandId
            return match.id
        }
        if upper.contains("PLA") {
            if let hyper = db.database.materials.first(where: { $0.id == "01001" }) {
                selectedBrandID = hyper.brandId
                return hyper.id
            }
            return db.database.materials.first(where: { $0.materialType.uppercased() == "PLA" })?.id
        }
        return db.database.materials.first?.id
    }

    var canWrite: Bool {
        if !bluetooth.isConnected { return false }
        if selectedMaterial == nil { return false }
        if useCustomSerial && customSerial.count != 6 { return false }
        return true
    }

    var writeDisabledReason: String {
        if !bluetooth.isConnected { return "Connect to the CFS Programmer first" }
        if selectedMaterial == nil { return "Select a material type above to enable writing" }
        if useCustomSerial && customSerial.count != 6 { return "Enter a 6-digit serial number" }
        return ""
    }

    func restoreLastWriteFormIfNeeded() {
        guard selectedMaterialID == nil, let snap = bluetooth.lastWriteForm else { return }
        guard db.database.materials.contains(where: { $0.id == snap.materialID }) else { return }

        selectedMaterialID = snap.materialID
        selectedWeight = snap.weight
        selectedColor = Color(hex: snap.colorHex) ?? .white
        useCustomSerial = snap.useCustomSerial
        customSerial = snap.customSerial
        lengthHexOverride = snap.lengthHexOverride
        bluetooth.log("WRITE", "Restored last write form settings")
    }

    func saveWriteFormSnapshot() {
        guard let materialID = selectedMaterialID else { return }
        bluetooth.lastWriteForm = WriteFormSnapshot(
            materialID: materialID,
            weight: selectedWeight,
            colorHex: selectedColor.toHex() ?? "#FFFFFF",
            useCustomSerial: useCustomSerial,
            customSerial: customSerial,
            lengthHexOverride: lengthHexOverride
        )
    }

    var writeStepText: String {
        switch writeStep {
        case 1: return "Tag 1 of 2"
        case 2: return "Tag 2 of 2"
        default: return ""
        }
    }

    var writeInstructionText: String {
        switch writeStep {
        case 1: return "Place the first tag on the reader"
        case 2: return "Remove tag 1, then place the second tag on the reader"
        default: return ""
        }
    }

    func startWriting() {
        guard let material = selectedMaterial else { return }

        writeError = ""

        if useCustomSerial && customSerial.count == 6 {
            generatedSerial = customSerial
        } else {
            generatedSerial = generateUniqueSerial()
        }

        cfsDataToWrite = generateCFSData(
            material: material,
            weight: selectedWeight,
            color: selectedColor,
            serial: generatedSerial
        )

        guard cfsDataToWrite.count == 48 else {
            writeError = "Invalid CFS data length (\(cfsDataToWrite.count)/48). Check color format."
            bluetooth.log("ERR", "Bad CFS length \(cfsDataToWrite.count): \(cfsDataToWrite)")
            return
        }

        saveWriteFormSnapshot()

        writeStep = 1
        isWriting = true
        startWriteTimeout()
        bluetooth.log("WRITE", "Sending CFS data: \(cfsDataToWrite)")
        bluetooth.sendCommands(["CANCEL", "WRITE", cfsDataToWrite])
    }

    func startWriteTimeout() {
        writeTimeoutWork?.cancel()
        let work = DispatchWorkItem {
            if isWriting && writeStep < 3 {
                writeError = "Timed out — place tag on reader within 60 seconds"
                writeStep = 0
                isWriting = false
                bluetooth.sendCommand("CANCEL")
            }
        }
        writeTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 90, execute: work)
    }

    func cancelWriteTimeout() {
        writeTimeoutWork?.cancel()
        writeTimeoutWork = nil
    }

    func handleMessage(_ message: String) {
        bluetooth.log("WRITE", message)
        // Intermediate firmware status — not final write results
        if message == "WRITE_READY" || message == "READY" || message.hasPrefix("UID:") || message.hasPrefix("VERSION:") {
            return
        }

        if message == "TAG1_WRITTEN" {
            writeStep = 2
            writeError = ""
            bluetooth.log("WRITE", "Tag 1 done — remove tag, then place tag 2")
            startWriteTimeout()
        } else if message == "TAG2_WRITTEN" {
            writeStep = 3
            isWriting = false
            writeError = ""
            cancelWriteTimeout()
        } else if message.hasPrefix("ERROR:") {
            let error = message.replacingOccurrences(of: "ERROR:", with: "")
            if error.contains("Same tag") {
                writeError = error
                return
            }
            writeError = error
            writeStep = 0
            isWriting = false
            cancelWriteTimeout()
        }
    }

    func generateUniqueSerial() -> String {
        return String(format: "%06d", Int.random(in: 1...999999))
    }

    func generateCFSData(material: FilamentMaterial, weight: FilamentWeight, color: Color, serial: String) -> String {
        let dateCode = formatDateCode()
        // Prefer the material's brand RFID code (Creality=0276, Generic=0000)
        let vendor = CFSFilmID.vendorCode(for: material)
        let unknown = "01"
        // K2 film ID = "1" + material_database base.id (e.g. 01001 → 101001)
        let filmID = CFSFilmID.filmID(for: material)
        let rgb = (color.toHex() ?? "#FFFFFF").replacingOccurrences(of: "#", with: "")
        let colorHex = "0" + rgb
        let length = lengthHexOverride ?? weight.hexLength
        let reserve = "00000000000000"

        return "\(dateCode)\(vendor)\(unknown)\(filmID)\(colorHex)\(length)\(serial)\(reserve)"
    }

    func formatDateCode() -> String {
        let date = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        // Creality 5-char date: AB + hex month + 2-digit day (e.g. ABC21)
        return String(format: "AB%01X%02d", month, day)
    }
}

// MARK: - Material Database View
struct MaterialDatabaseView: View {
    @EnvironmentObject var db: DatabaseManager
    @State private var showingAddMaterial = false
    @State private var materialToEdit: FilamentMaterial?
    @State private var materialToDelete: FilamentMaterial?
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false

    var filteredMaterials: [FilamentMaterial] {
        if searchText.isEmpty {
            return db.database.materials
        }
        return db.database.materials.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.brandName.localizedCaseInsensitiveContains(searchText) ||
            $0.materialType.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Material Database")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showingAddMaterial = true }) {
                    Label("Add Material", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search materials...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.bottom)

            if filteredMaterials.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No materials yet" : "No matching materials")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Text("Click Add Material to create one.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(filteredMaterials.sorted(by: {
                        if $0.brandName.localizedCaseInsensitiveCompare($1.brandName) != .orderedSame {
                            return $0.brandName.localizedCaseInsensitiveCompare($1.brandName) == .orderedAscending
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    })) { material in
                        MaterialRowView(material: material)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                materialToEdit = material
                            }
                            .contextMenu {
                                Button {
                                    materialToEdit = material
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    materialToDelete = material
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    materialToDelete = material
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    materialToEdit = material
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMaterial) {
            MaterialEditorView(mode: .add)
        }
        .sheet(item: $materialToEdit) { material in
            MaterialEditorView(mode: .edit(material))
        }
        .confirmationDialog(
            "Delete Material?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let material = materialToDelete {
                    db.deleteMaterial(id: material.id)
                    materialToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                materialToDelete = nil
            }
        } message: {
            if let material = materialToDelete {
                Text("Are you sure you want to delete \"\(material.name)\"? This cannot be undone.")
            }
        }
    }
}

// MARK: - Material Row
private struct MaterialRowView: View {
    let material: FilamentMaterial

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(material.name)
                    .font(.headline)
                Text("\(material.brandName) · \(material.materialType)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(material.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let primaryColor = material.colors.first {
                    HStack {
                        Circle()
                            .fill(primaryColor.color)
                            .frame(width: 16, height: 16)
                        Text(primaryColor.name)
                            .font(.caption)
                    }
                }
                Text(String(format: "%.2f g/cm³", material.density))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .help("Double-click to edit · Right-click for more options")
    }
}

// MARK: - Material Editor (Add / Edit)
enum MaterialEditorMode {
    case add
    case edit(FilamentMaterial)

    var title: String {
        switch self {
        case .add: return "Add New Material"
        case .edit: return "Edit Material"
        }
    }

    var saveButtonTitle: String {
        switch self {
        case .add: return "Add"
        case .edit: return "Save"
        }
    }

    var existing: FilamentMaterial? {
        if case .edit(let material) = self { return material }
        return nil
    }
}

struct MaterialEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var db: DatabaseManager

    let mode: MaterialEditorMode

    @State private var name = ""
    @State private var selectedBrandID = ""
    @State private var materialType = "PLA"
    @State private var density: Double = 1.24
    @State private var notes = ""

    /// Full type list from the K2 catalog + common extras (not limited to PLA/PETG/ABS…).
    private var materialTypes: [String] {
        let catalog = K2MaterialCatalog.materialTypes
        let extras = ["PLA+", "Nylon", "PC", "HIPS", "PA6-CF", "PA612-CF", "PPS", "PCTG"]
        let fromDB = db.database.materials.map(\.materialType)
        return Array(Set(catalog + extras + fromDB)).sorted()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(mode.title)
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)

                    Picker("Brand", selection: $selectedBrandID) {
                        Text("Select brand...").tag("")
                        ForEach(db.brandsForPicker()) { brand in
                            Text(brand.isOfficial ? "\(brand.name) (Official)" : brand.name)
                                .tag(brand.id)
                        }
                    }

                    Picker("Material Type", selection: $materialType) {
                        ForEach(materialTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .onChange(of: materialType) { _, newType in
                        // When type changes, offer standard density unless user already customized it
                        if case .edit = mode {
                            // Only auto-update density if it still matches a known standard
                            let standards = db.database.densityStandards
                            let matchesStandard = standards.values.contains(where: { abs($0 - density) < 0.001 })
                            if matchesStandard {
                                density = db.getDensityStandard(for: newType)
                            }
                        } else {
                            density = db.getDensityStandard(for: newType)
                        }
                    }

                    HStack {
                        Text("Density (g/cm³)")
                        Spacer()
                        TextField("Density", value: $density, format: .number.precision(.fractionLength(2...3)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if case .edit(let material) = mode {
                    Section("Identity") {
                        LabeledContent("ID", value: material.id)
                        LabeledContent("Created", value: material.createdDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Modified", value: material.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(mode.saveButtonTitle) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .padding()
        .frame(width: 440, height: 520)
        .onAppear {
            loadInitialValues()
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedBrandID.isEmpty && density > 0
    }

    private func loadInitialValues() {
        if let material = mode.existing {
            name = material.name
            selectedBrandID = material.brandId
            materialType = material.materialType
            density = material.density
            notes = material.notes
        } else {
            density = db.getDensityStandard(for: materialType)
            if selectedBrandID.isEmpty, let firstBrand = db.database.brands.first {
                selectedBrandID = firstBrand.id
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedBrandID.isEmpty else { return }

        switch mode {
        case .add:
            let templateSource = "Generic \(materialType)"
            var created = db.createMaterial(
                brandId: selectedBrandID,
                name: trimmedName,
                materialType: materialType,
                templateSource: templateSource
            )
            // Apply density / notes if they differ from defaults
            if abs(created.density - density) > 0.0001 || !notes.isEmpty {
                created.density = density
                created.densitySource = abs(density - db.getDensityStandard(for: materialType)) > 0.0001 ? .custom : .standard
                created.weightOptions = db.calculateWeightOptions(density: density, diameter: created.diameter)
                created.notes = notes
                db.updateMaterial(created)
            }

        case .edit(let original):
            guard var updated = db.getMaterial(id: original.id) else { return }
            let brandChanged = updated.brandId != selectedBrandID
            let densityChanged = abs(updated.density - density) > 0.0001
            let typeChanged = updated.materialType != materialType

            updated.name = trimmedName
            updated.brandId = selectedBrandID
            if let brand = db.getBrand(id: selectedBrandID) {
                updated.brandName = brand.name
            }
            updated.materialType = materialType
            updated.density = density
            updated.densitySource = abs(density - db.getDensityStandard(for: materialType)) > 0.0001 ? .custom : .standard
            updated.notes = notes

            if typeChanged && updated.templateSource.hasPrefix("Generic ") {
                updated.templateSource = "Generic \(materialType)"
                updated.inherits = updated.templateSource
            }

            if densityChanged || typeChanged {
                updated.weightOptions = db.calculateWeightOptions(
                    density: density,
                    diameter: updated.diameter
                )
            }

            // Brand ID is part of identity; keep existing material id even if brand changes
            _ = brandChanged
            db.updateMaterial(updated)
        }

        dismiss()
    }
}

/// Backwards-compatible alias used if anything still references AddMaterialView
struct AddMaterialView: View {
    var body: some View {
        MaterialEditorView(mode: .add)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @AppStorage("wifiSSID") private var wifiSSID = ""
    @AppStorage("wifiPassword") private var wifiPassword = ""

    @State private var showingWiFiConfig = false
    @State private var checkingUpdate = false
    @State private var updateMessage = ""
    @State private var availableVersion = ""
    @State private var downloadURL = ""
    @State private var showingUpdatePrompt = false
    @State private var isUpdating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Divider()

                // Device Info
                GroupBox("Device Information") {
                    VStack(spacing: 12) {
                        InfoRow(label: "Name", value: bluetooth.deviceName)
                        Divider()
                        InfoRow(label: "Firmware", value: bluetooth.firmwareVersion)
                        Divider()
                        InfoRow(label: "Status", value: bluetooth.isConnected ? "Connected" : "Disconnected")
                    }
                    .padding()
                }

                // WiFi Configuration
                GroupBox("WiFi Configuration") {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                            Text("Configure WiFi for OTA updates")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        Button(action: { showingWiFiConfig = true }) {
                            Label(wifiSSID.isEmpty ? "Configure WiFi" : "WiFi: \(wifiSSID)", systemImage: "gear")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }

                // Firmware Update
                GroupBox("Firmware Updates") {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Current: \(bluetooth.firmwareVersion)")
                                    .font(.caption)
                                if bluetooth.updateAvailable {
                                    Text("Update available!")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                        }

                        if !updateMessage.isEmpty {
                            Text(updateMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        HStack {
                            Button(action: checkForUpdate) {
                                Label(checkingUpdate ? "Checking..." : "Check for Updates", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkingUpdate || !bluetooth.isConnected || wifiSSID.isEmpty)

                            if bluetooth.updateAvailable {
                                Button(action: { showingUpdatePrompt = true }) {
                                    Label("Install Update", systemImage: "arrow.down.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding()
                }

                // About
                GroupBox("About") {
                    VStack(spacing: 12) {
                        InfoRow(label: "App Version", value: "1.3.0")
                        Divider()
                        InfoRow(label: "Build Date", value: "2025-12-26")
                    }
                    .padding()
                }
            }
            .padding()
        }
        .frame(maxWidth: 700)
        .sheet(isPresented: $showingWiFiConfig) {
            WiFiConfigView(ssid: $wifiSSID, password: $wifiPassword)
        }
        .alert("Firmware Update Available", isPresented: $showingUpdatePrompt) {
            Button("Cancel", role: .cancel) { }
            Button("Install Now") {
                performUpdate()
            }
        } message: {
            Text("Version \(availableVersion) is available. The device will reboot after the update completes (30-60 seconds).")
        }
        .onChange(of: bluetooth.messageSequence) { _, _ in
            handleUpdateMessage(bluetooth.lastMessage)
        }
        .onChange(of: bluetooth.isConnected) { _, connected in
            if !connected {
                checkingUpdate = false
                isUpdating = false
            }
        }
    }

    func checkForUpdate() {
        guard bluetooth.isConnected else {
            updateMessage = "Connect to the device first"
            return
        }

        checkingUpdate = true
        updateMessage = "Checking GitHub..."

        Task {
            do {
                let release = try await GitHubAPI.latestRelease(repo: BuildConfig.githubRepo)
                let latest = VersionCompare.normalize(release.tag_name)
                let current = VersionCompare.normalize(bluetooth.firmwareVersion)

                let assetURL = release.assets.first(where: { $0.name.lowercased().hasSuffix(".bin") })?.browser_download_url
                            ?? release.assets.first?.browser_download_url
                            ?? ""

                await MainActor.run {
                    checkingUpdate = false

                    if VersionCompare.compare(current, latest) >= 0 {
                        bluetooth.updateAvailable = false
                        availableVersion = latest
                        downloadURL = ""
                        updateMessage = "Firmware is up to date (\(current))"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { updateMessage = "" }
                    } else {
                        availableVersion = latest
                        downloadURL = assetURL
                        bluetooth.updateAvailable = !assetURL.isEmpty
                        updateMessage = assetURL.isEmpty
                            ? "Update exists (\(latest)) but no firmware asset found on the release."
                            : "Update available: \(latest)"
                        showingUpdatePrompt = !assetURL.isEmpty
                    }
                }
            } catch {
                await MainActor.run {
                    checkingUpdate = false
                    bluetooth.updateAvailable = false
                    updateMessage = "GitHub check failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func performUpdate() {
        isUpdating = true
        updateMessage = "Updating firmware..."
        bluetooth.sendCommand("OTA_UPDATE:\(downloadURL)")
    }

    func handleUpdateMessage(_ message: String) {
        if message.hasPrefix("UPDATE_AVAILABLE:") {
            checkingUpdate = false
            let parts = message.replacingOccurrences(of: "UPDATE_AVAILABLE:", with: "").split(separator: ",")
            if parts.count == 2 {
                availableVersion = String(parts[0])
                downloadURL = String(parts[1])
                bluetooth.updateAvailable = true
                updateMessage = "Version \(availableVersion) available!"
                showingUpdatePrompt = true
            }
        } else if message == "UP_TO_DATE" {
            checkingUpdate = false
            bluetooth.updateAvailable = false
            updateMessage = "Firmware is up to date!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                updateMessage = ""
            }
        } else if message == "UPDATE_SUCCESS" {
            isUpdating = false
            updateMessage = "Update successful! Device rebooting..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                updateMessage = ""
                bluetooth.updateAvailable = false
            }
        } else if message.hasPrefix("ERROR:") && (checkingUpdate || isUpdating) {
            checkingUpdate = false
            isUpdating = false
            let error = message.replacingOccurrences(of: "ERROR:", with: "")
            updateMessage = "Error: \(error)"
        } else if message == "DISCONNECTED" && isUpdating {
            checkingUpdate = false
            isUpdating = false
            updateMessage = "Device rebootingâ€¦ waiting to reconnect"
        }
    }
}

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }
    let tag_name: String
    let assets: [Asset]
}

enum VersionCompare {
    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .replacingOccurrences(of: "\0", with: "")
         .replacingOccurrences(of: "v", with: "")
    }

    static func compare(_ a: String, _ b: String) -> Int {
        let pa = normalize(a).split(separator: ".").map { Int($0) ?? 0 }
        let pb = normalize(b).split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)

        for i in 0..<n {
            let va = i < pa.count ? pa[i] : 0
            let vb = i < pb.count ? pb[i] : 0
            if va < vb { return -1 }
            if va > vb { return 1 }
        }
        return 0
    }
}

enum GitHubAPI {
    static func latestRelease(repo: String) async throws -> GitHubRelease {
        let repo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = repo.split(separator: "/")
        guard components.count == 2 else {
            throw NSError(domain: "GitHubAPI", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid repo format. Use: username/repo"])
        }

        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        print("[GitHub] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GitHubAPI", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
        }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("CFSProgrammer-macOS/1.3.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)

            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            print("[GitHub] Response status: \(http.statusCode)")

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                throw NSError(domain: "GitHubAPI", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
            }

            return try JSONDecoder().decode(GitHubRelease.self, from: data)

        } catch let e as URLError {
            let friendly: String
            switch e.code {
            case .notConnectedToInternet:
                friendly = "No internet connection."
            case .cannotFindHost, .cannotConnectToHost:
                friendly = "Cannot reach api.github.com (DNS/VPN/adblock/captive portal)."
            case .timedOut:
                friendly = "Request timed out."
            default:
                friendly = e.localizedDescription
            }
            throw NSError(domain: "GitHubAPI", code: e.code.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: friendly])
        }
    }
}

struct WiFiConfigView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bluetooth: BluetoothManager
    @Binding var ssid: String
    @Binding var password: String

    @State private var tempSSID = ""
    @State private var tempPassword = ""
    @State private var showPassword = false
    @State private var isSaving = false
    @State private var saveMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("WiFi Configuration")
                .font(.title)
                .fontWeight(.bold)

            Text("Required for OTA firmware updates")
                .font(.caption)
                .foregroundColor(.secondary)

            Form {
                Section("Network Settings") {
                    TextField("WiFi Network Name (SSID)", text: $tempSSID)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        if showPassword {
                            TextField("Password", text: $tempPassword)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Password", text: $tempPassword)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .formStyle(.grouped)

            if !saveMessage.isEmpty {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundColor(saveMessage.contains("Success") ? .green : .orange)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: saveWiFiConfig) {
                    Label(isSaving ? "Saving..." : "Save", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tempSSID.isEmpty || tempPassword.isEmpty || isSaving)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 350)
        .onAppear {
            tempSSID = ssid
            tempPassword = password
        }
        .onChange(of: bluetooth.messageSequence) { _, _ in
            if bluetooth.lastMessage == "WIFI_OK" {
                isSaving = false
                saveMessage = "Success! WiFi configured."
                ssid = tempSSID
                password = tempPassword
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dismiss()
                }
            }
        }
    }

    func saveWiFiConfig() {
        guard !tempSSID.isEmpty && !tempPassword.isEmpty else { return }

        isSaving = true
        saveMessage = "Sending to device..."
        bluetooth.sendCommand("WIFI_CONFIG:\(tempSSID),\(tempPassword)")
    }
}

// MARK: - Helper Views
struct StatusBanner: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InfoRow: View {
    let label: String
    let value: String?
    var mono: Bool = false

    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Spacer()
            Text(value ?? "")
                .font(mono ? .system(.body, design: .monospaced) : .body)
        }
    }
}

// MARK: - Data Models
// Note: FilamentMaterial is now defined in Material.swift
// Keeping FilamentWeight enum here for convenience

enum CFSFilmID {
    /// Legacy type → generic Creality film ID map (fallback for custom materials).
    static func from(materialType: String) -> String {
        switch materialType.uppercased() {
        case "PLA": return "101001"
        case "PETG": return "101002"
        case "ABS": return "101003"
        case "TPU": return "101004"
        case "NYLON", "PA": return "101005"
        case "ASA": return "101007"
        default: return "101001"
        }
    }

    /// RFID film ID: K2 uses `"1" + material_database base.id` (5 hex chars → 6).
    /// Firmware rejects non-hex film IDs (`cfsFilmIdIsValid`), so only pure hex is used.
    static func filmID(for material: FilamentMaterial) -> String {
        let candidate = material.baseId.count == 5 ? material.baseId : material.id
        if candidate.count == 5, candidate.uppercased().allSatisfy({ $0.isHexDigit }) {
            return "1" + candidate.uppercased()
        }
        // Custom / non-K2 IDs fall back to type-based generic film IDs
        return from(materialType: material.materialType)
    }

    /// 4-char RFID vendor code from brand id when valid hex, else Creality.
    /// Note: Generic brand uses `0000` in the Mac DB — that is valid hex.
    static func vendorCode(for material: FilamentMaterial) -> String {
        let id = material.brandId.uppercased()
        let hexOK = id.count == 4 && id.allSatisfy { $0.isHexDigit }
        return hexOK ? id : "0276"
    }
}

enum FilamentWeight: String, CaseIterable, Identifiable {
    case grams250 = "250g"
    case grams500 = "500g"
    case grams600 = "600g"
    case grams750 = "750g"
    case kilograms1 = "1kg"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var lengthMeters: String {
        switch self {
        case .grams250: return "82m"
        case .grams500: return "165m"
        case .grams600: return "198m"
        case .grams750: return "247m"
        case .kilograms1: return "330m"
        }
    }

    var hexLength: String {
        switch self {
        case .grams250: return "0082"
        case .grams500: return "0165"
        case .grams600: return "0198"
        case .grams750: return "0247"
        case .kilograms1: return "0330"
        }
    }

    /// Maps decoded tag length (Creality stores hex digits as a decimal meter value).
    static func from(lengthDisplay: String) -> FilamentWeight {
        let digits = lengthDisplay.filter(\.isNumber)
        guard let meters = Int(digits) else { return .kilograms1 }
        switch meters {
        case 0..<150: return .grams250
        case 150..<280: return .grams500
        case 280..<350: return .grams600
        case 350..<700: return .grams750
        default: return .kilograms1
        }
    }
}

// MARK: - Debug Log File
final class DebugLogFileWriter {
    static let shared = DebugLogFileWriter()

    let fileURL: URL
    private let queue = DispatchQueue(label: "cfs.debuglog.file", qos: .utility)
    private let maxFileBytes = 5 * 1024 * 1024

    private init() {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/CFS Programmer", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        fileURL = logsDir.appendingPathComponent("debug.log")
        writeSessionHeader()
    }

    private func writeSessionHeader() {
        queue.async {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let header = "\n========== Session \(formatter.string(from: Date())) ==========\n"
            self.appendUnlocked(header)
        }
    }

    func append(_ line: String) {
        queue.async {
            self.appendUnlocked(line + "\n")
            self.rotateIfNeeded()
        }
    }

    private func appendUnlocked(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int,
              size > maxFileBytes else { return }
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("debug.old.log")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        appendUnlocked("========== Log rotated \(Date()) ==========\n")
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}

// MARK: - Debug Log
struct DebugLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let message: String

    var formattedLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] [\(category)] \(message)"
    }
}

struct DebugLogView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Debug Log")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Text("\(bluetooth.logEntries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button("Copy All") {
                    bluetooth.copyLogToPasteboard()
                }

                Button("Clear") {
                    bluetooth.clearLog()
                }
            }
            .padding()

            VStack(alignment: .leading, spacing: 4) {
                Text("BLE traffic and read/write events — use while debugging tag issues")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("File:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(bluetooth.logFilePath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("Reveal") {
                        bluetooth.revealLogFile()
                    }
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if bluetooth.logEntries.isEmpty {
                            Text("No log entries yet. Connect to the device and read or write a tag.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(bluetooth.logEntries) { entry in
                                Text(entry.formattedLine)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(colorForCategory(entry.category))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(8)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: bluetooth.logEntries.count) { _, _ in
                    guard autoScroll, let last = bluetooth.logEntries.last else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "TX", "TX-CHUNK": return .blue
        case "RX": return .green
        case "RX-CHUNK": return .teal
        case "ERR": return .red
        case "READ", "WRITE": return .orange
        case "BLE": return .purple
        case "SYS": return .secondary
        default: return .primary
        }
    }
}

// MARK: - Bluetooth Manager
class BluetoothManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var deviceName = "CFS-Programmer"
    @Published var firmwareVersion = "Unknown"
    @Published var updateAvailable = false
    @Published var lastMessage = ""
    @Published var messageSequence = 0
    @Published var logEntries: [DebugLogEntry] = []
    @Published var logFilePath: String
    @Published var writePrefill: WritePrefill?
    @Published var lastWriteForm: WriteFormSnapshot?

    private let maxLogEntries = 1000
    private let logFile = DebugLogFileWriter.shared

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var pendingWriteChunks: [Data] = []
    private var pendingWriteTotalChunks = 0
    private var pendingWriteLabel = ""
    private var onWriteComplete: (() -> Void)?
    private var pendingCommandQueue: [String] = []
    private var txAccumulatorData = Data()

    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    private let rxUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    private let txUUID = CBUUID(string: "1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e")

    override init() {
        logFilePath = DebugLogFileWriter.shared.fileURL.path
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        log("SYS", "CFS Programmer started — log file: \(logFilePath)")
    }

    var logText: String {
        logEntries.map(\.formattedLine).joined(separator: "\n")
    }

    func log(_ category: String, _ message: String) {
        let entry = DebugLogEntry(timestamp: Date(), category: category, message: message)
        logFile.append(entry.formattedLine)
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
        }
        print("[\(category)] \(message)")
    }

    func revealLogFile() {
        logFile.revealInFinder()
    }

    func clearLog() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
        log("SYS", "Log cleared")
    }

    func copyLogToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
        log("SYS", "Log copied to clipboard (\(logEntries.count) entries)")
    }

    func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        centralManager.scanForPeripherals(withServices: [serviceUUID])
        log("BLE", "Scanning for CFS-Programmer...")
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func sendCommand(_ command: String, completion: (() -> Void)? = nil) {
        guard let peripheral = peripheral,
              let rxChar = rxCharacteristic,
              let data = command.data(using: .utf8) else {
            log("ERR", "Cannot send — not connected: \(command)")
            completion?()
            return
        }

        onWriteComplete = completion

        let maxLen = peripheral.maximumWriteValueLength(for: .withResponse)
        if data.count <= maxLen {
            peripheral.writeValue(data, for: rxChar, type: .withResponse)
            log("TX", command)
            return
        }

        pendingWriteLabel = command
        pendingWriteChunks = stride(from: 0, to: data.count, by: maxLen).map { offset in
            Data(data[offset..<min(offset + maxLen, data.count)])
        }
        pendingWriteTotalChunks = pendingWriteChunks.count
        log("TX", "\(command) (\(pendingWriteTotalChunks) chunks)")
        sendNextWriteChunk(to: peripheral, characteristic: rxChar)
    }

    func sendCommands(_ commands: [String]) {
        log("TX", "Queued \(commands.count) commands: \(commands.joined(separator: " → "))")
        pendingCommandQueue = commands
        sendNextQueuedCommand()
    }

    private func sendNextQueuedCommand() {
        guard !pendingCommandQueue.isEmpty else { return }
        let command = pendingCommandQueue.removeFirst()
        sendCommand(command) { [weak self] in
            guard let self = self else { return }
            if self.pendingCommandQueue.isEmpty { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.sendNextQueuedCommand()
            }
        }
    }

    private func sendNextWriteChunk(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard let chunk = pendingWriteChunks.first else {
            if !pendingWriteLabel.isEmpty {
                log("TX", "Chunked send complete: \(pendingWriteLabel)")
                pendingWriteLabel = ""
            }
            return
        }

        let chunkNum = pendingWriteTotalChunks - pendingWriteChunks.count + 1
        log("TX-CHUNK", "chunk \(chunkNum)/\(pendingWriteTotalChunks) — \(chunk.count) bytes")
        peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
    }
    
    private func requestFirmwareVersion() {
        sendCommand("GET_VERSION")
    }

    private func sanitizeBLEMessage(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isCompleteBLEMessage(_ message: String) -> Bool {
        if message == "READY" || message == "BLANK_TAG" || message == "WRITE_READY" { return true }
        if message == "TAG1_WRITTEN" || message == "TAG2_WRITTEN" { return true }
        if message == "UP_TO_DATE" || message == "WIFI_OK" || message == "DISCONNECTED" { return true }
        if message.hasPrefix("VERSION:") { return true }
        if message.hasPrefix("UID:") { return true }
        if message.hasPrefix("UPDATE_") { return true }
        return false
    }

    private func dispatchBLEMessage(_ raw: String) {
        let message = sanitizeBLEMessage(raw)
        guard !message.isEmpty else { return }

        log("RX", message)

        if message.hasPrefix("VERSION:") {
            let version = message
                .replacingOccurrences(of: "VERSION:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\0", with: "")

            DispatchQueue.main.async {
                self.firmwareVersion = version
            }
            log("BLE", "Firmware version: \(version)")
            return
        }

        DispatchQueue.main.async {
            self.lastMessage = message
            self.messageSequence += 1
        }
    }

    private func decodeBLEData(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        // CFS protocol messages are ASCII; avoid per-chunk UTF-8 failures on split bytes
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private func handleIncomingBLEData(_ data: Data) {
        txAccumulatorData.append(data)

        while let newlineIndex = txAccumulatorData.firstIndex(of: 0x0A) {
            let messageData = txAccumulatorData[..<newlineIndex]
            txAccumulatorData = Data(txAccumulatorData[(newlineIndex + 1)...])
            dispatchBLEMessage(decodeBLEData(messageData))
        }

        if !txAccumulatorData.isEmpty {
            let partial = decodeBLEData(txAccumulatorData)
            if isCompleteBLEMessage(partial) {
                txAccumulatorData.removeAll()
                dispatchBLEMessage(partial)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && !isConnected {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log("BLE", "Discovered: \(peripheral.name ?? "Unknown")")

        if peripheral.name == "CFS-Programmer" {
            self.peripheral = peripheral
            central.stopScan()
            isScanning = false
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("BLE", "Connected")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            log("BLE", "Disconnected: \(error.localizedDescription)")
        } else {
            log("BLE", "Disconnected")
        }
        isConnected = false
        firmwareVersion = "Unknown"
        startScanning()
        
        DispatchQueue.main.async {
            self.txAccumulatorData.removeAll()
            self.lastMessage = "DISCONNECTED"
            self.messageSequence += 1
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([txUUID, rxUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == txUUID {
                txCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                log("BLE", "Subscribed to TX notifications")
            } else if characteristic.uuid == rxUUID {
                rxCharacteristic = characteristic
                log("BLE", "Found RX characteristic")
            }
        }

        if txCharacteristic != nil && rxCharacteristic != nil {
            DispatchQueue.main.async {
                self.txAccumulatorData.removeAll()
                self.isConnected = true
            }
            log("BLE", "Ready — requesting firmware version")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.requestFirmwareVersion()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == rxUUID else { return }

        if let error = error {
            log("ERR", "BLE write failed: \(error.localizedDescription)")
            pendingWriteChunks.removeAll()
            pendingWriteTotalChunks = 0
            pendingWriteLabel = ""
            return
        }

        if !pendingWriteChunks.isEmpty {
            pendingWriteChunks.removeFirst()
            if let rxChar = rxCharacteristic {
                sendNextWriteChunk(to: peripheral, characteristic: rxChar)
            }
        } else {
            let completion = onWriteComplete
            onWriteComplete = nil
            completion?()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == txUUID,
              let data = characteristic.value else { return }

        let hex = data.map { String(format: "%02X", $0) }.joined()
        log("RX-CHUNK", "\(data.count) bytes: \(hex)")
        handleIncomingBLEData(data)
    }
}
