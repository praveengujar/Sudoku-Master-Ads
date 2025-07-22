import SwiftUI

struct HomeView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineStorage: OfflineStorage
    @State private var showProfileSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                HStack {
                    Button(action: {
                        showProfileSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text(authManager.currentUser?.username ?? "Guest")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Offline mode indicator
                    if offlineStorage.isOfflineMode {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Offline Mode")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
                .padding()
                
                // Main game view
                SudokuBoardView()
                    .environmentObject(sudokuStore)
                
                // Controls
                VStack {
                    // Difficulty selector
                    HStack {
                        Text("Difficulty:")
                            .font(.headline)
                        
                        ForEach(SudokuDifficulty.allCases) { diff in
                            Button(action: {
                                sudokuStore.setDifficulty(diff)
                            }) {
                                Text(diff.displayName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(sudokuStore.difficulty == diff ? diff.color.opacity(0.3) : Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.bottom)
                    
                    // Game actions
                    HStack(spacing: 20) {
                        Button(action: {
                            sudokuStore.newGame()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            sudokuStore.getHint()
                        }) {
                            Image(systemName: "lightbulb")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 44, height: 44)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            sudokuStore.autoSolve()
                        }) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 44, height: 44)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            sudokuStore.loadTestPuzzle()
                        }) {
                            Image(systemName: "wrench")
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(width: 44, height: 44)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.bottom)
                    
                    // Number pad
                    VStack(spacing: 10) {
                        HStack(spacing: 15) {
                            ForEach(1...5, id: \.self) { num in
                                NumberButton(number: num)
                            }
                        }
                        
                        HStack(spacing: 15) {
                            ForEach(6...9, id: \.self) { num in
                                NumberButton(number: num)
                            }
                            Button(action: {
                                sudokuStore.eraseNumber()
                            }) {
                                Image(systemName: "delete.left")
                                    .frame(width: 40, height: 40)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                
                // Debug section (remove in production)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Debug Info:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Grid filled: \(sudokuStore.grid.flatMap { $0 }.compactMap { $0 }.count)/81 cells")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("Selected: (\(sudokuStore.selectedCell.row ?? -1), \(sudokuStore.selectedCell.col ?? -1))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("Offline mode: \(sudokuStore.isOfflineMode ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("Loading: \(sudokuStore.isLoading ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .navigationBarTitle("Sudoku Master", displayMode: .inline)
            .alert(isPresented: $sudokuStore.showVictoryAlert) {
                Alert(
                    title: Text("Congratulations!"),
                    message: Text("You completed the puzzle in \(formatTime(sudokuStore.timeSpentSeconds))"),
                    dismissButton: .default(Text("OK")) {
                        sudokuStore.closeVictoryModal()
                    }
                )
            }
            .alert("Error", isPresented: .constant(sudokuStore.errorMessage != nil)) {
                Button("OK") {
                    sudokuStore.errorMessage = nil
                }
            } message: {
                Text(sudokuStore.errorMessage ?? "")
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
            .onAppear {
                // Initialize the board if empty
                if isEmptyGrid(sudokuStore.grid) {
                    sudokuStore.newGame()
                }
                
                // Set the offline mode based on the stored value
                sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
            }
            .onChange(of: offlineStorage.isOfflineMode) { newValue in
                sudokuStore.setOfflineMode(isOffline: newValue)
            }
        }
    }
    
    // Helper function to check if grid is empty
    private func isEmptyGrid(_ grid: SudokuGrid) -> Bool {
        return grid.allSatisfy { row in
            row.allSatisfy { $0 == nil }
        }
    }
    
    // Format seconds to mm:ss
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// Number button for the keypad
struct NumberButton: View {
    let number: Int
    @EnvironmentObject var sudokuStore: SudokuStore
    
    var body: some View {
        Button(action: {
            print("Number button \(number) pressed")
            sudokuStore.enterNumber(number)
        }) {
            Text("\(number)")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}