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
            .navigationBarHidden(true)
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
            // Header with user info, title, and timer - reduced padding
            OptimizedHeaderView(showProfileSheet: $showProfileSheet)
                .environmentObject(authManager)
                .environmentObject(sudokuStore)
            
            // Main game board - moved up by 2 lines
            SudokuBoardView()
                .environmentObject(sudokuStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, -32)     // Move up by reducing top space (2 lines)
                .padding(.bottom, -20)  // Move up by reducing bottom space
            
            // Compact controls at bottom - reduced spacing
            CompactControlsView()
                .environmentObject(sudokuStore)
                .environmentObject(adManager)
            
            // Banner ad at bottom - increased height for more space
            BannerAdView()
                .environmentObject(adManager)
                .frame(height: 90)  // Increased from 72 to 90 for more ad space
                .padding(.horizontal)
        }
    }
}

private struct OptimizedHeaderView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var sudokuStore: SudokuStore
    @Binding var showProfileSheet: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Empty space line
            Spacer()
                .frame(height: 8)
            
            // Sudoku Master title - moved down one line
            Text("Sudoku Master")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Second empty space line
            Spacer()
                .frame(height: 8)
            
            // Guest icon and timer on fourth line with matching fonts
            HStack {
                // User profile button
                ProfileButton(showProfileSheet: $showProfileSheet)
                    .environmentObject(authManager)
                
                Spacer()
                
                // Timer with matching font
                TimerDisplayView()
                    .environmentObject(sudokuStore)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)  // Further reduced padding
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
                    .font(.subheadline)
                Text(authManager.currentUser?.username ?? "Guest")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)  // Reduced padding
            .background(Color.blue.opacity(0.1))
            .cornerRadius(15)  // Slightly smaller corner radius
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

private struct CompactControlsView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var adManager: AdManager
    @State private var showingHintAdChoice = false
    
    var body: some View {
        VStack(spacing: 6) {  // Reduced from 12 to 6
            // Single compact line with all controls
            HStack(spacing: 16) {
                // Difficulty buttons with letter icons
                DifficultyButton(difficulty: .easy, icon: "E")
                    .environmentObject(sudokuStore)
                
                DifficultyButton(difficulty: .medium, icon: "M")
                    .environmentObject(sudokuStore)
                
                DifficultyButton(difficulty: .hard, icon: "H")
                    .environmentObject(sudokuStore)
                
                // Separator
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                // Action buttons
                ActionButton(
                    icon: "🔄",
                    color: .blue,
                    action: {
                        sudokuStore.newGame()
                    }
                )
                
                ActionButton(
                    icon: "💡",
                    color: .orange,
                    action: {
                        showingHintAdChoice = true
                    }
                )
                
                ActionButton(
                    icon: "✓",
                    color: .green,
                    action: {
                        sudokuStore.autoSolve()
                    }
                )
            }
            .padding(.horizontal)
            
            // Number pad on second line
            NumberPadView()
                .environmentObject(sudokuStore)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)  // Reduced from 8 to 4
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


private struct DifficultyButton: View {
    let difficulty: SudokuDifficulty
    let icon: String
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
            Text(icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .white : difficulty.color)
                .frame(width: 36, height: 36)
                .background(
                    isSelected 
                        ? difficulty.color
                        : difficulty.color.opacity(0.15)
                )
                .clipShape(Circle())
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
            HapticManager.shared.mediumImpactOccurred()
            
            action()
        }) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(color.opacity(0.2))
                .cornerRadius(8)
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
        VStack(spacing: 6) {  // Reduced from 10 to 6
            HStack(spacing: 12) {  // Reduced from 15 to 12
                ForEach(1...5, id: \.self) { number in
                    OptimizedNumberButton(number: number)
                        .environmentObject(sudokuStore)
                }
            }
            
            HStack(spacing: 12) {  // Reduced from 15 to 12
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
            HapticManager.shared.lightImpactOccurred()
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
            HapticManager.shared.mediumImpactOccurred()
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

private struct TimerDisplayView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .font(.subheadline)
            Text(formatTime(sudokuStore.timeSpentSeconds))
                .font(.subheadline)
                .monospacedDigit()
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
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