#include "../CFS_Handheld_v1.2_OTA/CFSMaterialIDs.h"
#include <cassert>
#include <iostream>
#include <string>

int main() {
  assert(strcmp(cfsMaterialTypeForFilmID("101002"), "PLA") == 0);
  assert(strcmp(cfsMaterialTypeForFilmID("101003"), "PLA") == 0);
  assert(strcmp(cfsMaterialTypeForFilmID("101004"), "PLA") == 0);
  assert(strcmp(cfsMaterialTypeForFilmID("100003"), "PETG") == 0);
  assert(strcmp(cfsMaterialTypeForFilmID("106001"), "PETG") == 0);
  assert(strcmp(cfsMaterialTypeForFilmID("106002"), "PETG") == 0);
  assert(cfsMaterialTypeForFilmID("101005") == nullptr);
  assert(cfsMaterialTypeForFilmID("1FFFFF") == nullptr);
  assert(cfsMaterialTypeForFilmID("01001") == nullptr);
  assert(cfsMaterialTypeForFilmID(nullptr) == nullptr);

  std::string line;
  size_t count = 0;
  while (std::getline(std::cin, line)) {
    const auto separator = line.find('\t');
    assert(separator == 48);
    const auto payload = line.substr(0, separator);
    const auto expectedType = line.substr(separator + 1);
    const auto filmID = payload.substr(11, 6);
    const char* decodedType = cfsMaterialTypeForFilmID(filmID.c_str());
    assert(decodedType && expectedType == decodedType);
    ++count;
  }
  assert(count == 47);
  std::cout << "Firmware material checks passed: all 47 Mac-generated payloads decode to the expected type.\n";
}
