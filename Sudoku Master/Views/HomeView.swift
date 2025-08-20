import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineStorage: OfflineStorage
    @EnvironmentObject var adManager: AdManager
    @State private var showProfileSheet = false
    
    // Performance optimizations
    @State private var isViewReady = false
    @State private var cachedGridState: CachedGridState?
    
    // Ad integration
    @State private var bannerViewController: UIViewController?
    @State private var showingRewardedAdForHint = false
    
    var body: some View {
        NavigationView {
            // Main content
            MainContentView(showProfileSheet: $showProfileSheet)
                .environmentObject(sudokuStore)
                .environmentObject(authManager)
                .environmentObject(networkMonitor)
                .environmentObject(offlineStorage)
            .navigationBarTitle("Sudoku Master", displayMode: .inline)
            .alert(isPresented: $sudokuStore.showVictoryAlert) {
                Alert(
                    title: Text("🎉 Congratulations!"),
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
                setupView()
                setupAdIntegration()
            }
            .onReceive(NotificationCenter.default.publisher(for: .adRewardEarned)) { notification in
                handleAdReward(notification)
            }
            .onChange(of: offlineStorage.isOfflineMode) { newValue in
                sudokuStore.setOfflineMode(isOffline: newValue)
            }
        }
    }
    
    // MARK: - Setup and Optimization
    
    private func setupView() {
        guard !isViewReady else { return }
        
        // Initialize the board if empty
        if isEmptyGrid(sudokuStore.grid) {
            sudokuStore.newGame()
        }
        
        // Set the offline mode based on the stored value
        sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
        
        isViewReady = true
    }
    
    private func setupAdIntegration() {
        // Create banner view controller for ads
        bannerViewController = UIViewController()
        
        // Listen for ad reward notifications
        NotificationCenter.default.addObserver(
            forName: .adRewardEarned,
            object: nil,
            queue: .main
        ) { notification in
            handleAdReward(notification)
        }
    }
    
    private func handleAdReward(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let amount = userInfo["amount"] as? Int,
              let type = userInfo["type"] as? String else { return }
        
// Ad reward earned: \(amount) from \(type)
        
        // If this was for a hint, provide the hint
        if showingRewardedAdForHint {
            sudokuStore.getHint()
            showingRewardedAdForHint = false
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

// MARK: - Optimized Sub-Views

private struct MainContentView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineStorage: OfflineStorage
    @EnvironmentObject var adManager: AdManager
    @Binding var showProfileSheet: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with user info and offline indicator
            OptimizedHeaderView(showProfileSheet: $showProfileSheet)
                .environmentObject(authManager)
                .environmentObject(offlineStorage)
            
            // Main game board
            SudokuBoardView()
                .environmentObject(sudokuStore)
            
            // Game controls
            GameControlsView()
                .environmentObject(sudokuStore)
                .environmentObject(adManager)
            
            // Banner ad at bottom
            BannerAdView()
                .environmentObject(adManager)
                .frame(height: 60)
                .padding(.horizontal)
        }
    }
}

private struct OptimizedHeaderView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var offlineStorage: OfflineStorage
    @Binding var showProfileSheet: Bool
    
    var body: some View {
        HStack {
            // User profile button
            ProfileButton(showProfileSheet: $showProfileSheet)
                .environmentObject(authManager)
            
            Spacer()
            
            // Offline mode indicator
            if offlineStorage.isOfflineMode {
                OfflineModeIndicator()
            }
        }
        .padding()
    }
}

private struct ProfileButton: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var showProfileSheet: Bool
    
    var body: some View {
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
        .buttonStyle(.borderless)
    }
}

private struct OfflineModeIndicator: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Offline Mode")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(20)
        .font(.caption)
    }
}

private struct GameControlsView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    
    var body: some View {
        VStack(spacing: 16) {
            // Difficulty selector
            DifficultySelector()
                .environmentObject(sudokuStore)
            
            // Action buttons
            ActionButtonsView()
                .environmentObject(sudokuStore)
            
            // Number pad
            NumberPadView()
                .environmentObject(sudokuStore)
        }
        .padding()
    }
}

