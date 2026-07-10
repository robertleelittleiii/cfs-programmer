//
//  K2MaterialCatalog.swift
//  CFS Programmer
//
//  Stock brands + materials from Creality K2 material_database.json
//  (printer path: /mnt/UDISK/creality/userdata/box/material_database.json)
//

import Foundation

/// Stock catalog mirrored from the K2 CFS material database.
enum K2MaterialCatalog {

    struct StockBrand {
        let id: String
        let name: String
        let isOfficial: Bool
    }

    struct StockMaterial {
        let id: String          // K2 base.id (e.g. "01001") — RFID film ID is "1" + id
        let brandName: String
        let name: String
        let materialType: String
        let density: Double
        let diameter: Double
        let minTemp: Int
        let maxTemp: Int
        let defaultTemp: Int
        let primaryColorHex: String
    }

    /// Official brands present on the K2 printer catalog.
    static let brands: [StockBrand] = [
        StockBrand(id: "0276", name: "Creality", isOfficial: true),
        StockBrand(id: "0000", name: "Generic", isOfficial: false),
    ]

    /// Full material list from the K2 printer (40 materials).
    static let materials: [StockMaterial] = [
        StockMaterial(id: "07001", brandName: "Creality", name: "CR-ABS", materialType: "ABS", density: 1.08, diameter: 1.75, minTemp: 240, maxTemp: 280, defaultTemp: 260, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "06001", brandName: "Creality", name: "CR-PETG", materialType: "PETG", density: 1.23, diameter: 1.75, minTemp: 220, maxTemp: 270, defaultTemp: 245, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "04001", brandName: "Creality", name: "CR-PLA", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "15001", brandName: "Creality", name: "CR-PLA Fluo", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "14001", brandName: "Creality", name: "CR-PLA Matte", materialType: "PLA", density: 1.3, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "05001", brandName: "Creality", name: "CR-Silk", materialType: "PLA", density: 1.25, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#000000"),
        StockMaterial(id: "16001", brandName: "Creality", name: "CR-TPU", materialType: "TPU", density: 1.12, diameter: 1.75, minTemp: 210, maxTemp: 240, defaultTemp: 225, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "09001", brandName: "Creality", name: "EN-PLA+", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "09002", brandName: "Creality", name: "ENDER FAST PLA", materialType: "PLA", density: 1.21, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#000000"),
        StockMaterial(id: "08001", brandName: "Creality", name: "Ender-PLA", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "19001", brandName: "Creality", name: "HP-ASA", materialType: "ASA", density: 1.15, diameter: 1.75, minTemp: 240, maxTemp: 280, defaultTemp: 260, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "10001", brandName: "Creality", name: "HP-TPU", materialType: "TPU", density: 1.26, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "03001", brandName: "Creality", name: "Hyper ABS", materialType: "ABS", density: 1.08, diameter: 1.75, minTemp: 240, maxTemp: 280, defaultTemp: 260, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "01002", brandName: "Creality", name: "Hyper L-W PLA", materialType: "PLA", density: 1.21, diameter: 1.75, minTemp: 200, maxTemp: 270, defaultTemp: 235, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "01003", brandName: "Creality", name: "Hyper Luminous", materialType: "PLA", density: 1.3, diameter: 1.75, minTemp: 190, maxTemp: 230, defaultTemp: 210, primaryColorHex: "#000000"),
        StockMaterial(id: "29001", brandName: "Creality", name: "Hyper Marble", materialType: "PLA", density: 1.25, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#000000"),
        StockMaterial(id: "12003", brandName: "Creality", name: "Hyper PAHT-CF", materialType: "PA-CF", density: 1.06, diameter: 1.75, minTemp: 280, maxTemp: 320, defaultTemp: 300, primaryColorHex: "#000000"),
        StockMaterial(id: "06002", brandName: "Creality", name: "Hyper PETG", materialType: "PETG", density: 1.27, diameter: 1.75, minTemp: 220, maxTemp: 270, defaultTemp: 245, primaryColorHex: "#000000"),
        StockMaterial(id: "06003", brandName: "Creality", name: "Hyper PETG-CF", materialType: "PETG-CF", density: 1.25, diameter: 1.75, minTemp: 240, maxTemp: 260, defaultTemp: 250, primaryColorHex: "#000000"),
        StockMaterial(id: "06004", brandName: "Creality", name: "Hyper PETG-GF", materialType: "PETG-GF", density: 1.32, diameter: 1.75, minTemp: 240, maxTemp: 260, defaultTemp: 250, primaryColorHex: "#000000"),
        StockMaterial(id: "01001", brandName: "Creality", name: "Hyper PLA", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "02001", brandName: "Creality", name: "Hyper PLA-CF", materialType: "PLA-CF", density: 1.27, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "01004", brandName: "Creality", name: "Hyper Stardust", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#000000"),
        StockMaterial(id: "06005", brandName: "Creality", name: "Soleyin Basic PETG", materialType: "PETG", density: 1.25, diameter: 1.75, minTemp: 230, maxTemp: 250, defaultTemp: 240, primaryColorHex: "#000000"),
        StockMaterial(id: "01601", brandName: "Creality", name: "Soleyin Ultra PLA", materialType: "PLA", density: 1.25, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#000000"),
        StockMaterial(id: "00004", brandName: "Generic", name: "Generic ABS", materialType: "ABS", density: 1.24, diameter: 1.75, minTemp: 240, maxTemp: 280, defaultTemp: 260, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00007", brandName: "Generic", name: "Generic ASA", materialType: "ASA", density: 1.24, diameter: 1.75, minTemp: 240, maxTemp: 280, defaultTemp: 260, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00010", brandName: "Generic", name: "Generic BVOH", materialType: "BVOH", density: 1.24, diameter: 1.75, minTemp: 200, maxTemp: 220, defaultTemp: 210, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00008", brandName: "Generic", name: "Generic PA", materialType: "PA", density: 1.24, diameter: 1.75, minTemp: 240, maxTemp: 260, defaultTemp: 250, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00016", brandName: "Generic", name: "Generic PAHT-CF", materialType: "PA-CF", density: 1.24, diameter: 1.75, minTemp: 300, maxTemp: 320, defaultTemp: 310, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00020", brandName: "Generic", name: "Generic PET", materialType: "PET", density: 1.24, diameter: 1.75, minTemp: 250, maxTemp: 270, defaultTemp: 260, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00003", brandName: "Generic", name: "Generic PETG", materialType: "PETG", density: 1.24, diameter: 1.75, minTemp: 220, maxTemp: 270, defaultTemp: 245, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00014", brandName: "Generic", name: "Generic PETG-CF", materialType: "PETG-CF", density: 1.24, diameter: 1.75, minTemp: 240, maxTemp: 260, defaultTemp: 250, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00027", brandName: "Generic", name: "Generic PETG-GF", materialType: "PETG-GF", density: 1.28, diameter: 1.75, minTemp: 240, maxTemp: 280, defaultTemp: 260, primaryColorHex: "#000000"),
        StockMaterial(id: "00001", brandName: "Generic", name: "Generic PLA", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00006", brandName: "Generic", name: "Generic PLA-CF", materialType: "PLA-CF", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00002", brandName: "Generic", name: "Generic PLA-Silk", materialType: "PLA", density: 1.24, diameter: 1.75, minTemp: 190, maxTemp: 240, defaultTemp: 215, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00019", brandName: "Generic", name: "Generic PP", materialType: "PP", density: 1.24, diameter: 1.75, minTemp: 220, maxTemp: 260, defaultTemp: 240, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00011", brandName: "Generic", name: "Generic PVA", materialType: "PVA", density: 1.24, diameter: 1.75, minTemp: 215, maxTemp: 225, defaultTemp: 220, primaryColorHex: "#FFFFFF"),
        StockMaterial(id: "00005", brandName: "Generic", name: "Generic TPU", materialType: "TPU", density: 1.24, diameter: 1.75, minTemp: 210, maxTemp: 240, defaultTemp: 225, primaryColorHex: "#FFFFFF"),
    ]

    /// Material types used by stock catalog (for editor pickers).
    static var materialTypes: [String] {
        Array(Set(materials.map(\.materialType))).sorted()
    }

    static func brandId(forName name: String) -> String? {
        brands.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.id
    }
}
