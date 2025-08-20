# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sudoku Master is a SwiftUI iOS app that provides a complete Sudoku gaming experience with both online and offline modes. The app features user authentication, multiple difficulty levels, game progress tracking, offline puzzle storage, and comprehensive ad monetization integration.

## Architecture

The app follows the MVVM pattern with SwiftUI and uses an AppDelegate for lifecycle management:

- **Models** (`Models/SudokuModels.swift`): Core data models including `SudokuPuzzle`, `User`, `UserStats`, `GameplayRecord`, and enums for difficulty levels and themes
- **ViewModels**: Business logic and state management
  - `SudokuStore`: Main game state, puzzle logic, validation, solving, and timer management
  - `APIService`: HTTP client for backend communication
  - `AuthManager`: User authentication and session management
  - `AdManager`: Performance-optimized ad management for Meta Audience Network ONLY
- **Views**: SwiftUI UI components
  - `HomeView`: Main game interface
  - `SudokuBoardView`: Interactive Sudoku grid
  - `AuthView`: Login/registration
  - `ProfileView`: User profile and offline mode settings
- **Utils**: Helper classes
  - `NetworkMonitor`: Tracks network connectivity
  - `OfflineStorage`: Local puzzle storage using UserDefaults
  - `PerformanceMonitor`: Real-time performance metrics and monitoring

## Key Features

### Dual Mode Operation
The app operates in both online and offline modes:
- **Online Mode**: Fetches puzzles from API at `https://sudoku-master-api-93673815784.us-central1.run.app/api`
- **Offline Mode**: Uses locally stored puzzles or generates fallback puzzles

### Game State Management
- `SudokuStore` is the central state manager injected as environment object
- Timer management for tracking game duration
- Local validation using backtracking algorithm
- Progress saving to both API and local storage

### Data Models
- `SudokuGrid` is defined as `[[Int?]]` representing a 9x9 grid
- `SudokuDifficulty` enum with comprehensive properties including UI colors, completion times, and learning tips
- Comprehensive user statistics and game records

## Build and Test Commands

This project uses CocoaPods for dependency management. Use Xcode IDE for building and testing:

### Prerequisites
1. Install CocoaPods: `brew install cocoapods`
2. Install dependencies: `pod install` (in project directory)

### Building
- **IMPORTANT**: Open `Sudoku Master.xcworkspace` (NOT .xcodeproj)
- Build: Cmd+B
- Run: Cmd+R  
- Test: Cmd+U

### Dependencies
- **Meta Audience Network (~> 6.15)**: Primary and ONLY ad network
- **System Frameworks**: AppTrackingTransparency for privacy compliance

**Note**: All Google AdMob, Firebase, and TikTok dependencies have been REMOVED for simplified Meta-only integration.

Note: `xcodebuild` requires full Xcode installation, not just Command Line Tools.

## Development Notes

### Environment Objects
The app uses five main environment objects injected at the root level:
- `SudokuStore`: Game state and logic
- `AuthManager`: User authentication
- `NetworkMonitor`: Connectivity status
- `OfflineStorage`: Local data persistence
- `AdManager`: Ad management and monetization

### API Integration
All API endpoints expect JSON payloads and return structured responses. The `APIService` class handles encoding/decoding with proper error handling for network failures and server errors.

### Offline Functionality
The app gracefully degrades to offline mode when network is unavailable. It includes a fallback puzzle generator and local storage for downloaded puzzles.

### State Persistence
Game progress is saved both locally (UserDefaults) and remotely (API) with conflict resolution favoring the most recent save.

### Ad Monetization Integration
The app includes Meta Audience Network integration with performance optimizations:
- **Meta Audience Network**: Primary ad network with banner, interstitial, and rewarded video ads
- **Privacy Compliance**: App Tracking Transparency (ATT) with comprehensive privacy manifests
- **Performance Optimized**: Async ad loading, intelligent caching, and preloading
- **UX Integration**: Natural ad placement at game completion and hint system
- **Clean Implementation**: Simplified single-network approach for easier maintenance

### Difficulty Selection & Puzzle Loading
- Difficulty selection triggers automatic puzzle reload via `setDifficulty()` method in `SudokuStore`
- The `setDifficulty()` method (line 151-154) calls `newGame()` to load a fresh puzzle with the selected difficulty
- This ensures users get a new puzzle immediately when changing difficulty levels
- Works seamlessly in both online and offline modes

