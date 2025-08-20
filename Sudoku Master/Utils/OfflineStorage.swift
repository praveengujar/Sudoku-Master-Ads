import Foundation
import SwiftUI
import Combine

// MARK: - High-Performance Offline Storage Manager

@MainActor
class OfflineStorage: ObservableObject {
    @Published var isOfflineMode = false
    @Published var isManualOfflineMode = false
    @Published var puzzleCount = 0
    
    // Performance optimizations
    private let storageQueue = DispatchQueue(label: "offline.storage", qos: .utility)
    private let cacheQueue = DispatchQueue(label: "offline.cache", qos: .background)
    
    // In-memory cache for frequently accessed data
    private var puzzleCache: [String: [SudokuPuzzle]] = [:]
    private var progressCache: [Int: StoredGameRecord] = [:]
    private var customPuzzleCache: [String: SavedCustomPuzzle] = [:]
    
    // Cache configuration
    private let maxCacheSize = 100
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private var lastCacheUpdate: Date = Date()
    
    // Storage keys - centralized for better maintenance
    private enum StorageKeys {
        static let offlineMode = "isManualOfflineMode"
        static let storedPuzzles = "storedPuzzles_v2" // v2 for optimized format
        static let savedProgress = "savedGameProgress_v2"
        static let savedCustomPuzzles = "savedCustomPuzzles_v2"
        static let appSettings = "appSettings_v2"
        static let cacheMetadata = "cacheMetadata"
    }
    
