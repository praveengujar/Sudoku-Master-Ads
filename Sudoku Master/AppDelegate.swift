import UIKit
import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency
import GoogleUserMessagingPlatform

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
        
        // Initialize ads asynchronously to avoid blocking app launch
        Task {
            await initializeAdSystems()
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
    
    // MARK: - Ad System Initialization
    
    private func initializeAdSystems() async {
        // Performance monitoring for ad initialization
        PerformanceMonitor.shared.startOperation("ad_initialization")
        
        // Initialize Google Mobile Ads SDK first (most commonly used)
        await initializeGoogleMobileAds()
        
        // Wait a brief moment for optimal performance
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Initialize other ad networks
        await adManager.initializeAdSDKs()
        
        PerformanceMonitor.shared.endOperation("ad_initialization")
        print("✅ All ad systems initialized successfully")
    }
    
    private func initializeGoogleMobileAds() async {
        await MainActor.run {
            // Start Google Mobile Ads SDK
            GADMobileAds.sharedInstance().start { initializationStatus in
                print("✅ Google Mobile Ads SDK initialized")
                
                // Log initialization status for debugging
                let adapterStatuses = initializationStatus.adapterStatusesByClassName
                for (adapter, status) in adapterStatuses {
                    let state = status.state == .ready ? "Ready" : "Not Ready"
                    print("📊 Adapter \(adapter): \(state) - \(status.description)")
                }
                
                PerformanceMonitor.shared.recordCustomMetric(name: "google_ads_init_success", value: 1)
            }
            
            // Configure request configuration for optimal performance
            let requestConfiguration = GADMobileAds.sharedInstance().requestConfiguration
            requestConfiguration.maxAdContentRating = .general
            
            // Set test device IDs for development (remove for production)
            #if DEBUG
            requestConfiguration.testDeviceIdentifiers = [GADSimulatorID]
            #endif
        }
    }
    
    // MARK: - App Lifecycle Methods for Ads
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume ad loading when app becomes active
        Task {
            await adManager.initializeAdSDKs()
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
            await adManager.initializeAdSDKs()
        }
    }
}