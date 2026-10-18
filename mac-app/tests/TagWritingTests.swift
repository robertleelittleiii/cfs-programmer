import Foundation

@main
struct TagWritingTests {
    static func material(id: String, type: String, baseID: String, brandID: String = "0000") -> FilamentMaterial {
        FilamentMaterial(
            id: id, brandId: brandID, brandName: "Test", baseId: baseID,
            inherits: "", templateSource: "", name: "Test \(type)",
            materialType: type, density: 1.24
        )
    }

    static func encode(_ material: FilamentMaterial, serial: String = "123456") throws -> String {
        try CFSTagEncoder.encode(
            material: material, dateCode: "ABA18", rgbHex: "a1b2c3",
            lengthCode: "0330", serial: serial
        )
    }

    static func main() throws {
        var payloads: [(String, String)] = []
        for stock in K2MaterialCatalog.materials {
            let profile = material(
                id: stock.id, type: stock.materialType, baseID: stock.id,
                brandID: K2MaterialCatalog.brandId(forName: stock.brandName)!
            )
            let payload = try encode(profile)
            let bytes = Array(payload.utf8)
            precondition(bytes.count == 48)
            precondition(String(bytes: bytes[5..<9], encoding: .ascii) == profile.brandId)
            precondition(String(bytes: bytes[11..<17], encoding: .ascii) == "1" + stock.id)
            precondition(String(bytes: bytes[17..<24], encoding: .ascii) == "0A1B2C3")
            precondition(String(bytes: bytes[24..<28], encoding: .ascii) == "0330")
            precondition(String(bytes: bytes[28..<34], encoding: .ascii) == "123456")
            precondition(String(bytes: bytes[34..<48], encoding: .ascii) == "00000000000000")
            payloads.append((payload, stock.materialType))
        }

        let fallbacks = [
            "PLA": "100001", "PETG": "100003", "ABS": "100004",
            "TPU": "100005", "Nylon": "100008", "ASA": "100007",
            "PET": "100020", "PETG-CF": "100014", "PAHT-CF": "100016",
            "PLA+": "100001", "PC-CF": "100044", "PETG-GF": "100027",
        ]
        for (type, expected) in fallbacks {
            let custom = material(id: "F001-0001", type: type, baseID: "GFSA04")
            precondition(CFSFilmID.from(materialType: type) == expected)
            precondition(CFSFilmID.filmID(for: custom) == expected)
            let payload = try encode(custom)
            let bytes = Array(payload.utf8)
            precondition(String(bytes: bytes[11..<17], encoding: .ascii) == expected)
        }
        for type in K2MaterialCatalog.materialTypes {
            guard let filmID = CFSFilmID.from(materialType: type),
                  let stock = K2MaterialCatalog.materials.first(where: { "1" + $0.id == filmID }) else {
                preconditionFailure("Missing catalog-backed fallback for \(type)")
            }
            precondition(stock.materialType == type)
        }

        // A custom profile edited from PLA to PETG cannot keep a PLA base ID.
        let edited = material(id: "F001-0002", type: "PETG", baseID: "01001")
        precondition(CFSFilmID.filmID(for: edited) == "100003")
        let unsupported = material(id: "F001-0003", type: "Unobtainium", baseID: "GFSA04")
        precondition(CFSFilmID.filmID(for: unsupported) == nil)
        do {
            _ = try encode(unsupported)
            preconditionFailure("Unsupported material must not silently become PLA")
        } catch CFSTagEncodingError.unsupportedMaterial { }

        let petg = material(id: "00003", type: "PETG", baseID: "00003")
        for serial in ["oooooo", "１２３４５６", "12345", "1234567"] {
            do {
                _ = try encode(petg, serial: serial)
                preconditionFailure("Invalid serial accepted")
            } catch CFSTagEncodingError.invalidField { }
        }
        for (field, value) in [("date", "AB💡18"), ("color", "GGGGGG"), ("length", "00330")] {
            do {
                _ = try CFSTagEncoder.encode(
                    material: petg, dateCode: field == "date" ? value : "ABA18",
                    rgbHex: field == "color" ? value : "FFFFFF",
                    lengthCode: field == "length" ? value : "0330", serial: "123456"
                )
                preconditionFailure("Invalid \(field) accepted")
            } catch CFSTagEncodingError.invalidField { }
        }

        if CommandLine.arguments.contains("--emit-payloads") {
            for (payload, type) in payloads {
                print("\(payload)\t\(type)")
            }
        } else {
            print("Tag writing checks passed: 47 stock payloads, catalog-backed fallbacks, type edits, and invalid-input rejection.")
        }
    }
}