    // Compression and encoding optimizations
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // File manager for potential file-based storage migration
    private let fileManager = FileManager.default
    private lazy var documentsDirectory: URL = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }()
    
    init() {
        // Configure optimized JSON coding
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .withoutEscapingSlashes
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Load initial state
        loadInitialState()
        
        // Setup cache cleanup timer
        setupCacheCleanup()
    }
    
    // MARK: - Initialization and State Management
    
    private func loadInitialState() {
        isManualOfflineMode = UserDefaults.standard.bool(forKey: StorageKeys.offlineMode)
        updateOfflineStatus()
        
        Task { [weak self] in
            await self?.loadCacheAsync()
            await self?.countStoredPuzzlesAsync()
        }
    }
    
    private func setupCacheCleanup() {
        // Clean up cache every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.cleanupExpiredCache()
            }
        }
    }
    
    func updateOfflineStatus(networkConnected: Bool = true) {
        isOfflineMode = isManualOfflineMode || !networkConnected
    }
    
    func toggleOfflineMode() {
        isManualOfflineMode.toggle()
        UserDefaults.standard.set(isManualOfflineMode, forKey: StorageKeys.offlineMode)
        updateOfflineStatus()
    }
    
    // MARK: - Optimized Puzzle Management
    
    func countStoredPuzzles() {
        Task { [weak self] in
            await self?.countStoredPuzzlesAsync()
        }
    }
    
    private func countStoredPuzzlesAsync() async {
        // Check cache first
        if !puzzleCache.isEmpty {
            let count = puzzleCache.values.reduce(0) { $0 + $1.count }
            await MainActor.run { [weak self] in
                self?.puzzleCount = count
            }
            return
        }
        
        // Load from persistent storage
        let puzzles = await loadPuzzlesFromStorage()
        let count = puzzles?.values.reduce(0) { $0 + $1.count } ?? 0
        
        await MainActor.run { [weak self] in
            self?.puzzleCount = count
        }
    }
    
    func savePuzzles(puzzles: [String: [SudokuPuzzle]]) -> Bool {
        Task { [weak self] in
            await self?.savePuzzlesAsync(puzzles: puzzles)
        }
        return true
    }
    
    private func savePuzzlesAsync(puzzles: [String: [SudokuPuzzle]]) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.updatePuzzleCache(puzzles: puzzles)
            }
            
            group.addTask { [weak self] in
                await self?.persistPuzzlesToStorage(puzzles: puzzles)
            }
        }
        
        await countStoredPuzzlesAsync()
    }
    
    private func updatePuzzleCache(puzzles: [String: [SudokuPuzzle]]) async {
        puzzleCache = puzzles
        lastCacheUpdate = Date()
    }
    
    private func persistPuzzlesToStorage(puzzles: [String: [SudokuPuzzle]]) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storageQueue.async { [weak self] in
                defer { continuation.resume() }
                
                guard let self = self else { return }
                
                do {
                    let data = try self.encoder.encode(puzzles)
                    
                    // Use compressed storage for large datasets
                    let compressedData = try data.compressed()
                    UserDefaults.standard.set(compressedData, forKey: StorageKeys.storedPuzzles)
                    
                    print("✅ Saved \(puzzles.values.flatMap { $0 }.count) puzzles with compression")
                } catch {
                    print("❌ Error saving puzzles: \(error)")
                }
            }
        }
    }
    
    func getStoredPuzzles() -> [String: [SudokuPuzzle]]? {
        // Return cached data if available and fresh
        if !puzzleCache.isEmpty && Date().timeIntervalSince(lastCacheUpdate) < cacheExpirationTime {
            return puzzleCache
        }
        
        // Load from storage asynchronously
        Task { [weak self] in
            let puzzles = await self?.loadPuzzlesFromStorage()
            await MainActor.run { [weak self] in
                if let puzzles = puzzles {
                    self?.puzzleCache = puzzles
                    self?.lastCacheUpdate = Date()
                }
            }
        }
        
        return puzzleCache.isEmpty ? nil : puzzleCache
    }
    
    private func loadPuzzlesFromStorage() async -> [String: [SudokuPuzzle]]? {
        return await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                var hasResumed = false
                
                func safeResume(returning value: [String: [SudokuPuzzle]]?) {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }
                
                guard let self = self,
                      let compressedData = UserDefaults.standard.data(forKey: StorageKeys.storedPuzzles) else {
                    safeResume(returning: nil)
                    return
                }
                
                do {
                    let data = try compressedData.decompressed()
                    let puzzles = try self.decoder.decode([String: [SudokuPuzzle]].self, from: data)
                    safeResume(returning: puzzles)
                } catch {
                    print("❌ Error loading puzzles: \(error)")
                    safeResume(returning: nil)
                }
            }
        }
    }
    
    func getPuzzleByDifficulty(difficulty: SudokuDifficulty) -> SudokuPuzzle? {
        // Check cache first
        if let puzzles = puzzleCache[difficulty.rawValue], !puzzles.isEmpty {
            return puzzles.randomElement()
        }
        
        // Check persistent storage
        guard let storedPuzzles = getStoredPuzzles(),
              let difficultyPuzzles = storedPuzzles[difficulty.rawValue],
              !difficultyPuzzles.isEmpty else {
            return nil
        }
        
        return difficultyPuzzles.randomElement()
    }
    
    // MARK: - Optimized Game Progress Management
    
    func saveGameProgress(record: StoredGameRecord) {
        Task { [weak self] in
            await self?.saveGameProgressAsync(record: record)
        }
    }
    
    private func saveGameProgressAsync(record: StoredGameRecord) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.updateProgressCache(record: record)
            }
            
            group.addTask { [weak self] in
                await self?.persistProgressToStorage(record: record)
            }
        }
    }
    
    private func updateProgressCache(record: StoredGameRecord) async {
        progressCache[record.puzzleId] = record
    }
    
    private func persistProgressToStorage(record: StoredGameRecord) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storageQueue.async { [weak self] in
                defer { continuation.resume() }
                
                guard let self = self else { return }
                
                var savedRecords = self.loadProgressFromStorage() ?? []
                
                // Update existing record or add new one
                if let index = savedRecords.firstIndex(where: { $0.puzzleId == record.puzzleId }) {
                    savedRecords[index] = record
                } else {
                    savedRecords.append(record)
                }
                
                // Keep only the most recent 50 records to prevent unlimited growth
                if savedRecords.count > 50 {
                    savedRecords = Array(savedRecords.sorted { $0.timestamp > $1.timestamp }.prefix(50))
                }
                
                do {
                    let data = try self.encoder.encode(savedRecords)
                    let compressedData = try data.compressed()
                    UserDefaults.standard.set(compressedData, forKey: StorageKeys.savedProgress)
                } catch {
                    print("❌ Error saving game progress: \(error)")
                }
            }
        }
    }
    
    func getSavedGameProgress() -> [StoredGameRecord]? {
        return loadProgressFromStorage()
    }
    
    private func loadProgressFromStorage() -> [StoredGameRecord]? {
        guard let compressedData = UserDefaults.standard.data(forKey: StorageKeys.savedProgress) else {
            return nil
        }
        
        do {
            let data = try compressedData.decompressed()
            return try decoder.decode([StoredGameRecord].self, from: data)
        } catch {
            print("❌ Error retrieving game progress: \(error)")
            return nil
        }
    }
    
    func getLastPlayedPuzzle() -> StoredGameRecord? {
        // Check cache first
        let cachedRecord = progressCache.values.max { $0.timestamp < $1.timestamp }
        
        if let cachedRecord = cachedRecord {
            return cachedRecord
        }
        
        // Check persistent storage
        guard let savedRecords = getSavedGameProgress(), !savedRecords.isEmpty else {
            return nil
        }
        
        return savedRecords.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    // MARK: - Custom Puzzle Management (Optimized)
    
    func saveCustomPuzzle(puzzle: SavedCustomPuzzle) {
        Task { [weak self] in
            await self?.saveCustomPuzzleAsync(puzzle: puzzle)
        }
    }
    
    private func saveCustomPuzzleAsync(puzzle: SavedCustomPuzzle) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await MainActor.run { [weak self] in
                    self?.customPuzzleCache[String(puzzle.id)] = puzzle
                }
            }
            
            group.addTask { [weak self] in
                await self?.persistCustomPuzzleToStorage(puzzle: puzzle)
            }
        }
    }
    
    private func persistCustomPuzzleToStorage(puzzle: SavedCustomPuzzle) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storageQueue.async { [weak self] in
                defer { continuation.resume() }
                
                guard let self = self else { return }
                
                var savedPuzzles = self.loadCustomPuzzlesFromStorage() ?? []
                
                if let index = savedPuzzles.firstIndex(where: { $0.id == puzzle.id }) {
                    savedPuzzles[index] = puzzle
                } else {
                    savedPuzzles.append(puzzle)
                }
                
                do {
                    let data = try self.encoder.encode(savedPuzzles)
                    let compressedData = try data.compressed()
                    UserDefaults.standard.set(compressedData, forKey: StorageKeys.savedCustomPuzzles)
                } catch {
                    print("❌ Error saving custom puzzle: \(error)")
                }
            }
        }
    }
    
    func getSavedCustomPuzzles() -> [SavedCustomPuzzle]? {
        return loadCustomPuzzlesFromStorage()
    }
    
    private func loadCustomPuzzlesFromStorage() -> [SavedCustomPuzzle]? {
        guard let compressedData = UserDefaults.standard.data(forKey: StorageKeys.savedCustomPuzzles) else {
            return nil
        }
        
        do {
            let data = try compressedData.decompressed()
            return try decoder.decode([SavedCustomPuzzle].self, from: data)
        } catch {
            print("❌ Error retrieving custom puzzles: \(error)")
            return nil
        }
    }
    
    // MARK: - App Settings Management
    
    func saveAppSettings(settings: AppSettings) {
        Task { [weak self] in
            await self?.saveAppSettingsAsync(settings: settings)
        }
    }
    
    private func saveAppSettingsAsync(settings: AppSettings) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storageQueue.async { [weak self] in
                defer { continuation.resume() }
                
                guard let self = self else { return }
                
                do {
                    let data = try self.encoder.encode(settings)
                    UserDefaults.standard.set(data, forKey: StorageKeys.appSettings)
                } catch {
                    print("❌ Error saving app settings: \(error)")
                }
            }
        }
    }
    
    func getAppSettings() -> AppSettings? {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.appSettings) else {
            return nil
        }
        
        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("❌ Error retrieving app settings: \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management and Cleanup
    
    private func loadCacheAsync() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                if let puzzles = await self?.loadPuzzlesFromStorage() {
                    await MainActor.run { [weak self] in
                        self?.puzzleCache = puzzles
                    }
                }
            }
            
            group.addTask { [weak self] in
                guard let self = self else { return }
                if let progress = await self.loadProgressFromStorage() {
                    await MainActor.run { [weak self] in
                        for record in progress {
                            self?.progressCache[record.puzzleId] = record
                        }
                    }
                }
            }
            
            group.addTask { [weak self] in
                if let customPuzzles = await Task.detached { [weak self] in
                    return await self?.loadCustomPuzzlesFromStorage()
                }.value {
                    await MainActor.run { [weak self] in
                        for puzzle in customPuzzles {
                            self?.customPuzzleCache[String(puzzle.id)] = puzzle
                        }
                    }
                }
            }
        }
        
        lastCacheUpdate = Date()
    }
    
    private func cleanupExpiredCache() async {
        let now = Date()
        
        // Clean progress cache - keep only recent entries
        let recentProgressThreshold = now.addingTimeInterval(-24 * 60 * 60) // 24 hours
        progressCache = progressCache.filter { $0.value.timestamp > recentProgressThreshold }
        
        // Limit cache sizes
        if progressCache.count > maxCacheSize {
            let sortedProgress = progressCache.sorted { $0.value.timestamp > $1.value.timestamp }
            progressCache = Dictionary(uniqueKeysWithValues: Array(sortedProgress.prefix(maxCacheSize)))
        }
        
        if customPuzzleCache.count > maxCacheSize {
            // Keep custom puzzles as they're user-created
            let sortedCustom = customPuzzleCache.sorted { (first: (key: String, value: SavedCustomPuzzle), second: (key: String, value: SavedCustomPuzzle)) in 
                first.value.puzzleName < second.value.puzzleName
            }
            customPuzzleCache = Dictionary(uniqueKeysWithValues: Array(sortedCustom.prefix(maxCacheSize)))
        }
    }
    
    func clearAllData() {
        Task { [weak self] in
            await self?.clearAllDataAsync()
        }
    }
    
    private func clearAllDataAsync() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await MainActor.run { [weak self] in
                    // Clear in-memory caches
                    self?.puzzleCache.removeAll()
                    self?.progressCache.removeAll()
                    self?.customPuzzleCache.removeAll()
                    self?.puzzleCount = 0
                }
            }
            
            group.addTask {
                // Clear persistent storage
                UserDefaults.standard.removeObject(forKey: StorageKeys.storedPuzzles)
                UserDefaults.standard.removeObject(forKey: StorageKeys.savedProgress)
                UserDefaults.standard.removeObject(forKey: StorageKeys.savedCustomPuzzles)
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    func getStorageMetrics() -> StorageMetrics {
        let puzzleDataSize = estimateDataSize(puzzleCache)
        let progressDataSize = estimateDataSize(progressCache)
        let customPuzzleDataSize = estimateDataSize(customPuzzleCache)
        
        return StorageMetrics(
            puzzleCount: puzzleCount,
            progressRecordCount: progressCache.count,
            customPuzzleCount: customPuzzleCache.count,
            puzzleDataSize: puzzleDataSize,
            progressDataSize: progressDataSize,
            customPuzzleDataSize: customPuzzleDataSize,
            lastCacheUpdate: lastCacheUpdate
        )
    }
    
    private func estimateDataSize<T: Encodable>(_ data: T) -> Int {
        do {
            let encoded = try encoder.encode(data)
            return encoded.count
        } catch {
            return 0
        }
    }
}

// MARK: - Data Compression Extensions

extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .lzfse) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .lzfse) as Data
    }
}

// MARK: - Supporting Types

struct StorageMetrics {
    let puzzleCount: Int
    let progressRecordCount: Int
    let customPuzzleCount: Int
    let puzzleDataSize: Int
    let progressDataSize: Int
    let customPuzzleDataSize: Int
    let lastCacheUpdate: Date
    
    var totalDataSize: Int {
        return puzzleDataSize + progressDataSize + customPuzzleDataSize
    }
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalDataSize))
    }
}