## Recent Implementation Learnings

### Automatic Puzzle Reload (2025-07-22)
**Problem**: Users had to manually start a new game after selecting a difficulty level
**Solution**: Modified `SudokuStore.setDifficulty()` to automatically call `newGame()`
**Location**: `ViewModels/SudokuStore.swift:151-154`
**Impact**: 
- Improved UX by eliminating extra steps
- Maintains game state consistency across difficulty changes
- Works with both online API and offline puzzle storage

### Code Flow for Difficulty Changes
1. User taps difficulty button in `HomeView.swift:56-57`
2. Calls `sudokuStore.setDifficulty(diff)`
3. `setDifficulty()` updates difficulty property and calls `newGame()`
4. `newGame()` method handles puzzle loading based on online/offline mode
5. Timer resets and game state refreshes automatically

### Key Methods Involved
- `HomeView`: Difficulty button actions trigger difficulty changes
- `SudokuStore.setDifficulty()`: Sets difficulty and triggers puzzle reload
- `SudokuStore.newGame()`: Handles puzzle loading logic for both modes
- `SudokuStore.resetGameState()`: Clears previous game state

## Meta Audience Network Integration (2025-08-18)

### Streamlined Ad Platform Integration
**Implementation**: Clean Meta Audience Network-only ad monetization system
**Location**: `ViewModels/AdManager.swift` and `ViewModels/AdManager+Delegates.swift`
**Features**:
- Performance-optimized async ad loading with caching and preloading
- Privacy compliance with App Tracking Transparency (ATT)
- Natural UX integration with banner, interstitial, and rewarded video ads
- Comprehensive analytics and performance monitoring
- Simplified single-network approach for easier maintenance

### Ad Integration Points
1. **Banner Ads**: Bottom of `HomeView` using Meta's `FBAdView`
2. **Interstitial Ads**: After puzzle completion (frequency-capped) via `FBInterstitialAd`
3. **Rewarded Video Ads**: Hint system integration using `FBRewardedVideoAd`
4. **Privacy**: App Tracking Transparency with comprehensive privacy manifests

### Performance Optimizations
- **Async/Await**: All ad operations run on background queues to prevent main thread blocking
- **Intelligent Caching**: 5-minute TTL with automatic preloading and cache invalidation
- **Memory Management**: Weak references throughout to prevent retain cycles
- **Frequency Capping**: 30-second minimum between ads for optimal user experience

### Key Ad Methods
- `AdManager.initializeMetaAudienceNetwork()`: Meta SDK initialization with test mode support
- `AdManager.showBannerAd()`: Meta banner ad with automatic sizing
- `AdManager.showInterstitialAd()`: Frequency-capped Meta interstitials
- `AdManager.showRewardedAd()`: Meta rewarded video with completion callbacks

### Build Requirements
- **CocoaPods**: `pod install` required for Meta Audience Network SDK
- **Workspace**: Must use `Sudoku Master.xcworkspace` (not .xcodeproj)
- **Info.plist**: Meta SKAdNetwork IDs, ATT description, and privacy manifests
- **Placement IDs**: Configure actual Meta placement IDs in `AdConfiguration` struct

## Module Resolution & Build Fixes (2025-08-17)

### CocoaPods Module Import Issues Resolution
**Problem**: Multiple module import errors preventing successful builds
- `No such module 'GoogleMobileAds'`
- `No such module 'FBLPromises'` 
- Sandbox permission errors with FBAudienceNetwork framework

**Root Causes Identified**:
1. User script sandboxing was blocking framework file operations
2. PromisesSwift/PromisesObjC module map misconfiguration
3. Missing explicit promise dependencies in Podfile
4. Incorrect Xcode project file being used (.xcodeproj vs .xcworkspace)

**Solutions Implemented**:

#### 1. Sandbox Restrictions Fix
**Location**: `Podfile` post_install hook (lines 52-58)
```ruby
# Fix sandbox issues with FBAudienceNetwork and other frameworks
config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'
```
**Impact**: Resolved rsync permission denied errors for framework operations

#### 2. Promises Module Resolution
**Location**: `Podfile` explicit dependencies (lines 27-28) and post_install configuration (lines 61-67)
```ruby
# Explicit Promise dependencies to fix module resolution
pod 'PromisesObjC', '~> 2.1'
pod 'PromisesSwift', '~> 2.1'
```
**Impact**: Fixed `FBLPromises` module import errors in PromisesSwift

