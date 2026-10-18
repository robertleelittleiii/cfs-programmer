import Foundation

// Compile with Models/K2MaterialCatalog.swift and run the resulting executable.
@main
struct K2MaterialCatalogTests {
    static func main() {
        let materials = K2MaterialCatalog.materials
        precondition(materials.count == 47, "Expected all 47 printer profiles")
        precondition(Set(materials.map(\.id)).count == materials.count, "Duplicate material IDs")
        precondition(materials.filter { $0.brandName == "Creality" }.count == 25)
        precondition(materials.filter { $0.brandName == "Generic" }.count == 22)
        precondition(K2MaterialCatalog.materialTypes.count == 20)

        // Source: live K2 material_database.json, read 2026-10-18.
        let expected: [(id: String, name: String, type: String, density: Double, min: Int, max: Int, color: String)] = [
            ("00013", "Generic PET-CF", "PET-CF", 1.24, 280, 320, "#FFFFFF"),
            ("00040", "Generic PLA-HT-GF", "PLA-GF", 1.33, 0, 0, "#000000"),
            ("00041", "Generic ABS-GF", "ABS-GF", 1.08, 240, 270, "#000000"),
            ("00042", "Generic ABS-CF", "ABS-CF", 1.06, 240, 270, "#000000"),
            ("00043", "Generic PET-GF15", "PETG-GF", 1.43, 0, 0, "#000000"),
            ("00044", "Generic PC-CF", "PC-CF", 1.16, 0, 0, "#000000"),
            ("00045", "Generic ABS-FR", "ABS-FR", 1.05, 0, 0, "#000000"),
        ]

        for profile in expected {
            guard let material = materials.first(where: { $0.id == profile.id }) else {
                preconditionFailure("Missing profile \(profile.id)")
            }
            precondition(material.name == profile.name, "Name mismatch: \(profile.id)")
            precondition(material.materialType == profile.type, "Type mismatch: \(profile.id)")
            precondition(material.brandName == "Generic")
            precondition(K2MaterialCatalog.brandId(forName: material.brandName) == "0000")
            precondition(abs(material.density - profile.density) < 0.0001)
            precondition(material.diameter == 1.75)
            precondition(material.minTemp == profile.min)
            precondition(material.maxTemp == profile.max)
            precondition(material.defaultTemp == (profile.min + profile.max) / 2)
            precondition(material.primaryColorHex == profile.color)
            precondition(K2MaterialCatalog.materialTypes.contains(profile.type))
        }

        print("Catalog checks passed: 47 unique profiles, 20 types, 7 printer-sourced profiles verified.")
    }
}
