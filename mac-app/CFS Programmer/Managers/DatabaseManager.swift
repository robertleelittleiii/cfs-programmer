//
//  DatabaseManager.swift
//  CFS Programmer
//
//  Created by Steven Robinson on 12/24/25.
//

import Foundation
import Combine

class DatabaseManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var database: MaterialDatabase
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    
    // MARK: - File URLs
    private let fileManager = FileManager.default
    
    private var documentsURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CFS-Programmer", isDirectory: true)
    }
    
    private var mainDatabaseURL: URL {
        documentsURL.appendingPathComponent("materials.json")
    }
    
    private var backupURL: URL {
        documentsURL.appendingPathComponent("materials.backup.json")
    }
    
    private var backupsDirectory: URL {
        documentsURL.appendingPathComponent("backups", isDirectory: true)
    }
    
    // MARK: - Singleton
    static let shared = DatabaseManager()
    
    // MARK: - Initialization
    private init() {
        // Initialize database first
        if let loaded = Self.loadDatabase(from: fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CFS-Programmer").appendingPathComponent("materials.json")) {
            self.database = loaded
            print("✅ Database loaded successfully")
        } else {
            self.database = MaterialDatabase()
            print("🆕 Created new database")
        }
        
        // Create directories after database is initialized
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        
        // Ensure K2 stock brands + materials are present (idempotent upsert).
        // Always run — older installs only had Creality + a couple of test materials.
        let didSeed = seedK2CatalogIfNeeded()
        if didSeed {
            saveDatabase()
        }
        // Publish so SwiftUI pickers refresh even if mutation was nested
        objectWillChange.send()
        print("📚 Catalog ready: \(database.brands.count) brands, \(database.materials.count) materials")
    }

    // MARK: - K2 Catalog Seeding

    /// Upsert official brands and materials from the K2 printer catalog.
    /// - Returns: `true` if the in-memory database was modified.
    @discardableResult
    func seedK2CatalogIfNeeded() -> Bool {
        var changed = false

        // Brands
        for stock in K2MaterialCatalog.brands {
            if let index = database.brands.firstIndex(where: { $0.id == stock.id || $0.name.caseInsensitiveCompare(stock.name) == .orderedSame }) {
                var existing = database.brands[index]
                // Normalize official brands onto their stock IDs / names
                if existing.id != stock.id || existing.name != stock.name || existing.isOfficial != stock.isOfficial {
                    existing.id = stock.id
                    existing.name = stock.name
                    existing.isCustom = !stock.isOfficial
                    existing.isOfficial = stock.isOfficial
                    database.brands[index] = existing
                    changed = true
                }
            } else {
                database.brands.append(
                    Brand(
                        id: stock.id,
                        name: stock.name,
                        isCustom: !stock.isOfficial,
                        isOfficial: stock.isOfficial
                    )
                )
                changed = true
            }
        }

        // Density standards for catalog types
        for material in K2MaterialCatalog.materials {
            if database.densityStandards[material.materialType] == nil {
                database.densityStandards[material.materialType] = material.density
                changed = true
            }
        }

        // Materials — keyed by K2 base.id so RFID film IDs stay correct
        for stock in K2MaterialCatalog.materials {
            guard let brandId = K2MaterialCatalog.brandId(forName: stock.brandName) else { continue }

            if let index = database.materials.firstIndex(where: { $0.id == stock.id }) {
                var existing = database.materials[index]
                // Keep user notes/favorites; refresh stock identity + physical defaults
                let needsUpdate =
                    existing.name != stock.name ||
                    existing.brandId != brandId ||
                    existing.brandName != stock.brandName ||
                    existing.materialType != stock.materialType ||
                    abs(existing.density - stock.density) > 0.0001 ||
                    abs(existing.diameter - stock.diameter) > 0.0001 ||
                    existing.isCustom != false

                if needsUpdate {
                    existing.name = stock.name
                    existing.brandId = brandId
                    existing.brandName = stock.brandName
                    existing.materialType = stock.materialType
                    existing.density = stock.density
                    existing.diameter = stock.diameter
                    existing.isCustom = false
                    existing.baseId = stock.id
                    existing.templateSource = stock.name
                    existing.inherits = stock.name
                    existing.temperatures.nozzle.min = stock.minTemp
                    existing.temperatures.nozzle.max = stock.maxTemp
                    existing.temperatures.nozzle.defaultTemp = stock.defaultTemp
                    existing.weightOptions = calculateWeightOptions(density: stock.density, diameter: stock.diameter)
                    if existing.colors.isEmpty {
                        existing.colors = [
                            MaterialColor(hex: stock.primaryColorHex, name: "Default", isPrimary: true)
                        ]
                    }
                    existing.modifiedDate = Date()
                    database.materials[index] = existing
                    changed = true
                }
            } else {
                var material = FilamentMaterial(
                    id: stock.id,
                    brandId: brandId,
                    brandName: stock.brandName,
                    baseId: stock.id,
                    inherits: stock.name,
                    templateSource: stock.name,
                    name: stock.name,
                    materialType: stock.materialType,
                    density: stock.density,
                    weightOptions: calculateWeightOptions(density: stock.density, diameter: stock.diameter)
                )
                material.isCustom = false
                material.diameter = stock.diameter
                material.densitySource = .standard
                material.temperatures.nozzle.min = stock.minTemp
                material.temperatures.nozzle.max = stock.maxTemp
                material.temperatures.nozzle.defaultTemp = stock.defaultTemp
                material.colors = [
                    MaterialColor(hex: stock.primaryColorHex, name: "Default", isPrimary: true)
                ]
                database.materials.append(material)
                changed = true
            }
        }

        // Keep brandName on materials in sync if brand list changed
        for i in database.materials.indices {
            if let brand = getBrand(id: database.materials[i].brandId),
               database.materials[i].brandName != brand.name {
                database.materials[i].brandName = brand.name
                changed = true
            }
        }

        if changed {
            print("📦 Seeded/updated K2 catalog: \(K2MaterialCatalog.brands.count) brands, \(K2MaterialCatalog.materials.count) stock materials")
        }
        return changed
    }

    /// Materials sorted for UI pickers (brand, then name).
    func materialsForPicker() -> [FilamentMaterial] {
        database.materials.sorted {
            if $0.brandName.localizedCaseInsensitiveCompare($1.brandName) != .orderedSame {
                return $0.brandName.localizedCaseInsensitiveCompare($1.brandName) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Brands sorted for UI pickers.
    func brandsForPicker() -> [Brand] {
        database.brands.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Resolve a material from a 6-char RFID film ID (e.g. `101001` → Hyper PLA `01001`).
    /// K2 encodes film IDs as `"1" + material_database base.id`.
    func material(forFilmID filmID: String) -> FilamentMaterial? {
        let id = filmID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !id.isEmpty else { return nil }

        // Exact match on computed film ID for every catalog entry
        if let match = database.materials.first(where: { CFSFilmID.filmID(for: $0).uppercased() == id }) {
            return match
        }

        // Strip leading "1" from 6-char K2 film IDs → 5-char base.id
        if id.count == 6, id.hasPrefix("1") {
            let baseId = String(id.dropFirst())
            if let match = database.materials.first(where: {
                $0.id.uppercased() == baseId || $0.baseId.uppercased() == baseId
            }) {
                return match
            }
        }

        // Direct id / baseId match (in case firmware sends base id)
        if let match = database.materials.first(where: {
            $0.id.uppercased() == id || $0.baseId.uppercased() == id
        }) {
            return match
        }

        return nil
    }

    /// Resolve brand from 4-char RFID vendor code (e.g. `0276` → Creality).
    func brand(forVendorCode code: String) -> Brand? {
        let id = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !id.isEmpty else { return nil }
        if let match = database.brands.first(where: { $0.id.uppercased() == id }) {
            return match
        }
        // Known built-in codes if brand list is incomplete
        switch id {
        case "0276":
            return database.brands.first(where: { $0.name.caseInsensitiveCompare("Creality") == .orderedSame })
        case "0000":
            return database.brands.first(where: { $0.name.caseInsensitiveCompare("Generic") == .orderedSame })
        default:
            return nil
        }
    }

    /// Friendly vendor label from code + optional material match.
    func displayVendor(code: String?, material: FilamentMaterial?) -> String {
        if let material, !material.brandName.isEmpty {
            return material.brandName
        }
        if let code, let brand = brand(forVendorCode: code) {
            return brand.name
        }
        if let code, !code.isEmpty {
            switch code.uppercased() {
            case "0276": return "Creality"
            case "0000": return "Generic"
            default: return "Vendor \(code.uppercased())"
            }
        }
        return "Unknown vendor"
    }

    /// Resolve catalog material from read payload (film ID preferred, then coarse name/type).
    func resolveMaterial(rawMaterial: String, filmID: String?) -> FilamentMaterial? {
        if let filmID, let match = material(forFilmID: filmID) {
            return match
        }
        if let match = material(forFilmID: rawMaterial) {
            return match
        }
        let key = rawMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = database.materials.first(where: {
            $0.name.caseInsensitiveCompare(key) == .orderedSame
        }) {
            return match
        }
        if let match = database.materials.first(where: {
            $0.materialType.caseInsensitiveCompare(key) == .orderedSame && !$0.isCustom
        }) {
            return match
        }
        return nil
    }

    /// Human-readable label for a read tag (brand · name), falling back to the raw material string.
    func displayName(forReadMaterial material: String, filmID: String?) -> String {
        if let match = resolveMaterial(rawMaterial: material, filmID: filmID) {
            return "\(match.brandName) · \(match.name)"
        }
        if material.uppercased() == "UNKNOWN" {
            return "Unknown material"
        }
        return material
    }

    
    // MARK: - Database Operations
    
    /// Save database to disk with automatic backup
    func saveDatabase() {
        isLoading = true
        
        do {
            // Create backup before saving
            if fileManager.fileExists(atPath: mainDatabaseURL.path) {
                try? fileManager.copyItem(at: mainDatabaseURL, to: backupURL)
            }
            
            // Update metadata
            database.lastUpdated = Date()
            database.backupInfo.lastBackup = Date()
            
            // Encode and save
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(database)
            try data.write(to: mainDatabaseURL)
            
            print("ðŸ’¾ Database saved successfully")
            
            // Trigger objectWillChange for SwiftUI updates
            objectWillChange.send()
            
        } catch {
            print("âŒ Failed to save database: \(error)")
            lastError = error
        }
        
        isLoading = false
    }
    
    /// Load database from URL
    static func loadDatabase(from url: URL) -> MaterialDatabase? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let database = try decoder.decode(MaterialDatabase.self, from: data)
            return database
            
        } catch {
            print("âŒ Failed to load database: \(error)")
            return nil
        }
    }
    
    // MARK: - Material Operations
    
    /// Get all materials
    func getAllMaterials() -> [FilamentMaterial] {
        return database.materials.sorted { $0.name < $1.name }
    }
    
    /// Get materials by brand
    func getMaterials(for brandId: String) -> [FilamentMaterial] {
        return database.materials
            .filter { $0.brandId == brandId }
            .sorted { $0.name < $1.name }
    }
    
    /// Get material by ID
    func getMaterial(id: String) -> FilamentMaterial? {
        return database.materials.first { $0.id == id }
    }
    
    /// Search materials
    /// Search materials
    func searchMaterials(query: String) -> [FilamentMaterial] {
        let lowercaseQuery = query.lowercased()
        
        let filtered = database.materials.filter { material in
            let nameMatch = material.name.lowercased().contains(lowercaseQuery)
            let brandMatch = material.brandName.lowercased().contains(lowercaseQuery)
            let typeMatch = material.materialType.lowercased().contains(lowercaseQuery)
            let subtypeMatch = material.materialSubtype.lowercased().contains(lowercaseQuery)
            
            return nameMatch || brandMatch || typeMatch || subtypeMatch
        }
        
        return filtered.sorted { $0.name < $1.name }
    }

    
    /// Create new material
    @discardableResult
    func createMaterial(
        brandId: String,
        name: String,
        materialType: String,
        templateSource: String,
        cloneSettings: FilamentMaterial? = nil
    ) -> FilamentMaterial {
        
        // Get brand info
        guard let brand = getBrand(id: brandId) else {
            fatalError("Brand not found: \(brandId)")
        }
        
        // Generate material ID
        let materialId = generateMaterialId(for: brandId)
        
        // Get density for material type
        let density = database.densityStandards[materialType] ?? 1.24
        
        // Calculate weight options
        let weightOptions = calculateWeightOptions(density: density)
        
        // Create material
        var material = FilamentMaterial(
            id: materialId,
            brandId: brandId,
            brandName: brand.name,
            baseId: "GFSA04",
            inherits: templateSource,
            templateSource: templateSource,
            name: name,
            materialType: materialType,
            density: density,
            weightOptions: weightOptions
        )
        
        // Clone settings from template if provided
        if let template = cloneSettings {
            material = cloneMaterialSettings(from: template, to: material)
        }
        
        database.materials.append(material)
        saveDatabase()
        
        print("âœ¨ Created material: \(name) (\(materialId))")
        return material
    }
    
    /// Clone material settings
    private func cloneMaterialSettings(from template: FilamentMaterial, to target: FilamentMaterial) -> FilamentMaterial {
        var cloned = target
        
        // Copy all settings from template
        cloned.baseId = template.baseId
        cloned.materialSubtype = template.materialSubtype
        cloned.diameter = template.diameter
        cloned.temperatures = template.temperatures
        cloned.speeds = template.speeds
        cloned.kvParam = template.kvParam
        cloned.clonedFrom = template.id
        
        return cloned
    }
    
    /// Update existing material
    func updateMaterial(_ material: FilamentMaterial) {
        if let index = database.materials.firstIndex(where: { $0.id == material.id }) {
            var updated = material
            updated.modifiedDate = Date()
            database.materials[index] = updated
            saveDatabase()
            print("ðŸ“ Updated material: \(material.name)")
        }
    }
    
    /// Delete material
    func deleteMaterial(id: String) {
        database.materials.removeAll { $0.id == id }
        saveDatabase()
        print("ðŸ—‘ï¸ Deleted material: \(id)")
    }
    
    /// Generate next material ID for brand (BRAND_ID-0001)
    private func generateMaterialId(for brandId: String) -> String {
        // Initialize counter for this brand if needed
        if database.materialIdCounters[brandId] == nil {
            database.materialIdCounters[brandId] = 0
        }
        
        // Increment counter
        database.materialIdCounters[brandId]! += 1
        var counter = database.materialIdCounters[brandId]!
        
        // Format: BRAND_ID-XXXX
        var materialNumber = String(format: "%04d", counter)
        var id = "\(brandId)-\(materialNumber)"
        
        // Safety check for collisions
        while database.materials.contains(where: { $0.id == id }) {
            counter += 1
            materialNumber = String(format: "%04d", counter)
            id = "\(brandId)-\(materialNumber)"
        }
        
        database.materialIdCounters[brandId] = counter
        return id
    }
    
    // MARK: - Brand Operations
    
    /// Get all brands sorted by name
    func getAllBrands() -> [Brand] {
        return database.brands.sorted { $0.name < $1.name }
    }
    
    /// Get brand by ID
    func getBrand(id: String) -> Brand? {
        return database.brands.first { $0.id == id }
    }
    
    /// Create new brand
    @discardableResult
    func createBrand(name: String, notes: String = "") -> Brand {
        // Check if brand already exists
        if let existing = database.brands.first(where: { $0.name == name }) {
            return existing
        }
        
        // Generate new brand ID
        let brandId = generateBrandId()
        
        let brand = Brand(
            id: brandId,
            name: name,
            isCustom: true,
            isOfficial: false,
            notes: notes
        )
        
        database.brands.append(brand)
        saveDatabase()
        
        print("âœ¨ Created brand: \(name) (\(brandId))")
        return brand
    }
    
    /// Generate next available brand ID (F001-FFFF)
    private func generateBrandId() -> String {
        database.brandIdCounter += 1
        var counter = database.brandIdCounter
        
        // Format: F + 3 digits (F001-F999)
        var id = "F" + String(format: "%03d", counter)
        
        // Safety check for collisions
        while database.brands.contains(where: { $0.id == id }) {
            counter += 1
            id = "F" + String(format: "%03d", counter)
        }
        
        database.brandIdCounter = counter
        return id
    }
    
    // MARK: - Weight Options Calculation
    
    /// Calculate standard weight options based on density
    func calculateWeightOptions(density: Double, diameter: Double = 1.75) -> [WeightOption] {
        let weights = [1000, 750, 500, 250]
        
        return weights.map { grams in
            let lengthMeters = LengthCalculator.calculateLength(
                weightGrams: Double(grams),
                density: density,
                diameter: diameter
            )
            let lengthHex = LengthCalculator.lengthToHex(lengthMeters)
            
            return WeightOption(
                grams: grams,
                lengthMeters: lengthMeters,
                lengthHex: lengthHex,
                isDefault: grams == 1000
            )
        }
    }
    
    // MARK: - Serial Number Operations
    
    /// Generate unique 6-digit serial number
    func generateUniqueSerial() -> String {
        var serial: String
        var attempts = 0
        let maxAttempts = 100
        
        repeat {
            // Generate random 6-digit number (100000-999999)
            let randomNumber = Int.random(in: 100000...999999)
            serial = String(randomNumber)
            attempts += 1
            
            // Check if already used
            if !database.usedSerials.contains(serial) {
                database.usedSerials.append(serial)
                saveDatabase()
                print("ðŸ”¢ Generated serial: \(serial)")
                return serial
            }
            
        } while attempts < maxAttempts
        
        fatalError("Failed to generate unique serial after \(maxAttempts) attempts")
    }
    
    // MARK: - Brand Operations (Missing)

    /// Update existing brand
    func updateBrand(_ brand: Brand) {
        if let index = database.brands.firstIndex(where: { $0.id == brand.id }) {
            database.brands[index] = brand
            saveDatabase()
            print("ðŸ“ Updated brand: \(brand.name)")
        }
    }

    /// Delete brand (only if no materials use it)
    func deleteBrand(id: String) -> Result<Void, BrandDeletionError> {
        // Check if any materials use this brand
        let materialsUsingBrand = database.materials.filter { $0.brandId == id }
        
        if !materialsUsingBrand.isEmpty {
            return .failure(.hasMaterials(count: materialsUsingBrand.count))
        }
        
        // Don't allow deleting official Creality brand
        if let brand = getBrand(id: id), brand.isOfficial {
            return .failure(.isOfficial)
        }
        
        database.brands.removeAll { $0.id == id }
        saveDatabase()
        print("ðŸ—‘ï¸ Deleted brand: \(id)")
        return .success(())
    }

    /// Get count of materials for a brand
    func getMaterialCount(for brandId: String) -> Int {
        return database.materials.filter { $0.brandId == brandId }.count
    }

    enum BrandDeletionError: Error {
        case hasMaterials(count: Int)
        case isOfficial
    }

    // MARK: - Spool Instance Operations

    /// Create new spool instance
    @discardableResult
    func createSpoolInstance(
        materialId: String,
        serial: String,
        weightGrams: Int,
        location: String = "",
        notes: String = ""
    ) -> SpoolInstance {
        
        var spool = SpoolInstance(
            serial: serial,
            materialId: materialId,
            weightGrams: weightGrams
        )
        
        // Set optional properties
        spool.location = location
        spool.notes = notes
        spool.writeDate = Date()
        spool.isActive = true
        
        database.spoolInstances.append(spool)
        
        // Add serial to used serials if not already there
        if !database.usedSerials.contains(serial) {
            database.usedSerials.append(serial)
        }
        
        saveDatabase()
        print("ðŸ·ï¸ Created spool instance: \(serial) for material \(materialId)")
        return spool
    }

    /// Get spool by serial number
    func getSpoolInstance(serial: String) -> SpoolInstance? {
        return database.spoolInstances.first { $0.serial == serial }
    }

    /// Get all spool instances
    func getAllSpoolInstances() -> [SpoolInstance] {
        return database.spoolInstances.sorted(by: { $0.writeDate > $1.writeDate })
    }

    /// Get spools for a specific material
    func getSpoolInstances(for materialId: String) -> [SpoolInstance] {
        return database.spoolInstances
            .filter { $0.materialId == materialId }
            .sorted(by: { $0.writeDate > $1.writeDate })
    }

    /// Update spool instance
    func updateSpoolInstance(_ spool: SpoolInstance) {
        if let index = database.spoolInstances.firstIndex(where: { $0.serial == spool.serial }) {
            database.spoolInstances[index] = spool
            saveDatabase()
            print("ðŸ“ Updated spool: \(spool.serial)")
        }
    }

    /// Delete spool instance
    func deleteSpoolInstance(serial: String) {
        database.spoolInstances.removeAll { $0.serial == serial }
        // Optionally remove from used serials if you want to allow reuse
        // database.usedSerials.removeAll { $0 == serial }
        saveDatabase()
        print("ðŸ—‘ï¸ Deleted spool: \(serial)")
    }

    // MARK: - Settings Operations

    /// Update database settings
    func updateSettings(_ settings: DatabaseSettings) {
        database.settings = settings
        saveDatabase()
        print("âš™ï¸ Updated settings")
    }

    /// Get density standard for material type
    func getDensityStandard(for materialType: String) -> Double {
        return database.densityStandards[materialType] ?? 1.24 // Default to PLA
    }

    /// Set custom density standard
    func setDensityStandard(for materialType: String, density: Double) {
        database.densityStandards[materialType] = density
        saveDatabase()
        print("ðŸ“ Set density for \(materialType): \(density) g/cmÂ³")
    }

    // MARK: - Backup Operations

    /// Create timestamped backup
    func createDailySnapshot() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let snapshotURL = backupsDirectory
            .appendingPathComponent("materials_\(timestamp).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(database)
            try data.write(to: snapshotURL)
            
            database.backupInfo.backupCount += 1
            database.backupInfo.lastBackup = Date()
            
            print("ðŸ“¸ Created snapshot: \(timestamp)")
            
            // Clean old backups
            cleanOldBackups()
            
            return snapshotURL
        } catch {
            print("âŒ Failed to create snapshot: \(error)")
            return nil
        }
    }

    /// List all available backups
    func listBackups() -> [URL] {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(
                at: backupsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            return backupFiles
                .filter { $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    guard let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate,
                          let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                        return false
                    }
                    return date1 > date2
                }
        } catch {
            print("âŒ Failed to list backups: \(error)")
            return []
        }
    }

    /// Restore from backup
    func restoreFromBackup(url: URL) -> Bool {
        guard let backup = Self.loadDatabase(from: url) else {
            print("âŒ Failed to load backup")
            return false
        }
        
        // Create safety backup of current state
        _ = createDailySnapshot()
        
        // Restore
        self.database = backup
        saveDatabase()
        
        print("â™»ï¸ Restored from backup: \(url.lastPathComponent)")
        return true
    }

    /// Clean backups older than 30 days
    private func cleanOldBackups() {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        let backups = listBackups()
        
        for backup in backups {
            if let creationDate = try? backup.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < thirtyDaysAgo {
                try? fileManager.removeItem(at: backup)
                print("ðŸ§¹ Deleted old backup: \(backup.lastPathComponent)")
            }
        }
    }
}
