# Sudoku Master iOS App with Cloud Run Backend

A complete SwiftUI iOS Sudoku game with streamlined Meta Audience Network ad monetization, offline mode support, and a containerized Node.js backend deployable to Google Cloud Run.

## 📱 Project Overview

### iOS App Features
- **Complete Sudoku Game**: Multiple difficulty levels with auto-generation and solving
- **Dual Mode Operation**: Online API integration with offline fallback
- **Streamlined Ad Integration**: Meta Audience Network ONLY with privacy compliance (simplified build)
- **User Authentication**: Login/registration with progress tracking
- **Performance Optimized**: Async operations, intelligent caching, real-time monitoring

### Backend API
- **Node.js Express Server**: RESTful API for puzzle generation and user management
- **Cloud Run Deployment**: Containerized deployment with auto-scaling
- **Migration Ready**: Complete migration from App Engine Flex to Cloud Run

## 🚀 Quick Start

### Prerequisites
1. **iOS Development**:
   - Xcode 14.0+ 
   - iOS 15.0+ deployment target
   - CocoaPods installed: `brew install cocoapods`

2. **Backend Deployment**:
   - Google Cloud CLI installed and authenticated
   - Docker (for local development)
   - Node.js 18+ (for local development)

### iOS App Setup

1. **Clone and Install Dependencies**:
   ```bash
   git clone <repository-url>
   cd Sudoku-Master-Ads
   pod install
   ```

2. **⚠️ CRITICAL: Open Workspace File**:
   ```bash
   open "Sudoku Master.xcworkspace"  # NOT .xcodeproj!
   ```

3. **Build and Run**:
   - Clean Build Folder: Product → Clean Build Folder (Shift+Cmd+K)
   - Build: Cmd+B
   - Run: Cmd+R

### Backend Deployment to Cloud Run

1. **Quick Deployment**:
   ```bash
   cd api-server
   ./gcloud-deploy.sh YOUR_PROJECT_ID us-central1
   ```

2. **Advanced Deployment with CI/CD**:
   ```bash
   cd api-server
   ./deploy.sh YOUR_PROJECT_ID us-central1
   ```

## 🏗️ Architecture

### iOS App Structure
```
Sudoku Master/
├── Models/
│   └── SudokuModels.swift          # Core data models
├── ViewModels/
│   ├── SudokuStore.swift           # Game state management
│   ├── APIService.swift            # Backend communication
│   ├── AuthManager.swift           # User authentication
│   ├── AdManager.swift             # Ad monetization
│   └── AdManager+Delegates.swift   # Ad network delegates
├── Views/
│   ├── HomeView.swift              # Main game interface
│   ├── SudokuBoardView.swift       # Interactive grid
│   ├── AuthView.swift              # Authentication UI
│   └── ProfileView.swift           # User profile
├── Utils/
│   ├── NetworkMonitor.swift        # Connectivity tracking
│   ├── OfflineStorage.swift        # Local puzzle storage
│   └── PerformanceMonitor.swift    # Real-time metrics
└── AppDelegate.swift               # Lifecycle management
```

### Backend API Structure
```
api-server/
├── server.js                      # Express server
├── package.json                    # Dependencies
├── Dockerfile                      # Container configuration
├── cloudbuild.yaml                 # Cloud Build CI/CD
├── service.yaml                    # Knative service definition
├── deploy.sh                       # Cloud Build deployment
├── gcloud-deploy.sh                # Direct deployment
└── README.md                       # API documentation
```

## 🔧 Build & Troubleshooting

### Common Build Issues

#### Module Import or Sandbox Errors
If you encounter module import errors or sandbox permission issues:

```bash
# Clean rebuild for Meta-only integration
rm -rf "Sudoku Master.xcworkspace" Pods/ Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Sudoku_Master-*
pod install --repo-update
open "Sudoku Master.xcworkspace"
```

This resolves:
- ✅ Meta Audience Network module resolution
- ✅ Sandbox permission errors (`ENABLE_USER_SCRIPT_SANDBOXING = NO`)
- ✅ Workspace corruption issues
- ✅ Simplified dependency conflicts

#### Manual Fix Steps
1. **Ensure Workspace Usage**: Always open `Sudoku Master.xcworkspace`
2. **Clean Everything**:
   ```bash
   cd /path/to/project
   rm -rf ~/Library/Developer/Xcode/DerivedData/Sudoku_Master-*
   pod deintegrate && pod install
   ```
3. **Xcode Clean**: Product → Clean Build Folder (Shift+Cmd+K)

### Key Build Requirements
- **CocoaPods Integration**: Must use `.xcworkspace` file
- **Sandbox Settings**: Disabled for framework compatibility (`ENABLE_USER_SCRIPT_SANDBOXING = NO`)
- **Simplified Dependencies**: Only Meta Audience Network SDK (6.15+)
- **Access Levels**: Internal methods for delegate extensions

## 📊 Ad Monetization - Meta Audience Network Only

### Streamlined Integration (2025-08-18)
- **Meta Audience Network**: Single ad network for simplified maintenance
- **Complete Cleanup**: All Google AdMob, Firebase, and TikTok dependencies REMOVED
- **Privacy Compliance**: App Tracking Transparency + comprehensive privacy manifests
- **Production Ready**: Clean build with minimal dependencies

### Ad Integration Points
1. **Banner Ads**: Bottom of main game screen using `FBAdView`
2. **Interstitial Ads**: After puzzle completion (frequency-capped) using `FBInterstitialAd`
3. **Rewarded Video Ads**: Hint system integration using `FBRewardedVideoAd`

### Performance Features
- **Async Loading**: Background ad operations with MainActor integration
- **Intelligent Caching**: 5-minute TTL with automatic preloading
- **Memory Optimization**: Weak references and proper cleanup
- **Frequency Capping**: 30-second minimum between ads for optimal UX

