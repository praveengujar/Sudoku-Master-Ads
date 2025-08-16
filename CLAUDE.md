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