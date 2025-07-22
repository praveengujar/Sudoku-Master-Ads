import Foundation
import SwiftUI

class SudokuStore: ObservableObject {
    // MARK: - Published Properties
    
    // Game state
    @Published var grid: SudokuGrid = Array(repeating: Array(repeating: nil, count: 9), count: 9)
    @Published var originalGrid: SudokuGrid = Array(repeating: Array(repeating: nil, count: 9), count: 9)
    @Published var selectedCell: (row: Int?, col: Int?) = (nil, nil)
    @Published var difficulty: SudokuDifficulty = .easy
    @Published var errors: [CellPosition: Bool] = [:]
    @Published var hintCell: (row: Int?, col: Int?, value: Int?) = (nil, nil, nil)
    
    // Game status
    @Published var isLoading = false
    @Published var isVictory = false
    @Published var showVictoryAlert = false
    @Published var errorMessage: String?
    @Published var timeSpentSeconds = 0
    @Published var puzzleId: Int?
    
    // Offline mode properties
    @Published var isOfflineMode = false
    
    // Timer
    private var timer: Timer?
    
    // MARK: - Initialization
    
    init() {
        startTimer()
        // Load a test puzzle immediately so users can start playing
        loadTestPuzzle()
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - Game Actions
    
    func newGame() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isOfflineMode {
                    await loadOfflinePuzzle()
                } else {
                    let puzzle = try await APIService.shared.generatePuzzle(difficulty: difficulty)
                    await MainActor.run {
                        self.grid = puzzle.grid
                        self.originalGrid = puzzle.grid
                        self.puzzleId = puzzle.id
                        resetGameState()
                        isLoading = false
                        print("Successfully loaded puzzle with \(puzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
                    }
                }
            } catch {
                print("Error loading puzzle: \(error)")
                
                // Try to load a fallback puzzle if online mode fails
                if !isOfflineMode {
                    print("Attempting to switch to offline mode as fallback")
                    await MainActor.run {
                        self.isOfflineMode = true
                        // Clear the error message before attempting fallback
                        self.errorMessage = nil
                    }
                    await loadOfflinePuzzle()
                } else {
                    // If already in offline mode and still failing, show error
                    await MainActor.run {
                        self.errorMessage = "Failed to load puzzle: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    @MainActor
    private func loadOfflinePuzzle() async {
        guard let offlineStorage = (UIApplication.shared.delegate as? AppDelegate)?.offlineStorage else {
            errorMessage = "Offline storage not available"
            isLoading = false
            return
        }
        
        if let puzzle = offlineStorage.getPuzzleByDifficulty(difficulty: difficulty) {
            self.grid = puzzle.grid
            self.originalGrid = puzzle.grid
            self.puzzleId = puzzle.id
            resetGameState()
            isLoading = false
            print("Successfully loaded offline puzzle with \(puzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
        } else {
            errorMessage = "No offline puzzles available for \(difficulty.displayName) difficulty. Loading fallback puzzle..."
            print("No offline puzzles available for difficulty: \(difficulty.displayName), creating fallback puzzle")
            
            // Create a simple fallback puzzle
            let fallbackPuzzle = createFallbackPuzzle()
            self.grid = fallbackPuzzle.grid
            self.originalGrid = fallbackPuzzle.grid
            self.puzzleId = fallbackPuzzle.id
            resetGameState()
            isLoading = false
            print("Created fallback puzzle with \(fallbackPuzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
        }
    }
    
    func loadCustomPuzzle(customGrid: SudokuGrid, customSolution: SudokuGrid? = nil) {
        self.originalGrid = customGrid
        self.grid = customGrid
        
        // If no solution is provided, attempt to solve the puzzle
        if let solution = customSolution {
            // Use the provided solution
            resetGameState()
        } else {
            // Solve the puzzle to verify it's solvable
            Task {
                do {
                    let solution = try await solveGrid(customGrid)
                    if solution.isEmpty {
                        await MainActor.run {
                            self.errorMessage = "Custom puzzle is not solvable"
                        }
                    } else {
                        await MainActor.run {
                            resetGameState()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Error validating custom puzzle: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func setSelectedCell(row: Int?, col: Int?) {
        print("Selecting cell at (\(row ?? -1), \(col ?? -1))")
        selectedCell = (row, col)
    }
    
    func setDifficulty(_ difficulty: SudokuDifficulty) {
        self.difficulty = difficulty
    }
    
    func enterNumber(_ number: Int) {
        guard let row = selectedCell.row, let col = selectedCell.col else { 
            print("No cell selected")
            return 
        }
        
        // Don't allow changing original cells
        if originalGrid[row][col] != nil {
            print("Cannot modify original cell at (\(row), \(col))")
            return
        }
        
        print("Entering number \(number) at position (\(row), \(col))")
        grid[row][col] = number
        
        // Validate the move
        Task {
            await validateMove(row: row, col: col, value: number)
        }
    }
    
    func eraseNumber() {
        guard let row = selectedCell.row, let col = selectedCell.col else { return }
        
        // Don't allow erasing original cells
        if originalGrid[row][col] != nil {
            return
        }
        
        grid[row][col] = nil
        
        // Remove any error for this cell
        let position = CellPosition(row: row, col: col)
        errors.removeValue(forKey: position)
    }
    
    func getHint() {
        guard let row = selectedCell.row, let col = selectedCell.col else { return }
        
        // Don't give hints for original cells or cells that already have a value
        if originalGrid[row][col] != nil || grid[row][col] != nil {
            return
        }
        
        // Get the solution for the current grid
        Task {
            do {
                let solution = try await solveGrid(grid)
                if !solution.isEmpty {
                    await MainActor.run {
                        let hintValue = solution[row][col]
                        self.hintCell = (row, col, hintValue)
                        
                        // Clear the hint after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.hintCell = (nil, nil, nil)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to generate hint: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func autoSolve() {
        Task {
            do {
                let solution = try await solveGrid(grid)
                if !solution.isEmpty {
                    await MainActor.run {
                        self.grid = solution
                        // Don't show victory animation for auto-solved puzzles
                        checkVictoryWithoutAnimation()
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Puzzle cannot be solved from current state"
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to solve puzzle: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func clearUserInputs() {
        // Reset to original state, keeping only the original values
        for row in 0..<9 {
            for col in 0..<9 {
                if originalGrid[row][col] == nil {
                    grid[row][col] = nil
                }
            }
        }
        
        // Clear errors
        errors.removeAll()
    }
    
    func closeVictoryModal() {
        showVictoryAlert = false
    }
    
    // MARK: - Game Logic
    
    private func resetGameState() {
        selectedCell = (nil, nil)
        errors.removeAll()
        hintCell = (nil, nil, nil)
        isVictory = false
        showVictoryAlert = false
        errorMessage = nil
        timeSpentSeconds = 0
        restartTimer()
    }
    
    @MainActor
    private func validateMove(row: Int, col: Int, value: Int) async {
        do {
            if isOfflineMode {
                // Validate locally
                let position = CellPosition(row: row, col: col)
                let isValid = validateLocalMove(row: row, col: col, value: value)
                errors[position] = !isValid
            } else {
                // Validate via API
                let isValid = try await APIService.shared.validateMove(grid: grid, row: row, col: col, value: value)
                let position = CellPosition(row: row, col: col)
                errors[position] = !isValid
            }
            
            // Check if the puzzle is complete after the move
            checkVictory()
            
        } catch {
            errorMessage = "Failed to validate move: \(error.localizedDescription)"
        }
    }
    
    private func validateLocalMove(row: Int, col: Int, value: Int) -> Bool {
        // Check row
        for c in 0..<9 where c != col {
            if grid[row][c] == value {
                return false
            }
        }
        
        // Check column
        for r in 0..<9 where r != row {
            if grid[r][col] == value {
                return false
            }
        }
        
        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        
        for r in boxRow..<boxRow+3 {
            for c in boxCol..<boxCol+3 {
                if r != row && c != col && grid[r][c] == value {
                    return false
                }
            }
        }
        
        return true
    }
    
    func checkVictory() {
        // Check if the grid is completely filled
        let allFilled = grid.allSatisfy { row in
            row.allSatisfy { $0 != nil }
        }
        
        // Check if there are no errors
        let noErrors = errors.allSatisfy { !$0.value }
        
        if allFilled && noErrors {
            isVictory = true
            showVictoryAlert = true
            stopTimer()
            
            // Save game progress
            saveProgress(isCompleted: true)
        }
    }
    
    private func checkVictoryWithoutAnimation() {
        // Check if the grid is completely filled
        let allFilled = grid.allSatisfy { row in
            row.allSatisfy { $0 != nil }
        }
        
        // Check if there are no errors
        let noErrors = errors.allSatisfy { !$0.value }
        
        if allFilled && noErrors {
            isVictory = true
            stopTimer()
            
            // Save game progress but don't show animation
            saveProgress(isCompleted: true)
        }
    }
    
    private func solveGrid(_ grid: SudokuGrid) async throws -> SudokuGrid {
        if isOfflineMode {
            return solveLocalGrid(grid)
        } else {
            return try await APIService.shared.solvePuzzle(grid: grid)
        }
    }
    
    private func solveLocalGrid(_ grid: SudokuGrid) -> SudokuGrid {
        // Simple backtracking solver
        var gridCopy = grid
        
        func isValid(row: Int, col: Int, num: Int) -> Bool {
            // Check row
            for c in 0..<9 {
                if gridCopy[row][c] == num {
                    return false
                }
            }
            
            // Check column
            for r in 0..<9 {
                if gridCopy[r][col] == num {
                    return false
                }
            }
            
            // Check 3x3 box
            let boxRow = (row / 3) * 3
            let boxCol = (col / 3) * 3
            
            for r in boxRow..<boxRow+3 {
                for c in boxCol..<boxCol+3 {
                    if gridCopy[r][c] == num {
                        return false
                    }
                }
            }
            
            return true
        }
        
        func solve() -> Bool {
            for row in 0..<9 {
                for col in 0..<9 {
                    if gridCopy[row][col] == nil {
                        for num in 1...9 {
                            if isValid(row: row, col: col, num: num) {
                                gridCopy[row][col] = num
                                
                                if solve() {
                                    return true
                                }
                                
                                gridCopy[row][col] = nil
                            }
                        }
                        return false
                    }
                }
            }
            return true
        }
        
        if solve() {
            return gridCopy
        } else {
            return []
        }
    }
    
    // MARK: - Timer management
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeSpentSeconds += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        stopTimer()
        startTimer()
    }
    
    // MARK: - Data Persistence
    
    func saveProgress(isCompleted: Bool) {
        guard let puzzleId = puzzleId else { return }
        
        Task {
            do {
                if isOfflineMode {
                    saveLocalProgress(isCompleted: isCompleted)
                } else {
                    if let userId = (UIApplication.shared.delegate as? AppDelegate)?.authManager.currentUser?.id {
                        let _ = try await APIService.shared.saveGameProgress(
                            userId: userId,
                            puzzleId: puzzleId,
                            currentGrid: grid,
                            isCompleted: isCompleted,
                            timeSpentSeconds: timeSpentSeconds
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save progress: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveLocalProgress(isCompleted: Bool) {
        guard let puzzleId = puzzleId else { return }
        guard let offlineStorage = (UIApplication.shared.delegate as? AppDelegate)?.offlineStorage else { return }
        
        let userId = (UIApplication.shared.delegate as? AppDelegate)?.authManager.currentUser?.id
        
        let record = StoredGameRecord(
            puzzleId: puzzleId,
            userId: userId,
            currentGrid: grid,
            originalGrid: originalGrid,
            difficulty: difficulty,
            isCompleted: isCompleted,
            timeSpentSeconds: timeSpentSeconds,
            timestamp: Date()
        )
        
        offlineStorage.saveGameProgress(record: record)
    }
    
    // MARK: - Fallback Puzzle Creation
    
    private func createFallbackPuzzle() -> SudokuPuzzle {
        // Create a simple valid Sudoku puzzle
        let grid: SudokuGrid = [
            [5, 3, nil, nil, 7, nil, nil, nil, nil],
            [6, nil, nil, 1, 9, 5, nil, nil, nil],
            [nil, 9, 8, nil, nil, nil, nil, 6, nil],
            [8, nil, nil, nil, 6, nil, nil, nil, 3],
            [4, nil, nil, 8, nil, 3, nil, nil, 1],
            [7, nil, nil, nil, 2, nil, nil, nil, 6],
            [nil, 6, nil, nil, nil, nil, 2, 8, nil],
            [nil, nil, nil, 4, 1, 9, nil, nil, 5],
            [nil, nil, nil, nil, 8, nil, nil, 7, 9]
        ]
        
        // Create a solution (this is a valid Sudoku solution)
        let solution: SudokuGrid = [
            [5, 3, 4, 6, 7, 8, 9, 1, 2],
            [6, 7, 2, 1, 9, 5, 3, 4, 8],
            [1, 9, 8, 3, 4, 2, 5, 6, 7],
            [8, 5, 9, 7, 6, 1, 4, 2, 3],
            [4, 2, 6, 8, 5, 3, 7, 9, 1],
            [7, 1, 3, 9, 2, 4, 8, 5, 6],
            [9, 6, 1, 5, 3, 7, 2, 8, 4],
            [2, 8, 7, 4, 1, 9, 6, 3, 5],
            [3, 4, 5, 2, 8, 6, 1, 7, 9]
        ]
        
        return SudokuPuzzle(id: -1, grid: grid, solution: solution, difficulty: difficulty)
    }
    
    // MARK: - Debug Methods
    
    func loadTestPuzzle() {
        isLoading = true
        errorMessage = nil
        
        let testPuzzle = createFallbackPuzzle()
        self.grid = testPuzzle.grid
        self.originalGrid = testPuzzle.grid
        self.puzzleId = testPuzzle.id
        resetGameState()
        isLoading = false
        print("Loaded test puzzle with \(testPuzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
    }
    
    // MARK: - Offline Mode
    
    func setOfflineMode(isOffline: Bool) {
        isOfflineMode = isOffline
    }
    
    func downloadPuzzlesForOfflinePlay() async -> Bool {
        guard !isOfflineMode else { return false }
        guard let offlineStorage = (UIApplication.shared.delegate as? AppDelegate)?.offlineStorage else { return false }
        
        var puzzlesByDifficulty: [String: [SudokuPuzzle]] = [:]
        
        for difficulty in SudokuDifficulty.allCases {
            var puzzles: [SudokuPuzzle] = []
            
            // Download 5 puzzles for each difficulty
            for _ in 0..<5 {
                do {
                    let puzzle = try await APIService.shared.generatePuzzle(difficulty: difficulty)
                    puzzles.append(puzzle)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to download puzzles: \(error.localizedDescription)"
                    }
                    return false
                }
            }
            
            puzzlesByDifficulty[difficulty.rawValue] = puzzles
        }
        
        return offlineStorage.savePuzzles(puzzles: puzzlesByDifficulty)
    }
}

// MARK: - API Extensions

extension APIService {
    func validateMove(grid: SudokuGrid, row: Int, col: Int, value: Int) async throws -> Bool {
        let endpoint = "\(baseURL)/sudoku/validate"
        let body = ValidateMoveRequest(grid: grid, row: row, col: col, value: value)
        let response: [String: Bool] = try await performRequest(endpoint: endpoint, method: "POST", body: body)
        return response["isValid"] ?? false
    }
    
    func solvePuzzle(grid: SudokuGrid) async throws -> SudokuGrid {
        let endpoint = "\(baseURL)/sudoku/solve"
        let body = SolvePuzzleRequest(grid: grid)
        let response: [String: SudokuGrid] = try await performRequest(endpoint: endpoint, method: "POST", body: body)
        return response["solution"] ?? []
    }
}
