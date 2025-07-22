# SudokuMaster iOS App

This folder contains all the Swift files needed to create a SudokuMaster iOS app with offline mode support.

## Structure

The project is organized into the following directories:

- **Models**: Data models for the application
- **Views**: UI components and screens
- **ViewModels**: Business logic and data management
- **Utils**: Helper classes and utilities

## Setting Up in Xcode

1. Open Xcode and create a new iOS app project
   - Choose "App" template
   - Set Product Name: "SudokuMaster"
   - Interface: SwiftUI
   - Life Cycle: UIKit App Delegate
   - Language: Swift

2. After creating the project, you should replace the default files with the files in this folder, maintaining the folder structure.

3. Make sure to include all the files in your Xcode project by adding them to the appropriate group:
   - Select a group in Xcode (e.g., Models)
   - Right-click and select "Add Files to 'SudokuMaster'..."
   - Navigate to the corresponding directory in this folder
   - Select all files in that directory
   - Click "Add"

## Key Features Implemented

### Offline Mode

The offline mode functionality is fully implemented with the following components:

- **NetworkMonitor**: Tracks network connectivity status
- **OfflineStorage**: Manages saving and retrieving puzzles for offline play
- **Offline Toggle**: User interface to manually enable/disable offline mode
- **Profile View**: Shows offline status and puzzle download options

### Core Game Features

- Multiple difficulty levels
- Keyboard input for numbers
- Error validation
- Auto-solve functionality
- Hint system
- Victory detection
- Game progress tracking

## File Overview

- **AppDelegate.swift**: Manages the app lifecycle
- **SudokuMasterApp.swift**: Main app entry point
- **ContentView.swift**: Root view that shows either auth or game screen
- **Models/SudokuModels.swift**: All data models for the app
- **Utils/NetworkMonitor.swift**: Network connectivity tracking
- **Utils/OfflineStorage.swift**: Offline data management
- **ViewModels/APIService.swift**: API communication with backend
- **ViewModels/AuthManager.swift**: Authentication management
- **ViewModels/SudokuStore.swift**: Game state and logic
- **Views/HomeView.swift**: Main game screen
- **Views/SudokuBoardView.swift**: Sudoku grid display
- **Views/AuthView.swift**: Login and registration
- **Views/ProfileView.swift**: User profile and settings

## Known Limitations

- The app assumes API endpoints match those in the web version
- Some features like theme changing are UI-only in this version
- User-created puzzles interface is not fully implemented

## Getting Help

If you encounter issues while setting up this project, please refer to the documentation or contact the development team.