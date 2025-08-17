# Sudoku Master iOS App with Cloud Run Backend

A complete SwiftUI iOS Sudoku game with comprehensive ad monetization, offline mode support, and a containerized Node.js backend deployable to Google Cloud Run.

## 📱 Project Overview

### iOS App Features
- **Complete Sudoku Game**: Multiple difficulty levels with auto-generation and solving
- **Dual Mode Operation**: Online API integration with offline fallback
- **Comprehensive Ad Integration**: Google AdMob + Meta Audience Network with privacy compliance
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

#### Module Import Errors
If you encounter `No such module 'GoogleMobileAds'` or similar errors:

```bash
# Run the comprehensive build fix
./build-fix.sh
```

This script resolves:
- ✅ CocoaPods module resolution issues
- ✅ Sandbox permission errors
- ✅ Framework search path problems
- ✅ PromisesObjC/PromisesSwift dependencies

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
- **Sandbox Settings**: Disabled for framework compatibility
- **Module Dependencies**: Explicit PromisesObjC/PromisesSwift declarations
- **Framework Permissions**: Automated permission fixes included

## 📊 Ad Monetization

### Integrated Ad Networks
- **Google AdMob**: Primary ad network with full feature support
- **Meta Audience Network**: Fallback with seamless integration  
- **Privacy Compliance**: GDPR/CCPA consent + App Tracking Transparency

### Ad Integration Points
1. **Banner Ads**: Bottom of main game screen
2. **Interstitial Ads**: After puzzle completion (frequency-capped)
3. **Rewarded Ads**: Hint system with user choice

### Performance Features
- **Async Loading**: Background ad operations
- **Intelligent Caching**: 5-minute TTL with preloading
- **Network Resilience**: Automatic fallback cascade
- **Memory Optimization**: Weak references and cache management

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

### Module Resolution Fixes (2025-08-17)
- **Sandbox Issues**: Resolved framework permission errors
- **Promise Dependencies**: Fixed FBLPromises module resolution
- **Build Automation**: Created comprehensive fix scripts

### Cloud Run Migration (2025-08-17)  
- **Complete Containerization**: Optimized Docker configuration
- **Deployment Automation**: Multiple deployment strategies
- **Performance Optimization**: Resource limits and health checks

### Ad Integration (2025-08-16)
- **Multi-Network Setup**: AdMob + Meta with intelligent fallbacks
- **Privacy Compliance**: Full GDPR/CCPA + ATT implementation
- **Performance Optimization**: Async operations with caching

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
1. **Module Import Errors**: Run `./build-fix.sh`
2. **Ad Loading Failures**: Check network connectivity and ad unit IDs
3. **Cloud Run Deployment**: Verify project permissions and API enablement
4. **Build Failures**: Ensure workspace file usage and clean derived data

### Documentation
- **iOS Development**: See `CLAUDE.md` for detailed implementation notes
- **API Documentation**: See `api-server/README.md` for backend details
- **Build Troubleshooting**: See automated fix scripts for common solutions

For additional support, please check the project's issue tracker or contact the development team.