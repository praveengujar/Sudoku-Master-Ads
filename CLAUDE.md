# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sudoku Master is a SwiftUI iOS app that provides a complete Sudoku gaming experience with both online and offline modes. The app features user authentication, multiple difficulty levels, game progress tracking, and offline puzzle storage.

## Architecture

The app follows the MVVM pattern with SwiftUI and uses an AppDelegate for lifecycle management:

- **Models** (`Models/SudokuModels.swift`): Core data models including `SudokuPuzzle`, `User`, `UserStats`, `GameplayRecord`, and enums for difficulty levels and themes
- **ViewModels**: Business logic and state management
  - `SudokuStore`: Main game state, puzzle logic, validation, solving, and timer management
  - `APIService`: HTTP client for backend communication
  - `AuthManager`: User authentication and session management
- **Views**: SwiftUI UI components
  - `HomeView`: Main game interface
  - `SudokuBoardView`: Interactive Sudoku grid
  - `AuthView`: Login/registration
  - `ProfileView`: User profile and offline mode settings
- **Utils**: Helper classes
  - `NetworkMonitor`: Tracks network connectivity
  - `OfflineStorage`: Local puzzle storage using UserDefaults

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

This is a standard Xcode project. Use Xcode IDE for building and testing:
- Open `Sudoku Master.xcodeproj` in Xcode
- Build: Cmd+B
- Run: Cmd+R
- Test: Cmd+U

Note: `xcodebuild` requires full Xcode installation, not just Command Line Tools.

## Development Notes

### Environment Objects
The app uses four main environment objects injected at the root level:
- `SudokuStore`: Game state and logic
- `AuthManager`: User authentication
- `NetworkMonitor`: Connectivity status
- `OfflineStorage`: Local data persistence

### API Integration
All API endpoints expect JSON payloads and return structured responses. The `APIService` class handles encoding/decoding with proper error handling for network failures and server errors.

### Offline Functionality
The app gracefully degrades to offline mode when network is unavailable. It includes a fallback puzzle generator and local storage for downloaded puzzles.

### State Persistence
Game progress is saved both locally (UserDefaults) and remotely (API) with conflict resolution favoring the most recent save.

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