### Dependencies Summary
```ruby
# Podfile - Clean and Simple
pod 'FBAudienceNetwork', '~> 6.15'
```
**Result**: 1 dependency, 1 total pod installed (compared to 16+ with multi-network setup)

## ☁️ Cloud Run Backend

### Migration Benefits
- **Cost Efficiency**: Pay-per-request vs always-on pricing
- **Performance**: Sub-second cold starts vs minutes
- **Scalability**: 0-1000+ instances with fine control
- **Modern Stack**: Container-native deployment

### API Endpoints
```
GET  /api                           # Health check
POST /api/users/register            # User registration
POST /api/users/login               # Authentication
GET  /api/users/me                  # Current user info
GET  /api/sudoku/generate           # Puzzle generation
POST /api/sudoku/validate           # Move validation
POST /api/sudoku/solve              # Puzzle solving
POST /api/sudoku/save-progress      # Game progress
GET  /api/sudoku/user-stats/:userId # User statistics
```

### Environment Configuration
```bash
# Set environment variables
gcloud run services update sudoku-master-api \
  --set-env-vars NODE_ENV=production,PORT=8080 \
  --region us-central1
```

## 🔄 Offline Mode

### Features
- **Automatic Fallback**: Seamless transition when network unavailable
- **Local Storage**: Downloaded puzzles cached in UserDefaults
- **Generated Puzzles**: Fallback puzzle generation with backtracking solver
- **Progress Sync**: Local progress synced when connectivity restored

### Implementation
- `NetworkMonitor`: Real-time connectivity tracking
- `OfflineStorage`: Puzzle caching and retrieval
- `SudokuStore`: Unified online/offline game logic

## 📱 Game Features

### Core Gameplay
- **Multiple Difficulties**: Easy, Medium, Hard with adaptive puzzle generation
- **Smart Validation**: Real-time move checking with conflict highlighting
- **Auto-Solve**: Backtracking algorithm implementation
- **Hint System**: Integrated with rewarded ad monetization
- **Progress Tracking**: Game statistics and completion analytics

### Automatic Puzzle Reload
- **Smart Difficulty Selection**: Automatically loads new puzzle when difficulty changes
- **Seamless UX**: No manual "new game" required
- **State Management**: Proper game state reset and timer handling

## 🛠️ Development Guidelines

### Code Conventions
- **SwiftUI MVVM**: Clear separation of UI, business logic, and data
- **Environment Objects**: Centralized state management
- **Async/Await**: Modern concurrency patterns
- **Error Handling**: Comprehensive error states and user feedback

### Testing
```bash
# iOS Unit Tests
cmd+U in Xcode

# Backend API Tests
cd api-server
npm test  # If test scripts are added
```

### Performance Monitoring
- **Real-time Metrics**: Built-in performance monitoring
- **Memory Management**: Automatic leak detection
- **Network Optimization**: Request caching and batching

## 📝 Recent Implementation Learnings

### Meta-Only Integration Cleanup (2025-08-18)
- **Complete Simplification**: Removed ALL Google AdMob, Firebase, and TikTok dependencies
- **Dependency Reduction**: From 16+ pods to 1 single pod (Meta Audience Network)
- **Build Simplification**: Eliminated module conflicts and complex fallback logic
- **Sandbox Resolution**: Fixed Xcode 15+ sandboxing issues with `ENABLE_USER_SCRIPT_SANDBOXING = NO`

### Critical Fixes Applied (2025-08-18)
- **Access Level Issues**: Changed private methods to internal for delegate extensions
- **Environment Object Scope**: Added `@EnvironmentObject var adManager: AdManager` to all required view structs
- **Meta SDK API Updates**: Updated deprecated `.FBAdLogLevelLog` to `.log` for SDK 6.20.1
- **Info.plist Conflicts**: Switched to auto-generated Info.plist to eliminate duplicate build errors

### Cloud Run Migration (2025-08-17)  
- **Complete Containerization**: Optimized Docker configuration
- **Deployment Automation**: Multiple deployment strategies
- **Performance Optimization**: Resource limits and health checks

### Build Quality Improvements
- **Workspace Corruption Recovery**: Comprehensive rebuild procedures for corrupted workspaces
- **Troubleshooting Automation**: Step-by-step resolution for common build issues
- **Documentation Enhancement**: Complete integration learnings captured in CLAUDE.md

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Follow build setup instructions above
4. Make changes and test thoroughly
5. Submit pull request with detailed description

### Code Quality
- Follow existing code conventions
- Add appropriate comments for complex logic
- Test both online and offline modes
- Verify ad integration functionality

## 📄 License

This project is for educational and demonstration purposes. Please ensure compliance with all third-party SDK licenses and privacy regulations when deploying to production.

## 🆘 Support

### Common Issues
1. **Module Import Errors**: Run clean rebuild commands (see Build & Troubleshooting section)
2. **Sandbox Permission Errors**: Verify `ENABLE_USER_SCRIPT_SANDBOXING = NO` in both Podfile and project
3. **Workspace Won't Open**: Delete workspace and rebuild: `rm -rf "Sudoku Master.xcworkspace" && pod install`
4. **AdManager Scope Errors**: Ensure `@EnvironmentObject var adManager: AdManager` in all view structs
5. **Meta Ad Loading**: Check network connectivity and Meta placement IDs

### Documentation
- **iOS Development**: See `CLAUDE.md` for detailed implementation notes
- **API Documentation**: See `api-server/README.md` for backend details
- **Build Troubleshooting**: See automated fix scripts for common solutions

For additional support, please check the project's issue tracker or contact the development team.