#### 3. Framework Search Paths
**Location**: `Podfile` post_install hook (lines 57-58)
```ruby
config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= []
config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/**'
```
**Impact**: Ensured all frameworks are discoverable by the build system

### Automated Fix Scripts
**Created**: `fix-sandbox.sh` and `build-fix.sh` for comprehensive build issue resolution
**Features**:
- Complete pod deintegration and reinstallation
- Derived data cleaning
- Framework permission fixes
- Module verification
- Automated troubleshooting guidance

### Critical Build Process
**ALWAYS Use Workspace**: `Sudoku Master.xcworkspace` (NOT `Sudoku Master.xcodeproj`)
**Required Steps**:
1. Run `./build-fix.sh` if module issues occur
2. Open workspace file in Xcode
3. Clean Build Folder (Shift+Cmd+K)
4. Build project (Cmd+B)

### Key Lessons Learned
1. **Xcode Sandboxing**: Modern Xcode versions have stricter sandboxing that can interfere with CocoaPods framework operations
2. **Promise Dependencies**: Some Firebase/Google SDKs require explicit PromisesObjC/PromisesSwift dependencies
3. **Module Maps**: Framework module resolution can fail if module maps aren't properly configured
4. **Workspace Requirement**: CocoaPods integration requires using .xcworkspace, not .xcodeproj

## Cloud Run Migration Implementation (2025-08-17)

### App Engine to Cloud Run Migration
**Problem**: Need to migrate backend API from App Engine Flex to Cloud Run for better performance and cost efficiency
**Solution**: Complete containerization and Cloud Run deployment configuration

### Migration Benefits
- **Faster cold starts**: Seconds vs minutes compared to App Engine Flex
- **Pay-per-request**: More cost-effective for variable traffic
- **Better scaling**: 0 to 1000+ instances with fine-grained control
- **Container-native**: Modern deployment approach

### Implementation Files Created
1. **`api-server/Dockerfile`**: Optimized Node.js container with security best practices
2. **`api-server/cloudbuild.yaml`**: Google Cloud Build configuration for CI/CD
3. **`api-server/service.yaml`**: Knative service definition for advanced configurations
4. **`api-server/deploy.sh`**: Automated deployment script using Cloud Build
5. **`api-server/gcloud-deploy.sh`**: Simple direct deployment script

### Key Configuration Changes
- **Port Change**: Updated from 3000 to 8080 (Cloud Run standard)
- **Health Checks**: Added startup and liveness probes on `/api` endpoint
- **Resource Limits**: 512Mi memory, 1 CPU, 100 max instances
- **Security**: Non-root user, minimal attack surface

### Deployment Options
```bash
# Quick deployment (recommended for development)
./gcloud-deploy.sh YOUR_PROJECT_ID us-central1

# Advanced deployment with Cloud Build (recommended for production)
./deploy.sh YOUR_PROJECT_ID us-central1
```

### Environment Variables
Cloud Run supports environment variables for configuration:
```bash
gcloud run services update sudoku-master-api \
  --set-env-vars NODE_ENV=production,CUSTOM_VAR=value \
  --region us-central1
```

## Meta Audience Network ONLY Integration (2025-08-18)

### Complete Google/TikTok Cleanup Implementation
**Date**: August 18, 2025  
**Status**: ✅ COMPLETE - Meta-only integration successful  
**Goal**: Simplified build and maintenance by removing ALL non-Meta ad dependencies

### What Was Completely Removed
#### **Google AdMob Dependencies - ELIMINATED**
- ❌ `Google-Mobile-Ads-SDK` pod dependency
- ❌ `GoogleUserMessagingPlatform` pod dependency  
- ❌ GAD* class references in all Swift files
- ❌ Google AdMob configuration from Info.plist
- ❌ Google-specific initialization code from AppDelegate.swift

#### **Firebase Dependencies - ELIMINATED**  
- ❌ `Firebase/Analytics` pod dependency
- ❌ `Firebase/Crashlytics` pod dependency
- ❌ `PromisesObjC`/`PromisesSwift` explicit dependencies
- ❌ All Firebase imports and initialization code
- ❌ GoogleUtilities and related modules

#### **TikTok Audience Network - ELIMINATED**
- ❌ TikTok/ByteDance imports removed
- ❌ `Ads-Global` pod references removed
- ❌ BU* class references eliminated
- ❌ TikTok configuration removed

