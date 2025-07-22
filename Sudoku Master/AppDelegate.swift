import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    var authManager: AuthManager!
    var networkMonitor: NetworkMonitor!
    var offlineStorage: OfflineStorage!
    var sudokuStore: SudokuStore!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize core services
        networkMonitor = NetworkMonitor()
        offlineStorage = OfflineStorage()
        authManager = AuthManager()
        sudokuStore = SudokuStore()
        
        // Inject dependencies into SudokuStore
        sudokuStore.setDependencies(offlineStorage: offlineStorage, authManager: authManager)
        
        // Set offline mode status in SudokuStore based on OfflineStorage
        sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
        
        // Update offline status when network status changes
        self.updateOfflineStatusBasedOnNetwork()
        
        return true
    }
    
    private func updateOfflineStatusBasedOnNetwork() {
        // Initial update
        offlineStorage.updateOfflineStatus(networkConnected: networkMonitor.isConnected)
        
        // Subscribe to network status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
        
        // Subscribe to offline mode enable request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enableOfflineMode),
            name: NSNotification.Name("EnableOfflineMode"),
            object: nil
        )
    }
    
    @objc private func networkStatusChanged() {
        offlineStorage.updateOfflineStatus(networkConnected: networkMonitor.isConnected)
        sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
    }
    
    @objc private func enableOfflineMode() {
        // Force enable offline mode (typically when in guest mode)
        if !offlineStorage.isManualOfflineMode {
            offlineStorage.toggleOfflineMode()
        }
        sudokuStore.setOfflineMode(isOffline: true)
    }
}