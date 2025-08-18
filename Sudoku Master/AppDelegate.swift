import UIKit
import SwiftUI
import AppTrackingTransparency

class AppDelegate: NSObject, UIApplicationDelegate {
    var authManager: AuthManager!
    var networkMonitor: NetworkMonitor!
    var offlineStorage: OfflineStorage!
    var sudokuStore: SudokuStore!
    var adManager: AdManager!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize core services first
        networkMonitor = NetworkMonitor()
        offlineStorage = OfflineStorage()
        authManager = AuthManager()
        sudokuStore = SudokuStore()
        
        // Initialize ad manager early for optimal performance
        adManager = AdManager.shared
        
        // Inject dependencies into SudokuStore
        sudokuStore.setDependencies(offlineStorage: offlineStorage, authManager: authManager)
        
        // Set offline mode status in SudokuStore based on OfflineStorage
        sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
        
        // Update offline status when network status changes
        self.updateOfflineStatusBasedOnNetwork()
        
        // Initialize Meta Audience Network asynchronously to avoid blocking app launch
        Task {
            await initializeMetaAds()
        }
        
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
    
    // MARK: - Meta Ad System Initialization
    
    private func initializeMetaAds() async {
        // Performance monitoring for ad initialization
        PerformanceMonitor.shared.startOperation("meta_ad_initialization")
        
        // Initialize Meta Audience Network
        await adManager.initializeMetaAudienceNetwork()
        
        PerformanceMonitor.shared.endOperation("meta_ad_initialization")
        print("✅ Meta Audience Network initialized successfully")
    }
    
    // MARK: - App Lifecycle Methods for Ads
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume ad loading when app becomes active
        Task {
            await adManager.initializeMetaAudienceNetwork()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Pause ad operations when app becomes inactive (optional optimization)
        print("📱 App will resign active - pausing ad operations")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Clean up ad resources in background for memory optimization
        print("📱 App entered background - optimizing memory usage")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Prepare ads for foreground use
        print("📱 App will enter foreground - preparing ads")
        Task {
            await adManager.initializeMetaAudienceNetwork()
        }
    }
}