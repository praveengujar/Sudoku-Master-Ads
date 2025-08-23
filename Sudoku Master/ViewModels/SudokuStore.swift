import Foundation
import SwiftUI
import Combine

@MainActor
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
    
    // Performance optimizations
    private var isTimerActive = false
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var validationDebouncer = PassthroughSubject<(Int, Int, Int), Never>()
    
    // Cache for validation results
    private var validationCache: [String: Bool] = [:]
    private let maxCacheSize = 100
    
    // Dependencies - using weak references to prevent retain cycles
    private weak var offlineStorage: OfflineStorage?
    private weak var authManager: AuthManager?
    private weak var adManager: AdManager?
    
    // Ad integration tracking
    private var gamesCompleted = 0
    private var adsShownCount = 0
    private let adFrequency = 3 // Show ad every 3 completed games
    
    // Background queue for heavy operations
    private let backgroundQueue = DispatchQueue(label: "sudoku.background", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init() {
        setupValidationDebouncer()
        loadTestPuzzle()
    }
    
    func setDependencies(offlineStorage: OfflineStorage, authManager: AuthManager) {
        self.offlineStorage = offlineStorage
        self.authManager = authManager
        self.adManager = AdManager.shared
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Performance Optimizations
    
    private func setupValidationDebouncer() {
        validationDebouncer
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] row, col, value in
                Task { [weak self] in
                    await self?.performValidation(row: row, col: col, value: value)
                }
            }
            .store(in: &cancellables)
    }
    
    private func getCacheKey(grid: SudokuGrid, row: Int, col: Int, value: Int) -> String {
        let gridHash = grid.flatMap { $0.map { $0?.description ?? "nil" } }.joined()
        return "\(gridHash)_\(row)_\(col)_\(value)"
    }
    
    private func cacheValidationResult(key: String, result: Bool) {
        if validationCache.count >= maxCacheSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = Array(validationCache.keys.prefix(maxCacheSize / 2))
            keysToRemove.forEach { validationCache.removeValue(forKey: $0) }
        }
        validationCache[key] = result
    }
    
    // MARK: - Game Actions (Optimized)
    
    func newGame() {
        print("🎯 Starting new game with difficulty: \(difficulty.rawValue), offline mode: \(isOfflineMode)")
        isLoading = true
        errorMessage = nil
        
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                if self.isOfflineMode {
                    print("🎯 Using offline mode")
                    await self.loadOfflinePuzzle()
                } else {
                    print("🎯 Using online mode - calling API")
                    let puzzle = try await APIService.shared.generatePuzzle(difficulty: self.difficulty)
                    await self.updateGameState(with: puzzle)
                }
            } catch {
                await self.handleGameLoadError(error)
            }
        }
    }
    
    @MainActor
    private func updateGameState(with puzzle: SudokuPuzzle) async {
        self.grid = puzzle.grid
        self.originalGrid = puzzle.grid
        self.puzzleId = puzzle.id
        resetGameState()
        isLoading = false
        print("🎯 Successfully loaded API puzzle with \(puzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
    }
    
    @MainActor
    private func handleGameLoadError(_ error: Error) async {
        print("🎯 Error loading puzzle: \(error)")
        
        if !isOfflineMode {
            print("🎯 API failed - switching to offline mode as fallback")
            self.isOfflineMode = true
            self.errorMessage = nil
            await loadOfflinePuzzle()
        } else {
            self.errorMessage = "Failed to load puzzle: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    @MainActor
    private func loadOfflinePuzzle() async {
        guard let offlineStorage = offlineStorage else {
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
            await loadFallbackPuzzle()
        }
    }
    
    @MainActor
    private func loadFallbackPuzzle() async {
        errorMessage = "No offline puzzles available for \(difficulty.displayName) difficulty. Loading fallback puzzle..."
        print("No offline puzzles available for difficulty: \(difficulty.displayName), creating fallback puzzle")
        
        // Create fallback puzzle on background queue to avoid blocking UI
        let fallbackPuzzle = await withTaskGroup(of: SudokuPuzzle.self) { group in
            group.addTask { [weak self] in
                return await self?.createFallbackPuzzleAsync() ?? SudokuPuzzle(id: -1, grid: [], solution: [], difficulty: .easy)
            }
            return await group.first(where: { _ in true }) ?? SudokuPuzzle(id: -1, grid: [], solution: [], difficulty: .easy)
        }
        
        self.grid = fallbackPuzzle.grid
        self.originalGrid = fallbackPuzzle.grid
        self.puzzleId = fallbackPuzzle.id
        resetGameState()
        isLoading = false
        print("Created fallback puzzle with \(fallbackPuzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
    }
    
    func loadCustomPuzzle(customGrid: SudokuGrid, customSolution: SudokuGrid? = nil) {
        self.originalGrid = customGrid
        self.grid = customGrid
        
        if let solution = customSolution {
            resetGameState()
        } else {
            Task { [weak self] in
                do {
                    let solution = try await self?.solveGrid(customGrid) ?? []
                    await MainActor.run { [weak self] in
                        if solution.isEmpty {
                            self?.errorMessage = "Custom puzzle is not solvable"
                        } else {
                            self?.resetGameState()
                        }
                    }
                } catch {
                    await MainActor.run { [weak self] in
                        self?.errorMessage = "Error validating custom puzzle: \(error.localizedDescription)"
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
        print("🎯 Setting difficulty to: \(difficulty.rawValue)")
        self.difficulty = difficulty
        newGame()
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
        
        // Use debounced validation to improve performance
        validationDebouncer.send((row, col, number))
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
        
        Task { [weak self] in
            do {
                let solution = try await self?.solveGrid(self?.grid ?? []) ?? []
                await MainActor.run { [weak self] in
                    if !solution.isEmpty {
                        let hintValue = solution[row][col]
                        self?.hintCell = (row, col, hintValue)
                        
                        // Clear the hint after 3 seconds
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            await MainActor.run {
                                self?.hintCell = (nil, nil, nil)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to generate hint: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func autoSolve() {
        Task { [weak self] in
            do {
                let solution = try await self?.solveGrid(self?.grid ?? []) ?? []
                await MainActor.run { [weak self] in
                    if !solution.isEmpty {
                        self?.grid = solution
                        self?.checkVictoryWithoutAnimation()
                    } else {
                        self?.errorMessage = "Puzzle cannot be solved from current state"
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to solve puzzle: \(error.localizedDescription)"
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
        
        // Clear errors and cache
        errors.removeAll()
        validationCache.removeAll()
    }
    
    func closeVictoryModal() {
        showVictoryAlert = false
        gamesCompleted += 1
        
        // Show interstitial ad based on frequency and performance optimization
        Task { [weak self] in
            await self?.handlePostVictoryAd()
        }
    }
    
    private func handlePostVictoryAd() async {
        guard let adManager = adManager else { return }
        
        // Show ad every X completed games to balance UX and revenue
        if gamesCompleted >= adFrequency && gamesCompleted % adFrequency == 0 {
            await MainActor.run {
                // Add small delay for better UX (let victory celebration settle)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    PerformanceMonitor.shared.startOperation("interstitial_ad_display")
                    adManager.showInterstitialAd()
                    PerformanceMonitor.shared.endOperation("interstitial_ad_display")
                    
                    self.adsShownCount += 1
                    print("📺 Interstitial ad shown after \(self.gamesCompleted) games completed")
                }
            }
        }
    }
    
    // MARK: - Optimized Game Logic
    
    private func resetGameState() {
        selectedCell = (nil, nil)
        errors.removeAll()
        validationCache.removeAll()
        hintCell = (nil, nil, nil)
        isVictory = false
        showVictoryAlert = false
        errorMessage = nil
        timeSpentSeconds = 0
        restartTimer()
    }
    
    private func performValidation(row: Int, col: Int, value: Int) async {
        let cacheKey = getCacheKey(grid: grid, row: row, col: col, value: value)
        
        // Check cache first
        if let cachedResult = validationCache[cacheKey] {
            await MainActor.run { [weak self] in
                let position = CellPosition(row: row, col: col)
                self?.errors[position] = !cachedResult
                self?.checkVictory()
            }
            return
        }
        
        do {
            let isValid: Bool
            if isOfflineMode {
                isValid = validateLocalMove(row: row, col: col, value: value)
            } else {
                isValid = try await APIService.shared.validateMove(grid: grid, row: row, col: col, value: value)
            }
            
            // Cache the result
            cacheValidationResult(key: cacheKey, result: isValid)
            
            await MainActor.run { [weak self] in
                let position = CellPosition(row: row, col: col)
                self?.errors[position] = !isValid
                self?.checkVictory()
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.errorMessage = "Failed to validate move: \(error.localizedDescription)"
            }
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
        // Optimize victory check with early returns
        guard grid.allSatisfy({ row in row.allSatisfy { $0 != nil } }) else { return }
        guard errors.allSatisfy({ !$0.value }) else { return }
        
        isVictory = true
        showVictoryAlert = true
        stopTimer()
        
        // Save game progress asynchronously
        Task { [weak self] in
            await self?.saveProgressAsync(isCompleted: true)
            
            // Track ad performance metrics
            PerformanceMonitor.shared.recordCustomMetric(name: "game_completion", value: 1)
        }
    }
    
    private func checkVictoryWithoutAnimation() {
        guard grid.allSatisfy({ row in row.allSatisfy { $0 != nil } }) else { return }
        guard errors.allSatisfy({ !$0.value }) else { return }
        
        isVictory = true
        stopTimer()
        
        Task { [weak self] in
            await self?.saveProgressAsync(isCompleted: true)
        }
    }
    
    private func solveGrid(_ grid: SudokuGrid) async throws -> SudokuGrid {
        if isOfflineMode {
            return await Task {
                return self.solveLocalGrid(grid)
            }.value
        } else {
            return try await APIService.shared.solvePuzzle(grid: grid)
        }
    }
    
    private func solveLocalGrid(_ grid: SudokuGrid) -> SudokuGrid {
        // Optimized backtracking solver with better heuristics
        var gridCopy = grid
        var emptyCells: [(Int, Int)] = []
        
        // Pre-collect empty cells for better performance
        for row in 0..<9 {
            for col in 0..<9 {
                if gridCopy[row][col] == nil {
                    emptyCells.append((row, col))
                }
            }
        }
        
        // Sort empty cells by constraint (Most Constrained Variable heuristic)
        emptyCells.sort { pos1, pos2 in
            let constraints1 = countConstraints(gridCopy, pos1.0, pos1.1)
            let constraints2 = countConstraints(gridCopy, pos2.0, pos2.1)
            return constraints1 > constraints2
        }
        
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
        
        func solve(cellIndex: Int = 0) -> Bool {
            guard cellIndex < emptyCells.count else { return true }
            
            let (row, col) = emptyCells[cellIndex]
            
            for num in 1...9 {
                if isValid(row: row, col: col, num: num) {
                    gridCopy[row][col] = num
                    
                    if solve(cellIndex: cellIndex + 1) {
                        return true
                    }
                    
                    gridCopy[row][col] = nil
                }
            }
            return false
        }
        
        return solve() ? gridCopy : []
    }
    
    private func countConstraints(_ grid: SudokuGrid, _ row: Int, _ col: Int) -> Int {
        var used = Set<Int>()
        
        // Add row constraints
        for c in 0..<9 {
            if let value = grid[row][c] {
                used.insert(value)
            }
        }
        
        // Add column constraints
        for r in 0..<9 {
            if let value = grid[r][col] {
                used.insert(value)
            }
        }
        
        // Add box constraints
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        
        for r in boxRow..<boxRow+3 {
            for c in boxCol..<boxCol+3 {
                if let value = grid[r][c] {
                    used.insert(value)
                }
            }
        }
        
        return used.count
    }
    
    // MARK: - Optimized Timer Management
    
    private func startTimer() {
        guard !isTimerActive else { return }
        
        isTimerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timeSpentSeconds += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
    }
    
    private func restartTimer() {
        stopTimer()
        startTimer()
    }
    
    // MARK: - Optimized Data Persistence
    
    func saveProgress(isCompleted: Bool) {
        Task { [weak self] in
            await self?.saveProgressAsync(isCompleted: isCompleted)
        }
    }
    
    private func saveProgressAsync(isCompleted: Bool) async {
        guard let puzzleId = puzzleId else { 
            print("⚠️ Cannot save progress: puzzleId is nil")
            return 
        }
        print("🔍 Saving progress for puzzle: \(puzzleId), completed: \(isCompleted)")
        
        do {
            if isOfflineMode {
                await saveLocalProgressAsync(isCompleted: isCompleted)
            } else {
                if let userId = authManager?.currentUser?.id {
                    let gameRecord = try await APIService.shared.saveGameProgress(
                        userId: userId,
                        puzzleId: puzzleId,
                        currentGrid: grid,
                        isCompleted: isCompleted,
                        timeSpentSeconds: timeSpentSeconds
                    )
                    print("✅ Game progress saved: \(gameRecord.id)")
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.errorMessage = "Failed to save progress: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveLocalProgressAsync(isCompleted: Bool) async {
        guard let puzzleId = puzzleId,
              let offlineStorage = offlineStorage else { return }
        
        let userId = authManager?.currentUser?.id
        
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
        
        await Task.detached {
            await offlineStorage.saveGameProgress(record: record)
        }.value
    }
    
    // MARK: - Optimized Fallback Puzzle Creation
    
    private func createFallbackPuzzleAsync() async -> SudokuPuzzle {
        let currentDifficulty = difficulty
        return await Task {
            Self.createFallbackPuzzle(for: currentDifficulty)
        }.value
    }
    
    private static func createFallbackPuzzle(for difficulty: SudokuDifficulty) -> SudokuPuzzle {
        print("🎯 Creating fallback puzzle for difficulty: \(difficulty.rawValue)")
        
        // Pre-computed solution for better performance
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
        
        var grid = Array(repeating: Array(repeating: nil as Int?, count: 9), count: 9)
        
        // Optimized position selection based on difficulty
        let positions = Self.getPositionsForDifficulty(difficulty)
        
        // Fill the grid efficiently
        for (row, col) in positions {
            grid[row][col] = solution[row][col]
        }
        
        let filledCells = positions.count
        print("🎯 Created fallback puzzle with \(filledCells) filled cells for \(difficulty.rawValue)")
        
        return SudokuPuzzle(id: -1, grid: grid, solution: solution, difficulty: difficulty)
    }
    
    private static func getPositionsForDifficulty(_ difficulty: SudokuDifficulty) -> [(Int, Int)] {
        switch difficulty {
        case .easy:
            return [
                (0,0), (0,1), (0,2), (0,4), (0,6), (0,7),
                (1,0), (1,2), (1,3), (1,4), (1,5), (1,7), (1,8),
                (2,0), (2,1), (2,3), (2,5), (2,7), (2,8),
                (3,0), (3,2), (3,4), (3,6), (3,8),
                (4,0), (4,2), (4,3), (4,5), (4,6), (4,8),
                (5,0), (5,2), (5,4), (5,6), (5,8),
                (6,0), (6,1), (6,3), (6,5), (6,7), (6,8),
                (7,0), (7,2), (7,3), (7,4), (7,5), (7,7), (7,8),
                (8,0), (8,1), (8,2), (8,4), (8,6), (8,7), (8,8)
            ]
        case .medium:
            return [
                (0,0), (0,2), (0,4), (0,7),
                (1,0), (1,3), (1,5), (1,8),
                (2,1), (2,3), (2,5), (2,7),
                (3,0), (3,4), (3,8),
                (4,2), (4,3), (4,5), (4,6),
                (5,0), (5,4), (5,8),
                (6,1), (6,3), (6,5), (6,7),
                (7,0), (7,3), (7,5), (7,8),
                (8,1), (8,4), (8,6), (8,8),
                (2,0), (3,2), (4,0), (4,8), (5,2), (6,0), (7,1)
            ]
        case .hard:
            return [
                (0,0), (0,4), (0,8),
                (1,2), (1,6),
                (2,1), (2,7),
                (3,0), (3,8),
                (4,3), (4,5),
                (5,0), (5,8),
                (6,1), (6,7),
                (7,2), (7,6),
                (8,0), (8,4), (8,8),
                (1,0), (3,4), (4,1), (4,7), (5,4), (7,8)
            ]
        }
    }
    
    // MARK: - Debug Methods
    
    func loadTestPuzzle() {
        isLoading = true
        errorMessage = nil
        
        Task { [weak self] in
            let testPuzzle = await self?.createFallbackPuzzleAsync() ?? SudokuPuzzle(id: -1, grid: [], solution: [], difficulty: .easy)
            await MainActor.run { [weak self] in
                self?.grid = testPuzzle.grid
                self?.originalGrid = testPuzzle.grid
                self?.puzzleId = testPuzzle.id
                self?.resetGameState()
                self?.isLoading = false
                print("Loaded test puzzle with \(testPuzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
            }
        }
    }
    
    // MARK: - Offline Mode
    
    func setOfflineMode(isOffline: Bool) {
        isOfflineMode = isOffline
    }
    
    func downloadPuzzlesForOfflinePlay() async -> Bool {
        guard !isOfflineMode,
              let offlineStorage = offlineStorage else { return false }
        
        var puzzlesByDifficulty: [String: [SudokuPuzzle]] = [:]
        
        await withTaskGroup(of: (SudokuDifficulty, [SudokuPuzzle]).self) { group in
            for difficulty in SudokuDifficulty.allCases {
                group.addTask {
                    var puzzles: [SudokuPuzzle] = []
                    for _ in 0..<5 {
                        do {
                            let puzzle = try await APIService.shared.generatePuzzle(difficulty: difficulty)
                            puzzles.append(puzzle)
                        } catch {
                            print("Failed to download puzzle for \(difficulty): \(error)")
                            break
                        }
                    }
                    return (difficulty, puzzles)
                }
            }
            
            for await (difficulty, puzzles) in group {
                puzzlesByDifficulty[difficulty.rawValue] = puzzles
            }
        }
        
        return offlineStorage.savePuzzles(puzzles: puzzlesByDifficulty)
    }
}

