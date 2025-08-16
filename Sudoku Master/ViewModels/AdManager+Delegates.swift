import Foundation
import GoogleMobileAds
import FBAudienceNetwork
// import AdsGlobal // Temporarily disabled until TikTok setup is complete

// MARK: - Google AdMob Delegates

extension AdManager: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("✅ AdMob Banner loaded successfully")
        recordAdLoad(.bannerAdMob)
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("❌ AdMob Banner failed to load: \(error.localizedDescription)")
        recordAdFailure(.bannerAdMob, error: error)
    }
    
    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        print("📊 AdMob Banner impression recorded")
        recordAdShow(.bannerAdMob)
    }
    
    func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
        print("📱 AdMob Banner will present screen")
    }
    
    func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
        print("📱 AdMob Banner will dismiss screen")
    }
    
    func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
        print("📱 AdMob Banner did dismiss screen")
    }
}

extension AdManager: GADFullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("📱 AdMob Fullscreen ad will present")
        PerformanceMonitor.shared.startOperation("ad_display")
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("📱 AdMob Fullscreen ad dismissed")
        PerformanceMonitor.shared.endOperation("ad_display")
        
        // Preload the next ad
        if ad is GADInterstitialAd {
            loadAdMobInterstitial()
        } else if ad is GADRewardedAd {
            loadAdMobRewarded()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ AdMob Fullscreen ad failed to present: \(error.localizedDescription)")
        
        if ad is GADInterstitialAd {
            recordAdFailure(.interstitialAdMob, error: error)
        } else if ad is GADRewardedAd {
            recordAdFailure(.rewardedAdMob, error: error)
        }
    }
}

// MARK: - Meta Audience Network Delegates

extension AdManager: FBAdViewDelegate {
    func adViewDidLoad(_ adView: FBAdView) {
        print("✅ Meta Banner loaded successfully")
        recordAdLoad(.bannerMeta)
    }
    
    func adView(_ adView: FBAdView, didFailWithError error: Error) {
        print("❌ Meta Banner failed to load: \(error.localizedDescription)")
        recordAdFailure(.bannerMeta, error: error)
    }
    
    func adViewDidClick(_ adView: FBAdView) {
        print("🖱️ Meta Banner clicked")
        recordAdShow(.bannerMeta)
    }
    
    func adViewDidFinishHandlingClick(_ adView: FBAdView) {
        print("🖱️ Meta Banner click handling finished")
    }
    
    func adViewWillLogImpression(_ adView: FBAdView) {
        print("📊 Meta Banner will log impression")
    }
}

extension AdManager: FBInterstitialAdDelegate {
    func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        print("✅ Meta Interstitial loaded successfully")
        cacheAd(.interstitialMeta)
        recordAdLoad(.interstitialMeta)
    }
    
    func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        print("❌ Meta Interstitial failed to load: \(error.localizedDescription)")
        recordAdFailure(.interstitialMeta, error: error)
    }
    
    func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        print("🖱️ Meta Interstitial clicked")
    }
    
    func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        print("📱 Meta Interstitial closed")
        // Preload next interstitial
        loadMetaInterstitial()
    }
    
    func interstitialAdWillClose(_ interstitialAd: FBInterstitialAd) {
        print("📱 Meta Interstitial will close")
    }
    
    func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) {
        print("📊 Meta Interstitial will log impression")
    }
}

extension AdManager: FBRewardedVideoAdDelegate {
    func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("✅ Meta Rewarded loaded successfully")
        cacheAd(.rewardedMeta)
        recordAdLoad(.rewardedMeta)
    }
    
    func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        print("❌ Meta Rewarded failed to load: \(error.localizedDescription)")
        recordAdFailure(.rewardedMeta, error: error)
    }
    
    func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("🖱️ Meta Rewarded clicked")
    }
    
    func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("📱 Meta Rewarded closed")
        // Preload next rewarded ad
        loadMetaRewarded()
    }
    
    func rewardedVideoAdWillClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("📱 Meta Rewarded will close")
    }
    
    func rewardedVideoAdComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("🎁 Meta Rewarded completed - User earned reward!")
        recordAdReward(.rewardedMeta, amount: 1)
        
        // Notify game logic about reward
        NotificationCenter.default.post(name: .adRewardEarned, object: nil, userInfo: ["amount": 1, "type": "meta"])
    }
    
    func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
        print("📊 Meta Rewarded will log impression")
    }
}

// MARK: - TikTok Audience Network Delegates
// Note: TikTok delegates temporarily disabled until full configuration

/*
extension AdManager: BURewardedVideoAdDelegate {
    // TikTok delegate methods will be enabled when TikTok integration is fully configured
}
*/

// MARK: - Notification Extensions

extension Notification.Name {
    static let adRewardEarned = Notification.Name("adRewardEarned")
    static let adLoadStateChanged = Notification.Name("adLoadStateChanged")
}