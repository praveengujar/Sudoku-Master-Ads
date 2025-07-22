import Foundation
import SwiftUI

// Class for managing offline storage and synchronization
class OfflineStorage: ObservableObject {
    @Published var isOfflineMode = false
    @Published var isManualOfflineMode = false
    @Published var puzzleCount = 0
    
    private let userDefaults = UserDefaults.standard
    private let offlineModeKey = "isManualOfflineMode"
    private let storedPuzzlesKey = "storedPuzzles"
    private let savedProgressKey = "savedGameProgress"
    private let savedPuzzlesKey = "savedCustomPuzzles"
    private let appSettingsKey = "appSettings"
    
    init() {
        isManualOfflineMode = userDefaults.bool(forKey: offlineModeKey)
        updateOfflineStatus()
        countStoredPuzzles()
    }
    
    func updateOfflineStatus(networkConnected: Bool = true) {
        // If user has enabled manual offline mode, stay offline regardless of connection
        // If not in manual mode, offline status depends on network connectivity
        isOfflineMode = isManualOfflineMode || !networkConnected
    }
    
    func toggleOfflineMode() {
        isManualOfflineMode.toggle()
        userDefaults.set(isManualOfflineMode, forKey: offlineModeKey)
        updateOfflineStatus()
    }
    
    func countStoredPuzzles() {
        if let storedData = userDefaults.data(forKey: storedPuzzlesKey),
           let puzzles = try? JSONDecoder().decode([String: [SudokuPuzzle]].self, from: storedData) {
            var count = 0
            for (_, difficultyPuzzles) in puzzles {
                count += difficultyPuzzles.count
            }
            puzzleCount = count
        } else {
            puzzleCount = 0
        }
    }
    
    func savePuzzles(puzzles: [String: [SudokuPuzzle]]) -> Bool {
        do {
            let encodedData = try JSONEncoder().encode(puzzles)
            userDefaults.set(encodedData, forKey: storedPuzzlesKey)
            countStoredPuzzles()
            return true
        } catch {
            print("Error saving puzzles: \(error.localizedDescription)")
            return false
        }
    }
    
    func getStoredPuzzles() -> [String: [SudokuPuzzle]]? {
        guard let storedData = userDefaults.data(forKey: storedPuzzlesKey) else {
            return nil
        }
        
        do {
            let puzzles = try JSONDecoder().decode([String: [SudokuPuzzle]].self, from: storedData)
            return puzzles
        } catch {
            print("Error retrieving puzzles: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getPuzzleByDifficulty(difficulty: SudokuDifficulty) -> SudokuPuzzle? {
        guard let puzzles = getStoredPuzzles() else { return nil }
        let difficultyPuzzles = puzzles[difficulty.rawValue] ?? []
        
        if difficultyPuzzles.isEmpty {
            return nil
        }
        
        // Return a random puzzle from the available ones
        return difficultyPuzzles.randomElement()
    }
    
    func saveGameProgress(record: StoredGameRecord) {
        var savedRecords = getSavedGameProgress() ?? []
        
        // Check if a record with the same puzzle ID already exists and update it
        if let index = savedRecords.firstIndex(where: { $0.puzzleId == record.puzzleId }) {
            savedRecords[index] = record
        } else {
            savedRecords.append(record)
        }
        
        do {
            let encodedData = try JSONEncoder().encode(savedRecords)
            userDefaults.set(encodedData, forKey: savedProgressKey)
        } catch {
            print("Error saving game progress: \(error.localizedDescription)")
        }
    }
    
    func getSavedGameProgress() -> [StoredGameRecord]? {
        guard let storedData = userDefaults.data(forKey: savedProgressKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([StoredGameRecord].self, from: storedData)
        } catch {
            print("Error retrieving game progress: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getLastPlayedPuzzle() -> StoredGameRecord? {
        guard let savedRecords = getSavedGameProgress(), !savedRecords.isEmpty else {
            return nil
        }
        
        // Return the most recently saved record
        return savedRecords.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    func saveCustomPuzzle(puzzle: SavedCustomPuzzle) {
        var savedPuzzles = getSavedCustomPuzzles() ?? []
        
        // Check if a puzzle with the same ID exists and update it
        if let index = savedPuzzles.firstIndex(where: { $0.id == puzzle.id }) {
            savedPuzzles[index] = puzzle
        } else {
            savedPuzzles.append(puzzle)
        }
        
        do {
            let encodedData = try JSONEncoder().encode(savedPuzzles)
            userDefaults.set(encodedData, forKey: savedPuzzlesKey)
        } catch {
            print("Error saving custom puzzle: \(error.localizedDescription)")
        }
    }
    
    func getSavedCustomPuzzles() -> [SavedCustomPuzzle]? {
        guard let storedData = userDefaults.data(forKey: savedPuzzlesKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([SavedCustomPuzzle].self, from: storedData)
        } catch {
            print("Error retrieving custom puzzles: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveAppSettings(settings: AppSettings) {
        do {
            let encodedData = try JSONEncoder().encode(settings)
            userDefaults.set(encodedData, forKey: appSettingsKey)
        } catch {
            print("Error saving app settings: \(error.localizedDescription)")
        }
    }
    
    func getAppSettings() -> AppSettings? {
        guard let storedData = userDefaults.data(forKey: appSettingsKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(AppSettings.self, from: storedData)
        } catch {
            print("Error retrieving app settings: \(error.localizedDescription)")
            return nil
        }
    }
    
    func clearAllData() {
        userDefaults.removeObject(forKey: storedPuzzlesKey)
        userDefaults.removeObject(forKey: savedProgressKey)
        userDefaults.removeObject(forKey: savedPuzzlesKey)
        puzzleCount = 0
    }
}