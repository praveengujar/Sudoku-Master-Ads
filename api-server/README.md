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
Just run `npm start` and use `http://localhost:8080/api`

### Option 2: Deploy to Google Cloud Run (Recommended)

#### Prerequisites
1. Install Google Cloud CLI: `gcloud auth login`
2. Set your project: `gcloud config set project YOUR_PROJECT_ID`
3. Enable required APIs:
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   ```

#### Quick Deployment (Direct from source)
```bash
./gcloud-deploy.sh YOUR_PROJECT_ID us-central1
```

#### Advanced Deployment (Cloud Build)
```bash
./deploy.sh YOUR_PROJECT_ID us-central1
```

#### Manual Deployment
```bash
# Deploy from source
gcloud run deploy sudoku-master-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi

# Or build and push manually
docker build -t gcr.io/YOUR_PROJECT_ID/sudoku-master-api .
docker push gcr.io/YOUR_PROJECT_ID/sudoku-master-api
gcloud run deploy sudoku-master-api \
  --image gcr.io/YOUR_PROJECT_ID/sudoku-master-api \
  --region us-central1 \
  --allow-unauthenticated
```

### Option 3: Other Cloud Providers

#### Deploy to Railway
1. Create account at railway.app
2. Connect your GitHub repo
3. Deploy automatically

#### Deploy to Render
1. Create account at render.com
2. Create new Web Service
3. Connect repository

#### Deploy to Heroku
1. Install Heroku CLI
2. `heroku create sudoku-master-api`
3. `git push heroku main`

## Environment Variables

For production deployment, you might want to set:
- `PORT` - Server port (defaults to 8080 for Cloud Run)
- `NODE_ENV` - Environment (development/production)

### Setting Environment Variables in Cloud Run
```bash
gcloud run services update sudoku-master-api \
  --set-env-vars NODE_ENV=production,CUSTOM_VAR=value \
  --region us-central1
```

## Note

This is a simple in-memory server suitable for development and testing. For production, you should:
- Add a real database (PostgreSQL, MongoDB, etc.)
- Implement proper authentication with JWT tokens
- Add input validation and sanitization
- Add rate limiting
- Add logging
- Add error handling middleware