private struct DifficultySelector: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Difficulty:")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(SudokuDifficulty.allCases) { difficulty in
                    DifficultyButton(difficulty: difficulty)
                        .environmentObject(sudokuStore)
                }
            }
            
            Spacer()
        }
    }
}

private struct DifficultyButton: View {
    let difficulty: SudokuDifficulty
    @EnvironmentObject var sudokuStore: SudokuStore
    
    private var isSelected: Bool {
        sudokuStore.difficulty == difficulty
    }
    
    var body: some View {
        Button(action: {
            if !isSelected {
                sudokuStore.setDifficulty(difficulty)
            }
        }) {
            Text(difficulty.displayName)
                .font(.subheadline)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(minWidth: 80)
                .background(
                    isSelected 
                        ? difficulty.color.opacity(0.3)
                        : Color.gray.opacity(0.1)
                )
                .foregroundColor(isSelected ? .primary : .secondary)
                .cornerRadius(10)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.borderless)
        .disabled(isSelected)
    }
}

private struct ActionButtonsView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var adManager: AdManager
    @State private var showingHintAdChoice = false
    
    var body: some View {
        HStack(spacing: 20) {
            ActionButton(
                icon: "arrow.clockwise",
                color: .blue,
                action: {
                    sudokuStore.newGame()
                }
            )
            
            ActionButton(
                icon: "lightbulb",
                color: .orange,
                action: {
                    showingHintAdChoice = true
                }
            )
            
            ActionButton(
                icon: "checkmark.circle",
                color: .green,
                action: {
                    sudokuStore.autoSolve()
                }
            )
        }
        .alert("Get a Hint", isPresented: $showingHintAdChoice) {
            Button("Watch Ad for Free Hint") {
                adManager.showRewardedAd { success, reward in
                    if success {
                        sudokuStore.getHint()
                    }
                }
            }
            
            Button("Use Free Hint") {
                sudokuStore.getHint()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how to get your hint:")
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.2))
                .cornerRadius(10)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.borderless)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private struct NumberPadView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 15) {
                ForEach(1...5, id: \.self) { number in
                    OptimizedNumberButton(number: number)
                        .environmentObject(sudokuStore)
                }
            }
            
            HStack(spacing: 15) {
                ForEach(6...9, id: \.self) { number in
                    OptimizedNumberButton(number: number)
                        .environmentObject(sudokuStore)
                }
                
                EraseButton()
                    .environmentObject(sudokuStore)
            }
        }
    }
}

private struct OptimizedNumberButton: View {
    let number: Int
    @EnvironmentObject var sudokuStore: SudokuStore
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            sudokuStore.enterNumber(number)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            Text("\(number)")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.borderless)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private struct EraseButton: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            sudokuStore.eraseNumber()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }) {
            Image(systemName: "delete.left")
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 40, height: 40)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.borderless)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Supporting Views

// MARK: - Performance Caching

private struct CachedGridState {
    let grid: SudokuGrid
    let originalGrid: SudokuGrid
    let difficulty: SudokuDifficulty
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}

// MARK: - Ad Integration Views

private struct BannerAdView: UIViewControllerRepresentable {
    @EnvironmentObject var adManager: AdManager
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Add banner ad with performance optimization
        if let bannerView = adManager.showBannerAd(in: viewController) {
            viewController.view.addSubview(bannerView)
            
            // Auto Layout for banner positioning
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
                bannerView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor),
                bannerView.widthAnchor.constraint(lessThanOrEqualTo: viewController.view.widthAnchor)
            ])
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update if needed
    }
}

// MARK: - Preview Support

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(SudokuStore())
            .environmentObject(AuthManager())
            .environmentObject(NetworkMonitor())
            .environmentObject(OfflineStorage())
    }
}
#endif