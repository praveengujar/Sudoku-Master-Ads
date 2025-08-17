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
  - `AdManager`: Performance-optimized ad management for Google AdMob and Meta Audience Network
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
- **Online Mode**: Fetches puzzles from API at `https://sudoku-master-app.replit.app/api`
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
- Google AdMob SDK (~> 11.0)
- Meta Audience Network (~> 6.15)
- Google User Messaging Platform (~> 2.1)
- Firebase Analytics & Crashlytics (~> 10.0)

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
The app includes comprehensive ad integration with performance optimizations:
- **Google AdMob**: Banner, interstitial, and rewarded ads
- **Meta Audience Network**: Full integration with fallback support
- **Privacy Compliance**: GDPR/CCPA consent management and App Tracking Transparency (ATT)
- **Performance Optimized**: Async ad loading, intelligent caching, and preloading
- **UX Integration**: Natural ad placement at game completion and hint system

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

## Ad Integration Implementation (2025-08-16)

### Comprehensive Ad Platform Integration
**Implementation**: Complete ad monetization system with Google AdMob and Meta Audience Network
**Location**: `ViewModels/AdManager.swift` and `ViewModels/AdManager+Delegates.swift`
**Features**:
- Performance-optimized async ad loading with caching and preloading
- Privacy compliance with GDPR/CCPA consent management and ATT
- Natural UX integration with banner, interstitial, and rewarded ads
- Comprehensive analytics and performance monitoring

### Ad Integration Points
1. **Banner Ads**: Bottom of `HomeView` using `BannerAdView` UIViewControllerRepresentable
2. **Interstitial Ads**: After puzzle completion (every 3rd game) via `SudokuStore.closeVictoryModal()`
3. **Rewarded Ads**: Hint system integration with user choice dialog in `ActionButtonsView`
4. **Privacy**: App Tracking Transparency prompt and Google User Messaging Platform consent

### Performance Optimizations
- **Async/Await**: All ad operations run on background queues to prevent main thread blocking
- **Intelligent Caching**: 5-minute TTL with automatic preloading and cache invalidation
- **Memory Management**: Weak references throughout to prevent retain cycles
- **Network Resilience**: Fallback cascade (AdMob → Meta) with retry logic

### Key Ad Methods
- `AdManager.initializeAdSDKs()`: Parallel SDK initialization using TaskGroup
- `AdManager.showBannerAd()`: Multi-network banner with auto-layout
- `AdManager.showInterstitialAd()`: Frequency-capped interstitials
- `AdManager.showRewardedAd()`: Cross-platform reward handling with callbacks

### Build Requirements
- **CocoaPods**: `pod install` required for ad SDK dependencies
- **Workspace**: Must use `Sudoku Master.xcworkspace` (not .xcodeproj)
- **Info.plist**: Configure ad unit IDs, ATT description, and SKAdNetwork entries
- **Privacy**: Update privacy policy to reflect ad data collection

### TikTok Integration Status
TikTok Audience Network integration is implemented but temporarily disabled due to SDK compatibility. Can be re-enabled by:
1. Uncommenting TikTok imports in AdManager files
2. Re-enabling TikTok pod in Podfile
3. Restoring TikTok delegate methods
4. Configuring TikTok placement IDs

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