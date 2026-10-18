import Foundation

enum CFSTagEncodingError: LocalizedError {
    case unsupportedMaterial(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMaterial(let type):
            return "No K2 RFID material ID for \(type). Select a supported printer profile."
        case .invalidField(let field):
            return "Invalid tag \(field). No data was sent to the programmer."
        }
    }
}

enum CFSTagEncoder {
    /// Builds the exact 48-byte ASCII payload sent to the programmer.
    static func encode(
        material: FilamentMaterial,
        dateCode: String,
        rgbHex: String,
        lengthCode: String,
        serial: String
    ) throws -> String {
        guard let filmID = CFSFilmID.filmID(for: material) else {
            throw CFSTagEncodingError.unsupportedMaterial(material.materialType)
        }
        guard CFSFilmID.isHex(dateCode, count: 5) else {
            throw CFSTagEncodingError.invalidField("date")
        }
        guard CFSFilmID.isHex(rgbHex, count: 6) else {
            throw CFSTagEncodingError.invalidField("color")
        }
        guard CFSFilmID.isHex(lengthCode, count: 4) else {
            throw CFSTagEncodingError.invalidField("length")
        }
        guard serial.utf8.count == 6, serial.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw CFSTagEncodingError.invalidField("serial (six ASCII digits required)")
        }

        let vendor = CFSFilmID.vendorCode(for: material)
        return "\(dateCode)\(vendor)01\(filmID)0\(rgbHex.uppercased())\(lengthCode.uppercased())\(serial)00000000000000"
    }
}
