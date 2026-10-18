import Foundation

enum CFSFilmID {
    static func normalizedType(_ materialType: String) -> String {
        switch materialType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PLA+": return "PLA"
        case "NYLON": return "PA"
        case "PAHT-CF": return "PA-CF"
        default: return materialType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
    }

    /// Custom materials without a K2 base ID use a real Generic catalog profile.
    /// Unsupported types must not silently become PLA.
    static func from(materialType: String) -> String? {
        let type = normalizedType(materialType)
        guard let stock = K2MaterialCatalog.materials
            .filter({ $0.brandName == "Generic" && $0.materialType == type })
            .min(by: { $0.id < $1.id }) else { return nil }
        return "1" + stock.id
    }

    static func isHex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }

    /// K2 film ID = "1" + five-character printer material ID.
    static func filmID(for material: FilamentMaterial) -> String? {
        let candidate = (material.baseId.count == 5 ? material.baseId : material.id).uppercased()
        if isHex(candidate, count: 5) {
            // Editing a cloned profile's type must not retain its old PLA base ID.
            if let stock = K2MaterialCatalog.materials.first(where: { $0.id == candidate }),
               stock.materialType != normalizedType(material.materialType) {
                return from(materialType: material.materialType)
            }
            return "1" + candidate
        }
        return from(materialType: material.materialType)
    }

    static func vendorCode(for material: FilamentMaterial) -> String {
        let id = material.brandId.uppercased()
        return isHex(id, count: 4) ? id : "0276"
    }
}
