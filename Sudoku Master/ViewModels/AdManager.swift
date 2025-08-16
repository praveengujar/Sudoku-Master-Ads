import Foundation
import SwiftUI
import Combine
import GoogleMobileAds
import FBAudienceNetwork
// import AdsGlobal // Temporarily disabled until TikTok setup is complete
import AppTrackingTransparency
import GoogleUserMessagingPlatform

// MARK: - Performance-Optimized Ad Manager

@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    // MARK: - Published Properties
    @Published var isAdMobInitialized = false
    @Published var isConsentGathered = false
    @Published var canShowPersonalizedAds = false
    @Published var adLoadingState: AdLoadingState = .idle
    @Published var lastAdShownTime: Date?
    
    // MARK: - Ad Configuration
    private struct AdConfiguration {
        // Test IDs for development - Replace with your actual IDs for production
        static let admobAppID = "ca-app-pub-3940256099942544~1458002511" // Test App ID
        static let admobBannerID = "ca-app-pub-3940256099942544/2934735716" // Test Banner ID
        static let admobInterstitialID = "ca-app-pub-3940256099942544/4411468910" // Test Interstitial ID
        static let admobRewardedID = "ca-app-pub-3940256099942544/1712485313" // Test Rewarded ID
        
        static let metaPlacementBanner = "YOUR_META_PLACEMENT_ID"
        static let metaPlacementInterstitial = "YOUR_META_PLACEMENT_ID"
        static let metaPlacementRewarded = "YOUR_META_PLACEMENT_ID"
        
        static let tiktokAppID = "YOUR_TIKTOK_CLIENT_KEY"
        static let tiktokPlacementRewarded = "YOUR_TIKTOK_PLACEMENT_ID"
    }
    
    // MARK: - Ad Instances
    private var admobBannerView: GADBannerView?
    private var admobInterstitial: GADInterstitialAd?
    private var admobRewarded: GADRewardedAd?
    
    private var metaBannerView: FBAdView?
    private var metaInterstitial: FBInterstitialAd?
    private var metaRewarded: FBRewardedVideoAd?
    
    // private var tiktokRewarded: BURewardedVideoAd? // Disabled until TikTok is fully configured
    
    // MARK: - Performance Optimization
    private let adQueue = DispatchQueue(label: "ads.manager", qos: .userInitiated)
    private var adCache: [AdType: CachedAd] = [:]
    private let maxAdCacheAge: TimeInterval = 300 // 5 minutes
    private let minTimeBetweenAds: TimeInterval = 30 // 30 seconds
    
    // MARK: - Consent and Privacy
    private var consentInformation: UMPConsentInformation?
    private var consentForm: UMPConsentForm?
    
    // MARK: - Analytics and Performance Tracking
    private var adPerformanceMetrics: [AdType: AdMetrics] = [:]
    
    private override init() {
        super.init()
        setupAdManager()
    }
    
    // MARK: - Initialization
    
    private func setupAdManager() {
        Task { [weak self] in
            await self?.initializeConsentManagement()
        }
    }
    
    func initializeAdSDKs() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.initializeAdMob()
            }
            
            group.addTask { [weak self] in
                await self?.initializeMetaAudienceNetwork()
            }
            
            group.addTask { [weak self] in
                await self?.initializeTikTokAds()
            }
        }
        
        await preloadAds()
    }
    
    // MARK: - Google AdMob Integration
    
    private func initializeAdMob() async {
        await MainActor.run {
            GADMobileAds.sharedInstance().start { [weak self] status in
                DispatchQueue.main.async {
                    self?.isAdMobInitialized = true
                    print("✅ AdMob initialized successfully")
                    PerformanceMonitor.shared.recordCustomMetric(name: "admob_init_time", value: 0)
                }
            }
        }
    }
    
    private func loadAdMobBanner(in viewController: UIViewController) -> GADBannerView? {
        guard isAdMobInitialized else { return nil }
        
        let bannerView = GADBannerView(adSize: GADAdSizeSmartBannerPortrait)
        bannerView.adUnitID = AdConfiguration.admobBannerID
        bannerView.rootViewController = viewController
        bannerView.delegate = self
        
        let request = GADRequest()
        bannerView.load(request)
        
        recordAdRequest(.bannerAdMob)
        return bannerView
    }
    
    private func loadAdMobInterstitial() {
        guard isAdMobInitialized else { return }
        guard !isAdCached(.interstitialAdMob) else { return }
        
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AdConfiguration.admobInterstitialID,
                               request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ AdMob Interstitial failed to load: \(error.localizedDescription)")
                    self?.recordAdFailure(.interstitialAdMob, error: error)
                    return
                }
                
                self?.admobInterstitial = ad
                self?.admobInterstitial?.fullScreenContentDelegate = self
                self?.cacheAd(.interstitialAdMob)
                self?.recordAdLoad(.interstitialAdMob)
                print("✅ AdMob Interstitial loaded successfully")
            }
        }
        
        recordAdRequest(.interstitialAdMob)
    }
    
    private func loadAdMobRewarded() {
        guard isAdMobInitialized else { return }
        guard !isAdCached(.rewardedAdMob) else { return }
        
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: AdConfiguration.admobRewardedID,
                           request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ AdMob Rewarded failed to load: \(error.localizedDescription)")
                    self?.recordAdFailure(.rewardedAdMob, error: error)
                    return
                }
                
                self?.admobRewarded = ad
                self?.admobRewarded?.fullScreenContentDelegate = self
                self?.cacheAd(.rewardedAdMob)
                self?.recordAdLoad(.rewardedAdMob)
                print("✅ AdMob Rewarded loaded successfully")
            }
        }
        
        recordAdRequest(.rewardedAdMob)
    }
    
    // MARK: - Meta Audience Network Integration
    
    private func initializeMetaAudienceNetwork() async {
        // Meta Audience Network initializes automatically on first ad request
        await Task.detached {
            FBAdSettings.setLogLevel(.FBAdLogLevelLog)
            FBAdSettings.setIsChildDirected(false)
            print("✅ Meta Audience Network configured")
        }.value
    }
    
    private func loadMetaBanner(in viewController: UIViewController) -> FBAdView? {
        let bannerView = FBAdView(placementID: AdConfiguration.metaPlacementBanner,
                                  adSize: kFBAdSizeHeight50Banner,
                                  rootViewController: viewController)
        bannerView.delegate = self
        bannerView.loadAd()
        
        recordAdRequest(.bannerMeta)
        return bannerView
    }
    
    private func loadMetaInterstitial() {
        guard !isAdCached(.interstitialMeta) else { return }
        
        metaInterstitial = FBInterstitialAd(placementID: AdConfiguration.metaPlacementInterstitial)
        metaInterstitial?.delegate = self
        metaInterstitial?.load()
        
        recordAdRequest(.interstitialMeta)
    }
    
    private func loadMetaRewarded() {
        guard !isAdCached(.rewardedMeta) else { return }
        
        metaRewarded = FBRewardedVideoAd(placementID: AdConfiguration.metaPlacementRewarded)
        metaRewarded?.delegate = self
        metaRewarded?.load()
        
        recordAdRequest(.rewardedMeta)
    }
    
    // MARK: - TikTok Audience Network Integration
    
    private func initializeTikTokAds() async {
        await Task.detached {
            // TikTok SDK initialization - will be enabled when TikTok placement IDs are configured
            print("✅ TikTok Ads SDK ready for configuration")
        }.value
    }
    
    private func loadTikTokRewarded() {
        // TikTok rewarded ad loading - will be enabled when placement IDs are configured
        print("📺 TikTok rewarded ad loading ready for configuration")
        
        // recordAdRequest(.rewardedTikTok) // Disabled until TikTok integration is complete
    }
    
    // MARK: - Consent Management & Privacy
    
    private func initializeConsentManagement() async {
        await MainActor.run {
            consentInformation = UMPConsentInformation.sharedInstance
            
            let parameters = UMPRequestParameters()
            parameters.tagForUnderAgeOfConsent = false
            
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] error in
                if let error = error {
                    print("❌ Consent info update failed: \(error.localizedDescription)")
                    return
                }
                
                self?.loadConsentFormIfRequired()
            }
        }
    }
    
    private func loadConsentFormIfRequired() {
        guard let consentInformation = consentInformation else { return }
        
        if consentInformation.formStatus == .available {
            UMPConsentForm.load { [weak self] form, error in
                if let error = error {
                    print("❌ Consent form load failed: \(error.localizedDescription)")
                    return
                }
                
                self?.consentForm = form
                self?.presentConsentFormIfRequired()
            }
        } else {
            isConsentGathered = true
            canShowPersonalizedAds = consentInformation.canRequestAds
        }
    }
    
    private func presentConsentFormIfRequired() {
        guard let consentForm = consentForm,
              let topViewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
        if UMPConsentInformation.sharedInstance.consentStatus == .required {
            consentForm.present(from: topViewController) { [weak self] error in
                if let error = error {
                    print("❌ Consent form presentation failed: \(error.localizedDescription)")
                }
                
                self?.isConsentGathered = true
                self?.canShowPersonalizedAds = UMPConsentInformation.sharedInstance.canRequestAds
                
                Task { [weak self] in
                    await self?.requestTrackingPermission()
                }
            }
        }
    }
    
    private func requestTrackingPermission() async {
        guard #available(iOS 14, *) else { return }
        
        let status = await ATTrackingManager.requestTrackingAuthorization()
        
        await MainActor.run {
            switch status {
            case .authorized:
                print("✅ Tracking permission granted")
                canShowPersonalizedAds = true
            case .denied, .restricted:
                print("⚠️ Tracking permission denied")
                canShowPersonalizedAds = false
            case .notDetermined:
                print("⚠️ Tracking permission not determined")
            @unknown default:
                break
            }
            
            Task { [weak self] in
                await self?.initializeAdSDKs()
            }
        }
    }
    
    // MARK: - Public Ad Display Methods
    
    func showBannerAd(in viewController: UIViewController) -> UIView? {
        // Try AdMob first, then Meta as fallback
        if let adMobBanner = loadAdMobBanner(in: viewController) {
            return adMobBanner
        } else if let metaBanner = loadMetaBanner(in: viewController) {
            return metaBanner
        }
        return nil
    }
    
    func showInterstitialAd() {
        guard canShowAd() else { return }
        
        if let admobInterstitial = admobInterstitial,
           let topViewController = UIApplication.shared.windows.first?.rootViewController {
            admobInterstitial.present(fromRootViewController: topViewController)
            recordAdShow(.interstitialAdMob)
            self.admobInterstitial = nil // Clear after showing
            loadAdMobInterstitial() // Preload next ad
        } else if let metaInterstitial = metaInterstitial,
                  metaInterstitial.isAdValid {
            metaInterstitial.show(fromRootViewController: UIApplication.shared.windows.first?.rootViewController)
            recordAdShow(.interstitialMeta)
        }
    }
    
    func showRewardedAd(completion: @escaping (Bool, Int) -> Void) {
        guard canShowAd() else {
            completion(false, 0)
            return
        }
        
        if let admobRewarded = admobRewarded,
           let topViewController = UIApplication.shared.windows.first?.rootViewController {
            admobRewarded.present(fromRootViewController: topViewController) {
                let reward = admobRewarded.adReward
                completion(true, NSDecimalNumber(decimal: reward.amount.decimalValue).intValue)
                self.recordAdReward(.rewardedAdMob, amount: reward.amount.intValue)
            }
            recordAdShow(.rewardedAdMob)
            self.admobRewarded = nil
            loadAdMobRewarded()
        } else if let metaRewarded = metaRewarded,
                  metaRewarded.isAdValid {
            metaRewarded.show(fromRootViewController: UIApplication.shared.windows.first?.rootViewController)
            recordAdShow(.rewardedMeta)
            // Meta reward callback handled in delegate
        } else {
            completion(false, 0)
        }
    }
    
    // MARK: - Performance Optimization Methods
    
    private func preloadAds() async {
        await Task.detached { [weak self] in
            await MainActor.run {
                self?.loadAdMobInterstitial()
                self?.loadAdMobRewarded()
                self?.loadMetaInterstitial()
                self?.loadMetaRewarded()
                // TikTok preloading disabled until full configuration
                // self?.loadTikTokRewarded()
            }
        }.value
    }
    
    private func canShowAd() -> Bool {
        guard isConsentGathered else { return false }
        
        if let lastShown = lastAdShownTime {
            return Date().timeIntervalSince(lastShown) >= minTimeBetweenAds
        }
        
        return true
    }
    
    private func isAdCached(_ adType: AdType) -> Bool {
        guard let cachedAd = adCache[adType] else { return false }
        return !cachedAd.isExpired(maxAge: maxAdCacheAge)
    }
    
    private func cacheAd(_ adType: AdType) {
        adCache[adType] = CachedAd(timestamp: Date())
    }
    
    // MARK: - Analytics and Performance Tracking
    
    private func recordAdRequest(_ adType: AdType) {
        updateMetrics(for: adType) { metrics in
            metrics.requestCount += 1
        }
        PerformanceMonitor.shared.recordCustomMetric(name: "ad_request_\(adType.rawValue)", value: 1)
    }
    
    private func recordAdLoad(_ adType: AdType) {
        updateMetrics(for: adType) { metrics in
            metrics.loadCount += 1
        }
        PerformanceMonitor.shared.recordCustomMetric(name: "ad_load_\(adType.rawValue)", value: 1)
    }
    
    private func recordAdShow(_ adType: AdType) {
        updateMetrics(for: adType) { metrics in
            metrics.showCount += 1
        }
        lastAdShownTime = Date()
        PerformanceMonitor.shared.recordCustomMetric(name: "ad_show_\(adType.rawValue)", value: 1)
    }
    
    private func recordAdFailure(_ adType: AdType, error: Error) {
        updateMetrics(for: adType) { metrics in
            metrics.failureCount += 1
        }
        print("❌ Ad failure for \(adType.rawValue): \(error.localizedDescription)")
    }
    
    private func recordAdReward(_ adType: AdType, amount: Int) {
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
        var report = "=== Ad Performance Report ===\n"
        
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
    case bannerAdMob = "banner_admob"
    case bannerMeta = "banner_meta"
    case interstitialAdMob = "interstitial_admob"
    case interstitialMeta = "interstitial_meta"
    case rewardedAdMob = "rewarded_admob"
    case rewardedMeta = "rewarded_meta"
    // case rewardedTikTok = "rewarded_tiktok" // Disabled until TikTok integration is complete
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