# Sudoku Master API Server

A simple Express.js API server for the Sudoku Master iOS app.

## Features

- ✅ User authentication (register, login, logout)
- ✅ Sudoku puzzle generation (easy, medium, hard)
- ✅ Move validation
- ✅ Puzzle solving using backtracking algorithm
- ✅ Game progress tracking
- ✅ User statistics
- ✅ CORS enabled for cross-origin requests

## Quick Start

1. **Install dependencies:**
   ```bash
   cd api-server
   npm install
   ```

2. **Run the server:**
   ```bash
   npm start
   ```
   
   Or for development with auto-restart:
   ```bash
   npm run dev
   ```

3. **Test the API:**
   Open http://localhost:3000/api in your browser

## API Endpoints

### Authentication
- `POST /api/users/register` - Register new user
- `POST /api/users/login` - Login user
- `GET /api/users/me` - Get current user
- `POST /api/users/logout` - Logout user

### Sudoku Game
- `GET /api/sudoku/generate?difficulty=easy` - Generate puzzle
- `POST /api/sudoku/validate` - Validate move
- `POST /api/sudoku/solve` - Solve puzzle
- `POST /api/sudoku/save-progress` - Save game progress
- `GET /api/sudoku/user-stats/:userId` - Get user stats

## Update iOS App

Update the API URL in your iOS app:

```swift
// In APIService.swift
let baseURL = "http://localhost:3000/api"
```

## Deployment Options

### Option 1: Local Development
Just run `npm start` and use `http://localhost:3000/api`

### Option 2: Deploy to Railway
1. Create account at railway.app
2. Connect your GitHub repo
3. Deploy automatically

### Option 3: Deploy to Render
1. Create account at render.com
2. Create new Web Service
3. Connect repository

### Option 4: Deploy to Heroku
1. Install Heroku CLI
2. `heroku create sudoku-master-api`
3. `git push heroku main`

## Environment Variables

For production deployment, you might want to set:
- `PORT` - Server port (defaults to 3000)
- `NODE_ENV` - Environment (development/production)

## Note

This is a simple in-memory server suitable for development and testing. For production, you should:
- Add a real database (PostgreSQL, MongoDB, etc.)
- Implement proper authentication with JWT tokens
- Add input validation and sanitization
- Add rate limiting
- Add logging
- Add error handling middleware