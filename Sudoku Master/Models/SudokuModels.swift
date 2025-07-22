import Foundation
import SwiftUI

// SudokuGrid represents a 9x9 Sudoku grid
typealias SudokuGrid = [[Int?]]

// Difficulty levels for Sudoku puzzles
enum SudokuDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var cellsToRemove: Int {
        switch self {
        case .easy: return 35  // Shows 46 cells
        case .medium: return 45  // Shows 36 cells
        case .hard: return 55  // Shows 26 cells
        }
    }
    
    // UI-related properties
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .easy: return "1.square"
        case .medium: return "2.square"
        case .hard: return "3.square"
        }
    }
    
    // Expected completion times in seconds for each difficulty level
    var expectedCompletionTime: Int {
        switch self {
        case .easy: return 300  // 5 minutes
        case .medium: return 600  // 10 minutes
        case .hard: return 1200 // 20 minutes
        }
    }
    
    // Error tolerance rate for each difficulty level
    var errorTolerance: Double {
        switch self {
        case .easy: return 0.4  // 40% error tolerance
        case .medium: return 0.3  // 30% error tolerance
        case .hard: return 0.2  // 20% error tolerance
        }
    }
    
    // Skill level range for each difficulty
    var skillRange: ClosedRange<Int> {
        switch self {
        case .easy: return 0...35
        case .medium: return 36...70
        case .hard: return 71...100
        }
    }
    
    // Challenge score based on difficulty (used in adaptive system)
    var challengeScore: Int {
        switch self {
        case .easy: return 1
        case .medium: return 3
        case .hard: return 6
        }
    }
    
    // Check if skill level is appropriate for this difficulty
    func isAppropriateFor(skillLevel: Int) -> Bool {
        return skillRange.contains(skillLevel)
    }
    
    // Learning tips for each difficulty level
    var learningTips: [String] {
        switch self {
        case .easy:
            return [
                "Focus on scanning techniques to identify obvious placements",
                "Look for rows, columns, or boxes with many filled cells",
                "Practice the single candidate technique"
            ]
        case .medium:
            return [
                "Learn about 'candidate pairs' to eliminate possibilities",
                "Use the 'pointing pair' technique to narrow down options",
                "Practice 'box/line reduction' for more complex puzzles"
            ]
        case .hard:
            return [
                "Master X-Wing and Y-Wing techniques for complex eliminations",
                "Use 'forcing chains' to identify contradictions",
                "Try the 'Swordfish' technique for advanced puzzles"
            ]
        }
    }
    
    // Get appropriate skill description based on skill level
    static func getSkillDescription(for skillLevel: Int) -> String {
        switch skillLevel {
        case 0...20: return "Beginner"
        case 21...40: return "Casual Player"
        case 41...60: return "Intermediate"
        case 61...80: return "Advanced"
        case 81...90: return "Expert"
        case 91...100: return "Master"
        default: return "Unknown"
        }
    }
    
    // Progression hint for advancing to next difficulty level
    var progressionHint: String {
        switch self {
        case .easy:
            return "Try to improve your solving time and minimize errors to advance to Medium difficulty."
        case .medium:
            return "Practice recognizing advanced patterns and techniques to prepare for Hard puzzles."
        case .hard:
            return "Continue mastering advanced techniques to improve your Sudoku mastery."
        }
    }
}

// A cell position in the Sudoku grid
struct CellPosition: Equatable, Hashable {
    let row: Int
    let col: Int
}

// Represents a complete Sudoku puzzle
struct SudokuPuzzle: Identifiable, Codable {
    let id: Int
    let grid: SudokuGrid
    let solution: SudokuGrid
    let difficulty: SudokuDifficulty
    
    // For local puzzles
    var puzzleId: String {
        return "\(id)-\(difficulty.rawValue)"
    }
}

// Theme options
enum ThemeOption: String, CaseIterable, Identifiable, Codable {
    case `default` = "default"
    case starwars = "starwars"
    case minecraft = "minecraft"
    case mario = "mario"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .starwars: return "Star Wars"
        case .minecraft: return "Minecraft"
        case .mario: return "Mario"
        }
    }
}

// User model
struct User: Identifiable, Codable {
    let id: Int
    let username: String
    var theme: ThemeOption
}

// User statistics
struct UserStats: Identifiable, Codable {
    let id: Int
    let userId: Int
    let eloRating: Int
    let gamesPlayed: Int
    let gamesWon: Int
    let averageTimeSeconds: Int

    // Normalized rating between 1-100
    var normalizedRating: Int {
        let minElo: Double = 400 // Minimum possible Elo
        let maxElo: Double = 2000 // Maximum expected Elo
        let normalized = ((Double(eloRating) - minElo) / (maxElo - minElo)) * 100
        return Int(min(100.0, max(1.0, normalized)).rounded())
    }
}

// Represents an ongoing game
struct GameplayRecord: Identifiable, Codable {
    let id: Int
    let userId: Int
    let puzzleId: Int
    let currentGrid: SudokuGrid
    let isCompleted: Bool
    let timeSpentSeconds: Int
    let createdAt: Date
    
    // For tracking local progress
    var localId: String {
        return "\(puzzleId)-\(userId)"
    }
}

// Saved puzzle for later play
struct SavedPuzzle: Identifiable, Codable {
    let id: Int
    let userId: Int
    let puzzleId: Int
    let puzzleName: String
    let currentGrid: SudokuGrid
    let originalGrid: SudokuGrid
    let difficulty: SudokuDifficulty
    let createdAt: Date
}

// Model for storing game progress in UserDefaults
struct StoredGameRecord: Codable {
    let puzzleId: Int
    let userId: Int?
    let currentGrid: SudokuGrid
    let originalGrid: SudokuGrid
    let difficulty: SudokuDifficulty
    let isCompleted: Bool
    let timeSpentSeconds: Int
    let timestamp: Date
}

// Model for saved custom puzzle in UserDefaults
struct SavedCustomPuzzle: Codable, Identifiable {
    let id: Int
    let puzzleName: String
    let originalGrid: SudokuGrid
    let currentGrid: SudokuGrid
    let difficulty: SudokuDifficulty
    let createdAt: Date
}

// Model for app settings
struct AppSettings: Codable {
    let theme: ThemeOption
    let soundEnabled: Bool
    let hapticEnabled: Bool
}
