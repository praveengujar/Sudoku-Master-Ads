import Foundation
import SwiftUI
import Combine
import FBAudienceNetwork
import AppTrackingTransparency

// MARK: - Meta Audience Network Ad Manager

@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    // MARK: - Published Properties
    @Published var isMetaInitialized = false
    @Published var isTrackingAuthorized = false
    @Published var adLoadingState: AdLoadingState = .idle
    @Published var lastAdShownTime: Date?
    
    // MARK: - Ad Configuration
    private struct AdConfiguration {
        // Replace these with your actual placement IDs from Meta Audience Network dashboard
        static let metaPlacementBanner = "YOUR_META_PLACEMENT_ID"
        static let metaPlacementInterstitial = "YOUR_META_PLACEMENT_ID" 
        static let metaPlacementRewarded = "YOUR_META_PLACEMENT_ID"
    }
    
    // MARK: - Ad Instances
    private var metaBannerView: FBAdView?
    private var metaInterstitial: FBInterstitialAd?
    private var metaRewarded: FBRewardedVideoAd?
    
    // MARK: - Performance Optimization
    private let adQueue = DispatchQueue(label: "ads.manager", qos: .userInitiated)
    private var adCache: [AdType: CachedAd] = [:]
    private let maxAdCacheAge: TimeInterval = 300 // 5 minutes
    private let minTimeBetweenAds: TimeInterval = 30 // 30 seconds
    
    // MARK: - Analytics and Performance Tracking
    private var adPerformanceMetrics: [AdType: AdMetrics] = [:]
    
    private override init() {
        super.init()
        setupAdManager()
    }
    
    // MARK: - Initialization
    
    private func setupAdManager() {
        Task { [weak self] in
            await self?.requestTrackingPermission()
        }
    }
    
    func initializeMetaAudienceNetwork() async {
        await Task.detached { [weak self] in
            // Configure Meta Audience Network settings
            FBAdSettings.setLogLevel(.log)
            FBAdSettings.setIsChildDirected(false)
            
            // Enable test mode for development (remove for production)
            #if DEBUG
            FBAdSettings.addTestDevice(FBAdSettings.testDeviceHash())
            #endif
            
            await MainActor.run {
                self?.isMetaInitialized = true
                print("✅ Meta Audience Network initialized successfully")
                Task { [weak self] in
                    await self?.preloadAds()
                }
            }
        }.value
    }
    
    // MARK: - App Tracking Transparency (ATT)
    
    private func requestTrackingPermission() async {
        guard #available(iOS 14, *) else {
            await initializeMetaAudienceNetwork()
            return
        }
        
        let status = await ATTrackingManager.requestTrackingAuthorization()
        
        await MainActor.run {
            switch status {
            case .authorized:
                print("✅ Tracking permission granted")
                isTrackingAuthorized = true
            case .denied, .restricted:
                print("⚠️ Tracking permission denied")
                isTrackingAuthorized = false
            case .notDetermined:
                print("⚠️ Tracking permission not determined")
                isTrackingAuthorized = false
            @unknown default:
                isTrackingAuthorized = false
            }
            
            Task { [weak self] in
                await self?.initializeMetaAudienceNetwork()
            }
        }
    }
    
    // MARK: - Meta Banner Ad Integration
    
    private func loadMetaBanner(in viewController: UIViewController) -> FBAdView? {
        guard isMetaInitialized else {
            print("⚠️ Meta Audience Network not initialized")
            return nil
        }
        
        let bannerView = FBAdView(
            placementID: AdConfiguration.metaPlacementBanner,
            adSize: kFBAdSizeHeight50Banner,
            rootViewController: viewController
        )
        
        bannerView.delegate = self
        bannerView.loadAd()
        
        recordAdRequest(.bannerMeta)
        print("📱 Meta Banner ad loading...")
        
        return bannerView
    }
    
    // MARK: - Meta Interstitial Ad Integration
    
    internal func loadMetaInterstitial() {
        guard isMetaInitialized else {
            print("⚠️ Meta Audience Network not initialized")
            return
        }
        
        guard !isAdCached(.interstitialMeta) else {
            print("📱 Meta Interstitial already cached")
            return
        }
        
        metaInterstitial = FBInterstitialAd(placementID: AdConfiguration.metaPlacementInterstitial)
        metaInterstitial?.delegate = self
        metaInterstitial?.load()
        
        recordAdRequest(.interstitialMeta)
        print("📱 Meta Interstitial ad loading...")
    }
    
    // MARK: - Meta Rewarded Video Ad Integration
    
    internal func loadMetaRewarded() {
        guard isMetaInitialized else {
            print("⚠️ Meta Audience Network not initialized")
            return
        }
        
        guard !isAdCached(.rewardedMeta) else {
            print("📺 Meta Rewarded already cached")
            return
        }
        
        metaRewarded = FBRewardedVideoAd(placementID: AdConfiguration.metaPlacementRewarded)
        metaRewarded?.delegate = self
        metaRewarded?.load()
        
        recordAdRequest(.rewardedMeta)
        print("📺 Meta Rewarded ad loading...")
    }
    
    // MARK: - Public Ad Display Methods
    
    func showBannerAd(in viewController: UIViewController) -> UIView? {
        return loadMetaBanner(in: viewController)
    }
    
    func showInterstitialAd() {
        guard canShowAd() else {
            print("⚠️ Cannot show ad - frequency cap or consent not met")
            return
        }
        
        guard let metaInterstitial = metaInterstitial,
              metaInterstitial.isAdValid else {
            print("⚠️ Meta Interstitial not ready")
            loadMetaInterstitial() // Load for next time
            return
        }
        
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("❌ No root view controller found")
            return
        }
        
        metaInterstitial.show(fromRootViewController: rootViewController)
        recordAdShow(.interstitialMeta)
        
        // Clear the ad after showing and preload next one
        self.metaInterstitial = nil
        loadMetaInterstitial()
    }
    
    func showRewardedAd(completion: @escaping (Bool, Int) -> Void) {
        guard canShowAd() else {
            print("⚠️ Cannot show rewarded ad - frequency cap or consent not met")
            completion(false, 0)
            return
        }
        
        guard let metaRewarded = metaRewarded,
              metaRewarded.isAdValid else {
            print("⚠️ Meta Rewarded ad not ready")
            completion(false, 0)
            loadMetaRewarded() // Load for next time
            return
        }
        
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("❌ No root view controller found")
            completion(false, 0)
            return
        }
        
        // Store completion handler for reward callback
        self.rewardCompletion = completion
        
        metaRewarded.show(fromRootViewController: rootViewController)
        recordAdShow(.rewardedMeta)
        
        // Clear the ad after showing and preload next one
        self.metaRewarded = nil
        loadMetaRewarded()
    }
    
    // MARK: - Reward Completion Handler
    internal var rewardCompletion: ((Bool, Int) -> Void)?
    
    // MARK: - Performance Optimization Methods
    
    private func preloadAds() async {
        await Task.detached { [weak self] in
            await MainActor.run {
                self?.loadMetaInterstitial()
                self?.loadMetaRewarded()
            }
        }.value
    }
    
    private func canShowAd() -> Bool {
        // Check if tracking permission is granted (recommended for personalized ads)
        guard isTrackingAuthorized || true else { // Allow non-personalized ads
            return false
        }
        
        // Check minimum time between ads
        if let lastShown = lastAdShownTime {
            return Date().timeIntervalSince(lastShown) >= minTimeBetweenAds
        }
        
        return true
    }
    
    private func isAdCached(_ adType: AdType) -> Bool {
        guard let cachedAd = adCache[adType] else { return false }
        return !cachedAd.isExpired(maxAge: maxAdCacheAge)
    }
    
    internal func cacheAd(_ adType: AdType) {
        adCache[adType] = CachedAd(timestamp: Date())
    }
    
    // MARK: - Analytics and Performance Tracking
    
    private func recordAdRequest(_ adType: AdType) {
        updateMetrics(for: adType) { metrics in
            metrics.requestCount += 1
        }
        PerformanceMonitor.shared.recordCustomMetric(name: "ad_request_\(adType.rawValue)", value: 1)
    }
    
    internal func recordAdLoad(_ adType: AdType) {
        updateMetrics(for: adType) { metrics in
            metrics.loadCount += 1
        }
        PerformanceMonitor.shared.recordCustomMetric(name: "ad_load_\(adType.rawValue)", value: 1)
    }
    
    internal func recordAdShow(_ adType: AdType) {
        updateMetrics(for: adType) { metrics in
            metrics.showCount += 1
        }
        lastAdShownTime = Date()
        PerformanceMonitor.shared.recordCustomMetric(name: "ad_show_\(adType.rawValue)", value: 1)
    }
    
    internal func recordAdFailure(_ adType: AdType, error: Error) {
        updateMetrics(for: adType) { metrics in
            metrics.failureCount += 1
        }
        print("❌ Ad failure for \(adType.rawValue): \(error.localizedDescription)")
    }
    
    internal func recordAdReward(_ adType: AdType, amount: Int) {
        updateMetrics(for: adType) { metrics in
            metrics.rewardCount += 1
            metrics.totalRewardAmount += amount
        }
    }
    
    private func updateMetrics(for adType: AdType, update: (inout AdMetrics) -> Void) {
        if adPerformanceMetrics[adType] == nil {
            adPerformanceMetrics[adType] = AdMetrics()
        }
        update(&adPerformanceMetrics[adType]!)
    }
    
    // MARK: - Public Analytics
    
    func getAdPerformanceReport() -> String {
        var report = "=== Meta Audience Network Performance Report ===\n"
        
        for (adType, metrics) in adPerformanceMetrics {
            let fillRate = metrics.requestCount > 0 ? (Double(metrics.loadCount) / Double(metrics.requestCount) * 100) : 0
            report += "\(adType.rawValue):\n"
            report += "  Requests: \(metrics.requestCount)\n"
            report += "  Loads: \(metrics.loadCount)\n"
            report += "  Shows: \(metrics.showCount)\n"
            report += "  Fill Rate: \(String(format: "%.1f", fillRate))%\n"
            report += "  Rewards: \(metrics.rewardCount)\n\n"
        }
        
        return report
    }
}

// MARK: - Supporting Types

enum AdType: String, CaseIterable {
    case bannerMeta = "banner_meta"
    case interstitialMeta = "interstitial_meta"
    case rewardedMeta = "rewarded_meta"
}

enum AdLoadingState {
    case idle
    case loading
    case loaded
    case failed(Error)
}

struct CachedAd {
    let timestamp: Date
    
    func isExpired(maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}

struct AdMetrics {
    var requestCount = 0
    var loadCount = 0
    var showCount = 0
    var failureCount = 0
    var rewardCount = 0
    var totalRewardAmount = 0
}