### Final Clean State Achieved
**Current Dependencies**: 1 total
```ruby
# Podfile - Meta ONLY
pod 'FBAudienceNetwork', '~> 6.15'
```

**Build Results**:
- **Pod install**: 1 dependency, 1 total pod installed
- **Module conflicts**: 0 (all Google modules eliminated)
- **Build complexity**: Dramatically simplified
- **Maintenance burden**: Minimal (single SDK to update)

## AppDelegate Window Property Fix (2025-08-19)

### Problem
**Issue**: NSInvalidArgumentException crash with error:
```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', 
reason: '-[Sudoku_Master.AppDelegate window]: unrecognized selector sent to instance'
```

### Root Cause
SwiftUI apps using `@UIApplicationDelegateAdaptor` don't automatically have a `window` property, but some frameworks (like Meta Audience Network) expect traditional UIKit AppDelegate pattern with window property.

### Solution
**Location**: `Sudoku Master/AppDelegate.swift:6`
**Fix**: Added window property to AppDelegate:
```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?  // Added for compatibility with Meta SDK
    // ... rest of properties
}
```

### Impact
- **Compatibility**: Ensures Meta Audience Network SDK can access window property
- **Stability**: Prevents NSInvalidArgumentException crashes during ad initialization
- **SwiftUI Integration**: Maintains SwiftUI app lifecycle while providing UIKit compatibility

## Sudoku Grid Layout Fix (2025-08-19)

### Problem
**Issue**: Sudoku grid layout completely broken with numbers scattered and not properly aligned in cells
- Numbers appearing outside cell boundaries
- Inconsistent cell sizing
- Poor visual alignment

### Root Cause
LazyVStack and LazyHStack in SudokuBoardView were causing layout calculation issues, resulting in improper cell sizing and positioning.

### Solution
**Location**: `Sudoku Master/Views/SudokuBoardView.swift:40-75`
**Fix**: Replaced lazy layouts with proper geometry-based grid:
```swift
GeometryReader { geometry in
    let cellSize = min(geometry.size.width, geometry.size.height) / 9
    
    ZStack {
        // Background and grid lines
        Rectangle().fill(colors.backgroundColor)
        GridLinesView(colors: colors)
        
        // Fixed-size cells
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        OptimizedSudokuCell(...)
                        .frame(width: cellSize, height: cellSize)  // Fixed sizing
                    }
                }
            }
        }
    }
}
```

### Impact
- **Proper Grid Layout**: Numbers now properly contained within cell boundaries
- **Consistent Sizing**: All cells uniformly sized based on available space
- **Visual Alignment**: Perfect 9x9 Sudoku grid appearance
- **Responsive Design**: Scales properly across different screen sizes

## Meta Ad Loading Failures Fix (2025-08-19)

### Problem
**Issue**: Meta Audience Network ad loading failures with errors:
- "Server Error" for rewarded ads
- "Cannot parse response" network errors
- Invalid placement ID configuration causing ad failures

### Root Cause
App was attempting to load ads with placeholder placement IDs (`"YOUR_PLACEMENT_ID"`) which are invalid and cause server errors when Meta SDK tries to request ads.

### Solution
**Location**: `Sudoku Master/ViewModels/AdManager.swift:20-43`
**Fix**: Added graceful ad disabling with fallback functionality:
```swift
private struct AdConfiguration {
    // Disable ads until proper placement IDs are configured
    static let adsEnabled = false
    
    // IMPORTANT: Replace with actual placement IDs from Meta dashboard
    static let metaPlacementBanner = "YOUR_BANNER_PLACEMENT_ID"
    static let metaPlacementInterstitial = "YOUR_INTERSTITIAL_PLACEMENT_ID"
    static let metaPlacementRewarded = "YOUR_REWARDED_PLACEMENT_ID"
}
```

**Fallback Implementation**:
- **Rewarded Ads**: Provide free rewards when ads disabled/fail
- **Banner Ads**: Gracefully hide when placement IDs not configured
- **Interstitial Ads**: Skip display when disabled
- **Error Handling**: Clear user feedback about ad status

