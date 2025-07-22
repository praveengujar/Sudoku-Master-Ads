import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineStorage: OfflineStorage
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    @State private var isDownloadingPuzzles = false
    @State private var downloadSuccess = false
    
    var body: some View {
        NavigationView {
            VStack {
                // User profile header
                VStack(spacing: 10) {
                    // User avatar
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    // Username
                    Text(authManager.currentUser?.username ?? "Guest")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Connection status
                    HStack {
                        Circle()
                            .fill(networkMonitor.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text(networkMonitor.connectionDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                
                // Tab selector
                Picker("Options", selection: $selectedTab) {
                    Text("Profile").tag(0)
                    Text("Offline Mode").tag(1)
                    Text("Settings").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    ProfileTabContent()
                        .tag(0)
                    
                    OfflineModeTabContent(
                        isDownloadingPuzzles: $isDownloadingPuzzles,
                        downloadSuccess: $downloadSuccess
                    )
                    .tag(1)
                    
                    SettingsTabContent()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Logout button
                Button(action: {
                    Task {
                        await authManager.logout()
                    }
                }) {
                    Text("Logout")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Profile tab content
struct ProfileTabContent: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var userStats: UserStats?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Statistics section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Statistics")
                        .font(.headline)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else if let stats = userStats {
                        // Player level
                        HStack {
                            Text("Player Level:")
                                .fontWeight(.medium)
                            
                            Text(SudokuDifficulty.getSkillDescription(for: stats.normalizedRating))
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(20)
                        }
                        
                        // Rating
                        HStack {
                            Text("Proficiency:")
                                .fontWeight(.medium)
                            
                            Text("\(stats.normalizedRating)/100")
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(20)
                        }
                        
                        // Games played
                        HStack {
                            Text("Games Played:")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(stats.gamesPlayed)")
                        }
                        
                        // Games won
                        HStack {
                            Text("Games Completed:")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(stats.gamesWon)")
                        }
                        
                        // Average time
                        HStack {
                            Text("Average Time:")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(formatTime(stats.averageTimeSeconds))
                        }
                    } else {
                        Text("No statistics available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // Recent games section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Games")
                        .font(.headline)
                    
                    Text("Coming soon...")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // Achievements section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Achievements")
                        .font(.headline)
                    
                    Text("Coming soon...")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            }
            .padding()
        }
        .onAppear {
            loadUserStats()
        }
    }
    
    private func loadUserStats() {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let stats = try await APIService.shared.getUserStats(userId: userId)
                await MainActor.run {
                    self.userStats = stats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading user stats: \(error)")
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Offline mode tab content
struct OfflineModeTabContent: View {
    @EnvironmentObject var offlineStorage: OfflineStorage
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Binding var isDownloadingPuzzles: Bool
    @Binding var downloadSuccess: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Offline mode info
                VStack(alignment: .leading, spacing: 10) {
                    Text("Offline Mode")
                        .font(.headline)
                    
                    Text("Play Sudoku without an internet connection. Download puzzles in advance to play them offline.")
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Toggle switch
                    Toggle(isOn: Binding(
                        get: { offlineStorage.isManualOfflineMode },
                        set: { newValue in
                            offlineStorage.toggleOfflineMode()
                        }
                    )) {
                        Text("Enable Offline Mode")
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 5)
                    
                    // Status
                    HStack {
                        Text("Status:")
                            .fontWeight(.medium)
                        
                        Text(offlineStorage.isOfflineMode ? "Playing Offline" : "Playing Online")
                            .fontWeight(.semibold)
                            .foregroundColor(offlineStorage.isOfflineMode ? .orange : .green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(offlineStorage.isOfflineMode ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .cornerRadius(20)
                    }
                    
                    // Available puzzles
                    HStack {
                        Text("Available Puzzles:")
                            .fontWeight(.medium)
                        
                        Text("\(offlineStorage.puzzleCount)")
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 5)
                    
                    // Download button
                    Button(action: {
                        downloadPuzzles()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Download Puzzles")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(networkMonitor.isConnected ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!networkMonitor.isConnected || isDownloadingPuzzles)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.5)
                    
                    if isDownloadingPuzzles {
                        ProgressView("Downloading puzzles...")
                            .padding()
                    }
                    
                    if downloadSuccess {
                        Text("Puzzles downloaded successfully!")
                            .foregroundColor(.green)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // Offline mode details
                VStack(alignment: .leading, spacing: 10) {
                    Text("About Offline Mode")
                        .font(.headline)
                    
                    OfflineModeFeatureRow(icon: "wifi.slash", title: "No Internet Required", description: "Play puzzles even when you're not connected")
                    
                    OfflineModeFeatureRow(icon: "arrow.down.doc", title: "Downloaded Puzzles", description: "Access a library of pre-downloaded puzzles")
                    
                    OfflineModeFeatureRow(icon: "lock", title: "Local Progress", description: "Your progress is saved locally on your device")
                    
                    OfflineModeFeatureRow(icon: "arrow.triangle.2.circlepath", title: "Auto Sync", description: "Progress syncs when you reconnect to the internet")
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            }
            .padding()
        }
    }
    
    private func downloadPuzzles() {
        guard networkMonitor.isConnected else { return }
        
        isDownloadingPuzzles = true
        downloadSuccess = false
        
        Task {
            let success = await sudokuStore.downloadPuzzlesForOfflinePlay()
            
            await MainActor.run {
                isDownloadingPuzzles = false
                downloadSuccess = success
            }
        }
    }
}

// Settings tab content
struct SettingsTabContent: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTheme: ThemeOption = .default
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Theme settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Theme")
                        .font(.headline)
                    
                    ForEach(ThemeOption.allCases) { theme in
                        Button(action: {
                            selectedTheme = theme
                        }) {
                            HStack {
                                Text(theme.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(selectedTheme == theme ? Color.blue.opacity(0.1) : Color(.systemBackground))
                            .cornerRadius(10)
                        }
                    }
                    
                    Button(action: {
                        // Update theme
                    }) {
                        Text("Apply Theme")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // Account settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Account")
                        .font(.headline)
                    
                    Button(action: {
                        // Change password
                    }) {
                        HStack {
                            Text("Change Password")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // App information
                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(.headline)
                    
                    HStack {
                        Text("Version")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    
                    Button(action: {
                        // Terms of Service
                    }) {
                        HStack {
                            Text("Terms of Service")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Privacy Policy
                    }) {
                        HStack {
                            Text("Privacy Policy")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            }
            .padding()
        }
        .onAppear {
            if let theme = authManager.currentUser?.theme {
                selectedTheme = theme
            }
        }
    }
}

// Feature row component for offline mode
struct OfflineModeFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(width: 25)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}