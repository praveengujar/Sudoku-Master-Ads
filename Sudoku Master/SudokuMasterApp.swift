import SwiftUI
import Combine

@main
struct SudokuMasterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            AppInitializationView(appDelegate: appDelegate)
        }
    }
}

struct AppInitializationView: View {
    let appDelegate: AppDelegate
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if isInitialized, 
               let offlineStorage = appDelegate.offlineStorage,
               let adManager = appDelegate.adManager {
                ContentView()
                    .environmentObject(appDelegate.sudokuStore)
                    .environmentObject(appDelegate.authManager)
                    .environmentObject(appDelegate.networkMonitor)
                    .environmentObject(offlineStorage)
                    .environmentObject(adManager)
            } else {
                // Show loading screen while services initialize
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Sudoku Master...")
                        .font(.title2)
                        .padding(.top)
                }
            }
        }
        .onAppear {
            checkInitialization()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ServicesInitialized"))) { _ in
            isInitialized = true
        }
    }
    
    private func checkInitialization() {
        if appDelegate.offlineStorage != nil && appDelegate.adManager != nil {
            isInitialized = true
        }
    }
}