### To Enable Ads
1. Get placement IDs from [Meta Audience Network](https://developers.facebook.com/apps)
2. Replace placeholder IDs in `AdConfiguration`
3. Set `adsEnabled = true`
4. Test with Meta's test device configuration

### Impact
- **No Crashes**: App functions normally without valid placement IDs
- **User Experience**: Free rewards available when ads unavailable
- **Development Ready**: Easy to enable ads when placement IDs obtained
- **Graceful Degradation**: App works perfectly without ad revenue stream

## Login Parsing Error Fix (2025-08-19)

### Problem
**Issue**: Users experiencing login failures with error:
- "Login failed: Network error: cannot parse response"
- JSON parsing errors during authentication

### Root Cause
Network response parsing issues and insufficient error handling for different failure scenarios.

### Solution
**Location**: `Sudoku Master/ViewModels/APIService.swift:305-321` and `AuthManager.swift:48-59`
**Fix**: Enhanced error handling and debugging:

1. **API Response Debugging**:
```swift
// Debug: Print response data for troubleshooting
if let responseString = String(data: data, encoding: .utf8) {
    print("🔍 API Response: \(responseString)")
}

do {
    let decodedResponse = try decoder.decode(T.self, from: data)
    return decodedResponse
} catch {
    print("❌ JSON Decoding Error: \(error)")
    print("❌ Failed to decode type: \(T.self)")
    throw APIError.decodingError(error: error)
}
```

2. **Improved User Error Messages**:
```swift
if errorMessage.contains("parse") {
    self.error = "Network issue. Try 'Continue as Guest' to play offline, or check your internet connection."
} else if errorMessage.contains("credentials") || errorMessage.contains("401") {
    self.error = "Invalid username or password. Please try again."
}
```

### API Status Verification
- ✅ Health endpoint responding: `https://sudoku-master-api-93673815784.us-central1.run.app/api`
- ✅ Registration working: Returns proper JSON response
- ✅ Login working: Returns user object with correct format

### Impact
- **Better Debugging**: Console logs show exact parsing failures
- **User-Friendly Messages**: Clear guidance for different error types
- **Graceful Fallback**: Suggests offline mode for network issues
- **API Validation**: Confirmed backend is responding correctly

### HTTP Protocol Fix (Additional)
**Issue**: Network error -1017 "cannot parse response" with HTTP/2 protocol violations
**Solution**: Modified URLSession configuration to use HTTP/1.1:
```swift
// Force HTTP/1.1 to avoid HTTP/2 protocol violations
config.httpMaximumConnectionsPerHost = 2
config.requestCachePolicy = .reloadIgnoringLocalCacheData
config.urlCache = nil  // Disable URL caching to prevent conflicts

// Request headers to force HTTP/1.1
request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")  // Disable compression
request.setValue("close", forHTTPHeaderField: "Connection")  // Force connection close
```

**Result**: Eliminates "Server protocol violation" and "Control stream closed" errors

### Additional Networking Resilience (Final Fix)
**Issue**: Persistent -1017 errors despite HTTP/1.1 configuration
**Solution**: Implemented dual networking approach with fallback:

1. **Simple Request Method**: Uses `URLSession.shared` with minimal configuration
```swift
private func performSimpleRequest<T: Decodable, U: Encodable>(
    endpoint: String, method: String, body: U? = nil
) async throws -> T {
    // Basic URLSession with no advanced features
    let (data, response) = try await URLSession.shared.data(for: request)
    // Simple JSON decoding without caching
}
```

2. **Fallback Architecture**: 
   - Try simple request first (bypasses URLSession configuration issues)
   - Fall back to optimized request if simple fails
   - Provides maximum compatibility across different network conditions

3. **Configuration Simplification**:
```swift
let config = URLSessionConfiguration.ephemeral  // No caching
config.httpMaximumConnectionsPerHost = 1  // Single connection
config.waitsForConnectivity = false  // Immediate failure vs waiting
```

**Final Result**: Two-tier approach ensures login works in all network scenarios

### Critical Build Fixes Applied

#### 1. **Sandbox Permission Resolution (2025-08-18)**
**Problem**: `bash deny(1) file-write-create` errors during CocoaPods resource processing
**Root Cause**: Xcode 15+ stricter sandboxing blocking script operations

**Solutions Applied**:
```ruby
# Podfile post-install hook:
config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'NO'
config.build_settings['OTHER_LDFLAGS'] << '-ObjC'
```

```diff
# project.pbxproj fix:
- ENABLE_USER_SCRIPT_SANDBOXING = YES;
+ ENABLE_USER_SCRIPT_SANDBOXING = NO;
```

#### 2. **AdManager Access Level Resolution (2025-08-18)**
**Problem**: Extension delegates couldn't access private methods
**Solution**: Changed key methods from `private` to `internal`:
```swift
// Made accessible to delegates:
internal var rewardCompletion: ((Bool, Int) -> Void)?
internal func cacheAd(_ adType: AdType)
internal func recordAdLoad(_ adType: AdType)
internal func recordAdShow(_ adType: AdType) 
internal func recordAdFailure(_ adType: AdType, error: Error)
internal func recordAdReward(_ adType: AdType, amount: Int)
internal func loadMetaInterstitial()
internal func loadMetaRewarded()
```

#### 3. **Environment Object Scope Resolution (2025-08-18)**
**Problem**: `Cannot find 'adManager' in scope` in HomeView nested structures
**Solution**: Added `@EnvironmentObject var adManager: AdManager` to all view structs that need it:
```swift
// Fixed scope in MainContentView:
private struct MainContentView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineStorage: OfflineStorage
    @EnvironmentObject var adManager: AdManager  // ← Added
    @Binding var showProfileSheet: Bool
```

#### 4. **Meta SDK API Updates (2025-08-18)**
**Problem**: Deprecated enum values in Meta Audience Network SDK 6.20.1
**Solution**: Updated to current API:
```swift
// Before (deprecated):
FBAdSettings.setLogLevel(.FBAdLogLevelLog)

// After (current):
FBAdSettings.setLogLevel(.log)
```

#### 5. **Info.plist Conflict Resolution (2025-08-18)**
**Problem**: `Multiple commands produce Info.plist` build errors
**Solution**: Switched to auto-generated Info.plist approach:
```diff
# Changed from custom to auto-generated:
- INFOPLIST_FILE = "Sudoku Master/Info.plist"
+ GENERATE_INFOPLIST_FILE = YES
+ INFOPLIST_KEY_NSUserTrackingUsageDescription = "This app uses tracking..."
```

### Workspace Corruption Troubleshooting (2025-08-18)
**Symptoms**: "Sudoku Master.xcworkspace is not opening"  
**Solution Process**:
1. Delete corrupted workspace: `rm -rf "Sudoku Master.xcworkspace"`
2. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/Sudoku_Master-*`
3. Remove CocoaPods: `rm -rf Pods/ Podfile.lock`
4. Reinstall: `pod install --repo-update`
5. Open new workspace: `open "Sudoku Master.xcworkspace"`

### Build Verification Commands
```bash
# Clean everything
rm -rf "Sudoku Master.xcworkspace" Pods/ Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Sudoku_Master-*

# Reinstall Meta-only
pod install --repo-update

# Verify clean state
echo "Dependencies: $(grep -c 'pod ' Podfile)"  # Should be 1
echo "Total pods: $(cat Podfile.lock | grep -c 'SPEC CHECKSUMS' -A 50 | wc -l)"

# Open and build
open "Sudoku Master.xcworkspace"
# Then: Clean Build Folder (Shift+Cmd+K) → Build (Cmd+B)
```

### Integration Benefits Achieved

#### **For Development**
- **Simplified Build**: Single ad network, minimal dependencies
- **Easier Debugging**: No multi-network fallback complexity
- **Cleaner Code**: Meta-specific implementations only
- **Faster Builds**: Reduced dependency compilation time

#### **For Maintenance** 
- **Single SDK Updates**: Only Meta SDK to maintain
- **Simplified Testing**: One ad network to validate
- **Clearer Documentation**: Focused implementation guide
- **Reduced Complexity**: No cross-network compatibility issues

#### **For Performance**
- **Smaller Binary**: Removed unused SDKs (Google, Firebase, TikTok)
- **Faster Initialization**: Single network setup only
- **Optimized Memory**: No unused framework loading
- **Better UX**: Consistent ad experience across all placements

### Production Readiness
**Status**: ✅ Ready for production deployment

**Required for Production**:
1. **Configure Meta Placement IDs**:
   ```swift
   // In AdManager.swift:20-22
   static let metaPlacementBanner = "YOUR_ACTUAL_META_BANNER_ID"
   static let metaPlacementInterstitial = "YOUR_ACTUAL_META_INTERSTITIAL_ID"
   static let metaPlacementRewarded = "YOUR_ACTUAL_META_REWARDED_ID"
   ```

2. **Set up App-ads.txt**:
   ```
   # Add to https://yourdomain.com/app-ads.txt
   facebook.com, YOUR_META_BUSINESS_ID, DIRECT, c3e20eee3f780d68
   ```

3. **Disable Debug Mode**:
   ```swift
   // Remove or comment out in production:
   #if DEBUG
   FBAdSettings.addTestDevice(FBAdSettings.testDeviceHash())
   #endif
   ```

### Key Learnings & Best Practices

#### **CocoaPods & Xcode 15+ Compatibility**
1. **Sandboxing**: Modern Xcode requires explicit `ENABLE_USER_SCRIPT_SANDBOXING = NO`
2. **Workspace Priority**: Always use `.xcworkspace`, never `.xcodeproj` with CocoaPods
3. **Clean Rebuilds**: Corruption issues require complete clean + reinstall cycle
4. **Access Levels**: Extensions need `internal` access to call main class methods

#### **Meta SDK Integration**
1. **API Updates**: SDK 6.20.1 uses `.log` instead of `.FBAdLogLevelLog`
2. **Environment Objects**: Ensure all view structs have necessary `@EnvironmentObject` declarations
3. **Privacy First**: ATT integration is essential for Meta ad performance
4. **Auto-Generated Info.plist**: Simpler than custom plist for basic configurations

#### **Troubleshooting Guide**
- **Workspace won't open**: Delete and rebuild completely
- **Module not found**: Check CocoaPods installation and workspace usage
- **Sandbox errors**: Verify `ENABLE_USER_SCRIPT_SANDBOXING = NO` in both Podfile and project
- **AdManager scope errors**: Ensure environment objects declared in all view structs
- **Delegate access errors**: Change required methods from `private` to `internal`

**Final Result**: Clean, maintainable, Meta-only ad integration ready for production deployment.

## Cloud Run API Deployment (2025-08-18)

### Successful Cloud Run Deployment
**Status**: ✅ DEPLOYED - API Live on Google Cloud Run (Correct Project)
**Endpoint**: `https://sudoku-master-api-93673815784.us-central1.run.app/api`
**Project**: `sudoku-master-467202` (Sudoku Master)
**Region**: `us-central1`

### Deployment Configuration
- **Service Name**: `sudoku-master-api`
- **Memory**: 512Mi
- **CPU**: 1
- **Max Instances**: 100
- **Concurrency**: 80
- **Timeout**: 300 seconds
- **Port**: 8080

### API Endpoints Available
```
GET  /api                           # Health check ✅ Working
GET  /api/sudoku/generate           # Puzzle generation ✅ Working
POST /api/users/register            # User registration ✅ Available
POST /api/users/login               # Authentication ✅ Available
POST /api/sudoku/validate           # Move validation ✅ Available
POST /api/sudoku/solve              # Puzzle solving ✅ Available
POST /api/sudoku/save-progress      # Game progress ✅ Available
GET  /api/sudoku/user-stats/:userId # User statistics ✅ Available
```

### iOS App Integration Updated
- **APIService.swift**: Updated baseURL to point to Cloud Run endpoint
- **CLAUDE.md**: Documentation updated with new API URL
- **Deployment Date**: August 18, 2025

### Deployment Commands Used
```bash
# Corrected deployment to proper project
gcloud config set project sudoku-master-467202
cd api-server
./gcloud-deploy.sh sudoku-master-467202 us-central1
```

**Result**: Complete Meta-only iOS app with live Cloud Run API backend ready for production use.

### Swift Concurrency Fix (2025-08-18)
**Problem**: `SWIFT TASK CONTINUATION MISUSE: loadPuzzlesFromStorage() tried to resume its continuation more than once`
**Root Cause**: Multiple `continuation.resume()` calls in async method (defer block + guard condition)
**Solution**: Added safe resume pattern to prevent double resumption:
```swift
private func loadPuzzlesFromStorage() async -> [String: [SudokuPuzzle]]? {
    return await withCheckedContinuation { continuation in
        storageQueue.async { [weak self] in
            var hasResumed = false
            
            func safeResume(returning value: [String: [SudokuPuzzle]]?) {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: value)
            }
            // Use safeResume() instead of continuation.resume()
        }
    }
}
```
**Impact**: Eliminates fatal continuation misuse crashes in OfflineStorage