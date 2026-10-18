#pragma once

#include <string.h>

// K2 material_database.json IDs, mirrored by the Mac app's K2MaterialCatalog.
// The six-character tag film ID is "1" followed by the five-character base ID.
struct CFSMaterialID {
  const char* baseID;
  const char* materialType;
};

static const CFSMaterialID CFS_MATERIAL_IDS[] = {
  {"07001", "ABS"},
  {"06001", "PETG"},
  {"04001", "PLA"},
  {"15001", "PLA"},
  {"14001", "PLA"},
  {"05001", "PLA"},
  {"16001", "TPU"},
  {"09001", "PLA"},
  {"09002", "PLA"},
  {"08001", "PLA"},
  {"19001", "ASA"},
  {"10001", "TPU"},
  {"03001", "ABS"},
  {"01002", "PLA"},
  {"01003", "PLA"},
  {"29001", "PLA"},
  {"12003", "PA-CF"},
  {"06002", "PETG"},
  {"06003", "PETG-CF"},
  {"06004", "PETG-GF"},
  {"01001", "PLA"},
  {"02001", "PLA-CF"},
  {"01004", "PLA"},
  {"06005", "PETG"},
  {"01601", "PLA"},
  {"00004", "ABS"},
  {"00042", "ABS-CF"},
  {"00045", "ABS-FR"},
  {"00041", "ABS-GF"},
  {"00007", "ASA"},
  {"00010", "BVOH"},
  {"00008", "PA"},
  {"00016", "PA-CF"},
  {"00044", "PC-CF"},
  {"00020", "PET"},
  {"00013", "PET-CF"},
  {"00043", "PETG-GF"},
  {"00003", "PETG"},
  {"00014", "PETG-CF"},
  {"00027", "PETG-GF"},
  {"00001", "PLA"},
  {"00006", "PLA-CF"},
  {"00040", "PLA-GF"},
  {"00002", "PLA"},
  {"00019", "PP"},
  {"00011", "PVA"},
  {"00005", "TPU"},
};

inline const char* cfsMaterialTypeForFilmID(const char* filmID) {
  if (!filmID || strlen(filmID) != 6 || filmID[0] != '1') {
    return nullptr;
  }
  for (const auto& material : CFS_MATERIAL_IDS) {
    if (strcmp(filmID + 1, material.baseID) == 0) {
      return material.materialType;
    }
  }
  return nullptr; // Unknown IDs must remain unknown, not be labeled PLA.
}
