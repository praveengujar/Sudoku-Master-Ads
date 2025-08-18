import Foundation
import FBAudienceNetwork

// MARK: - Meta Audience Network Delegates

// MARK: - Banner Ad Delegate
extension AdManager: FBAdViewDelegate {
    func adViewDidLoad(_ adView: FBAdView) {
        print("✅ Meta Banner loaded successfully")
        recordAdLoad(AdType.bannerMeta)
        
        DispatchQueue.main.async {
            self.adLoadingState = .loaded
        }
    }
    
    func adView(_ adView: FBAdView, didFailWithError error: Error) {
        print("❌ Meta Banner failed to load: \(error.localizedDescription)")
        recordAdFailure(.bannerMeta, error: error)
        
        DispatchQueue.main.async {
            self.adLoadingState = .failed(error)
        }
    }
    
    func adViewDidClick(_ adView: FBAdView) {
        print("🖱️ Meta Banner clicked")
        recordAdShow(AdType.bannerMeta)
    }
    
    func adViewDidFinishHandlingClick(_ adView: FBAdView) {
        print("🖱️ Meta Banner click handling finished")
    }
    
    func adViewWillLogImpression(_ adView: FBAdView) {
        print("📊 Meta Banner will log impression")
    }
}

// MARK: - Interstitial Ad Delegate
extension AdManager: FBInterstitialAdDelegate {
    func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        print("✅ Meta Interstitial loaded successfully")
        cacheAd(AdType.interstitialMeta)
        recordAdLoad(AdType.interstitialMeta)
        
        DispatchQueue.main.async {
            self.adLoadingState = .loaded
        }
    }
    
    func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        print("❌ Meta Interstitial failed to load: \(error.localizedDescription)")
        recordAdFailure(.interstitialMeta, error: error)
        
        DispatchQueue.main.async {
            self.adLoadingState = .failed(error)
        }
    }
    
    func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        print("🖱️ Meta Interstitial clicked")
    }
    
    func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        print("📱 Meta Interstitial closed")
        
        // Preload next interstitial ad
        Task { [weak self] in
            await MainActor.run {
                self?.loadMetaInterstitial()
            }
        }
    }
    
    func interstitialAdWillClose(_ interstitialAd: FBInterstitialAd) {
        print("📱 Meta Interstitial will close")
    }
    
    func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) {
        print("📊 Meta Interstitial will log impression")
    }
}

// MARK: - Rewarded Video Ad Delegate
extension AdManager: FBRewardedVideoAdDelegate {
    func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("✅ Meta Rewarded loaded successfully")
        cacheAd(AdType.rewardedMeta)
        recordAdLoad(AdType.rewardedMeta)
        
        DispatchQueue.main.async {
            self.adLoadingState = .loaded
        }
    }
    
    func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        print("❌ Meta Rewarded failed to load: \(error.localizedDescription)")
        recordAdFailure(.rewardedMeta, error: error)
        
        DispatchQueue.main.async {
            self.adLoadingState = .failed(error)
        }
        
        // Notify completion handler of failure
        if let completion = rewardCompletion {
            completion(false, 0)
            rewardCompletion = nil
        }
    }
    
    func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("🖱️ Meta Rewarded clicked")
    }
    
    func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("📱 Meta Rewarded closed")
        
        // Preload next rewarded ad
        Task { [weak self] in
            await MainActor.run {
                self?.loadMetaRewarded()
            }
        }
    }
    
    func rewardedVideoAdWillClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("📱 Meta Rewarded will close")
    }
    
    func rewardedVideoAdComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("🎁 Meta Rewarded completed - User earned reward!")
        recordAdReward(.rewardedMeta, amount: 1)
        
        // Notify completion handler of success
        if let completion = rewardCompletion {
            completion(true, 1)
            rewardCompletion = nil
        }
        
        // Post notification for game logic
        NotificationCenter.default.post(
            name: .adRewardEarned,
            object: nil,
            userInfo: ["amount": 1, "type": "meta"]
        )
    }
    
    func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("📊 Meta Rewarded will log impression")
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let adRewardEarned = Notification.Name("adRewardEarned")
    static let adLoadStateChanged = Notification.Name("adLoadStateChanged")
}