import UIKit
import SwiftUI
import AppTrackingTransparency

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    
    var authManager: AuthManager!
    var networkMonitor: NetworkMonitor!
    var offlineStorage: OfflineStorage?
    var sudokuStore: SudokuStore!
    var adManager: AdManager?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize only critical services synchronously for faster launch
        networkMonitor = NetworkMonitor()
        authManager = AuthManager()
        sudokuStore = SudokuStore()
        
        // Initialize OfflineStorage synchronously but inject dependencies asynchronously
        offlineStorage = OfflineStorage()
        
        // Set dependencies asynchronously to avoid blocking launch
        Task.detached(priority: .userInitiated) { [weak self] in
            await MainActor.run {
                guard let self = self, let offlineStorage = self.offlineStorage else { return }
                // Inject dependencies after async initialization
                self.sudokuStore.setDependencies(offlineStorage: offlineStorage, authManager: self.authManager, networkMonitor: self.networkMonitor)
                self.sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
                self.updateOfflineStatusBasedOnNetwork()
                self.checkAllServicesInitialized()
            }
        }
        
        // Delay ad initialization until app is ready to avoid ATT prompt blocking launch
        Task.detached(priority: .background) { [weak self] in
            // Wait 500ms to allow app to fully load first
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                self?.adManager = AdManager.shared
                self?.checkAllServicesInitialized()
            }
            
            await self?.initializeMetaAds()
        }
        
        return true
    }
    
    private func checkAllServicesInitialized() {
        if offlineStorage != nil && adManager != nil {
            NotificationCenter.default.post(name: NSNotification.Name("ServicesInitialized"), object: nil)
            print("✅ All services initialized - notifying UI")
        }
    }
    
    private func updateOfflineStatusBasedOnNetwork() {
        // Initial update
        guard let offlineStorage = offlineStorage else {
            print("⚠️ OfflineStorage not yet initialized - skipping initial offline status update")
            return
        }
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
        guard let offlineStorage = offlineStorage else {
            print("⚠️ OfflineStorage not yet initialized - skipping network status update")
            return
        }
        offlineStorage.updateOfflineStatus(networkConnected: networkMonitor.isConnected)
        sudokuStore.setOfflineMode(isOffline: offlineStorage.isOfflineMode)
    }
    
    @objc private func enableOfflineMode() {
        // Force enable offline mode (typically when in guest mode)
        guard let offlineStorage = offlineStorage else {
            print("⚠️ OfflineStorage not yet initialized - skipping offline mode enable")
            return
        }
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
        guard let adManager = adManager else {
            print("⚠️ AdManager not initialized - cannot initialize Meta Audience Network")
            return
        }
        await adManager.initializeMetaAudienceNetwork()
        
        PerformanceMonitor.shared.endOperation("meta_ad_initialization")
        print("✅ Meta Audience Network initialized successfully")
    }
    
    // MARK: - App Lifecycle Methods for Ads
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume ad loading when app becomes active
        Task {
            guard let adManager = self.adManager else {
                print("⚠️ AdManager not yet initialized - skipping ad initialization")
                return
            }
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
            guard let adManager = self.adManager else {
                print("⚠️ AdManager not yet initialized - skipping ad preparation")
                return
            }
            await adManager.initializeMetaAudienceNetwork()
        }
    }
}