const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = process.env.PORT || 8080;

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'sudoku-master-secret-key-2025';
const JWT_ACCESS_EXPIRY = process.env.JWT_ACCESS_EXPIRY || '15m'; // 15 minutes
const JWT_REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '7d'; // 7 days

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage (replace with database in production)
let users = [];
let gameProgress = [];
let userStats = [];
let refreshTokens = []; // Store valid refresh tokens

// JWT Helper Functions
function generateAccessToken(user) {
  return jwt.sign(
    { 
      id: user.id, 
      username: user.username,
      type: 'access' 
    }, 
    JWT_SECRET, 
    { expiresIn: JWT_ACCESS_EXPIRY }
  );
}

function generateRefreshToken(user) {
  return jwt.sign(
    { 
      id: user.id, 
      username: user.username,
      type: 'refresh' 
    }, 
    JWT_SECRET, 
    { expiresIn: JWT_REFRESH_EXPIRY }
  );
}

function verifyToken(token, tokenType = 'access') {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.type !== tokenType) {
      throw new Error('Invalid token type');
    }
    return decoded;
  } catch (error) {
    throw new Error('Invalid or expired token');
  }
}

// JWT Authentication Middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const user = verifyToken(token, 'access');
    req.user = user;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired access token' });
  }
}

// Password hashing helpers
async function hashPassword(password) {
  return await bcrypt.hash(password, 12);
}

async function comparePassword(password, hashedPassword) {
  return await bcrypt.compare(password, hashedPassword);
}

// Helper function to generate Sudoku puzzle
function generateSudokuPuzzle(difficulty) {
  console.log(`🎯 Server generating puzzle for difficulty: ${difficulty}`);
  
  // Complete solution grid
  const solution = [
    [5, 3, 4, 6, 7, 8, 9, 1, 2],
    [6, 7, 2, 1, 9, 5, 3, 4, 8],
    [1, 9, 8, 3, 4, 2, 5, 6, 7],
    [8, 5, 9, 7, 6, 1, 4, 2, 3],
    [4, 2, 6, 8, 5, 3, 7, 9, 1],
    [7, 1, 3, 9, 2, 4, 8, 5, 6],
    [9, 6, 1, 5, 3, 7, 2, 8, 4],
    [2, 8, 7, 4, 1, 9, 6, 3, 5],
    [3, 4, 5, 2, 8, 6, 1, 7, 9]
  ];

  // Create empty grid
  let puzzle = Array(9).fill(null).map(() => Array(9).fill(null));
  
  // Define difficulty-based positions to fill
  let positions;
  
  if (difficulty === 'easy') {
    // Easy: 45-50 filled cells (more clues)
    positions = [
      [0,0], [0,1], [0,2], [0,4], [0,6], [0,7],
      [1,0], [1,2], [1,3], [1,4], [1,5], [1,7], [1,8],
      [2,0], [2,1], [2,3], [2,5], [2,7], [2,8],
      [3,0], [3,2], [3,4], [3,6], [3,8],
      [4,0], [4,2], [4,3], [4,5], [4,6], [4,8],
      [5,0], [5,2], [5,4], [5,6], [5,8],
      [6,0], [6,1], [6,3], [6,5], [6,7], [6,8],
      [7,0], [7,2], [7,3], [7,4], [7,5], [7,7], [7,8],
      [8,0], [8,1], [8,2], [8,4], [8,6], [8,7], [8,8]
    ];
  } else if (difficulty === 'medium') {
    // Medium: 35-40 filled cells (moderate clues)
    positions = [
      [0,0], [0,2], [0,4], [0,7],
      [1,0], [1,3], [1,5], [1,8],
      [2,1], [2,3], [2,5], [2,7],
      [3,0], [3,4], [3,8],
      [4,2], [4,3], [4,5], [4,6],
      [5,0], [5,4], [5,8],
      [6,1], [6,3], [6,5], [6,7],
      [7,0], [7,3], [7,5], [7,8],
      [8,1], [8,4], [8,6], [8,8],
      [2,0], [3,2], [4,0], [4,8], [5,2], [6,0], [7,1]
    ];
  } else { // hard
    // Hard: 25-30 filled cells (fewer clues)
    positions = [
      [0,0], [0,4], [0,8],
      [1,2], [1,6],
      [2,1], [2,7],
      [3,0], [3,8],
      [4,3], [4,5],
      [5,0], [5,8],
      [6,1], [6,7],
      [7,2], [7,6],
      [8,0], [8,4], [8,8],
      [1,0], [3,4], [4,1], [4,7], [5,4], [7,8]
    ];
  }
  
  // Fill the puzzle with solution values at specified positions
  positions.forEach(([row, col]) => {
    puzzle[row][col] = solution[row][col];
  });
  
  const filledCells = puzzle.flat().filter(cell => cell !== null).length;
  console.log(`🎯 Server created puzzle with ${filledCells} filled cells for ${difficulty}`);

  return {
    id: Math.floor(Math.random() * 10000),
    grid: puzzle,
    solution: solution,
    difficulty: difficulty
  };
}

// Helper function to validate Sudoku move
function validateMove(grid, row, col, value) {
  // Check row
  for (let c = 0; c < 9; c++) {
    if (c !== col && grid[row][c] === value) {
      return false;
    }
  }

  // Check column
  for (let r = 0; r < 9; r++) {
    if (r !== row && grid[r][col] === value) {
      return false;
    }
  }

  // Check 3x3 box
  const boxRow = Math.floor(row / 3) * 3;
  const boxCol = Math.floor(col / 3) * 3;
  
  for (let r = boxRow; r < boxRow + 3; r++) {
    for (let c = boxCol; c < boxCol + 3; c++) {
      if (r !== row && c !== col && grid[r][c] === value) {
        return false;
      }
    }
  }

  return true;
}

// Helper function to solve Sudoku using backtracking
function solveSudoku(grid) {
  const solution = JSON.parse(JSON.stringify(grid));
  
  function isValid(row, col, num) {
    // Check row
    for (let c = 0; c < 9; c++) {
      if (solution[row][c] === num) return false;
    }
    
    // Check column
    for (let r = 0; r < 9; r++) {
      if (solution[r][col] === num) return false;
    }
    
    // Check 3x3 box
    const boxRow = Math.floor(row / 3) * 3;
    const boxCol = Math.floor(col / 3) * 3;
    
    for (let r = boxRow; r < boxRow + 3; r++) {
      for (let c = boxCol; c < boxCol + 3; c++) {
        if (solution[r][c] === num) return false;
      }
    }
    
    return true;
  }
  
  function solve() {
    for (let row = 0; row < 9; row++) {
      for (let col = 0; col < 9; col++) {
        if (solution[row][col] === null) {
          for (let num = 1; num <= 9; num++) {
            if (isValid(row, col, num)) {
              solution[row][col] = num;
              
              if (solve()) {
                return true;
              }
              
              solution[row][col] = null;
            }
          }
          return false;
        }
      }
    }
    return true;
  }
  
  if (solve()) {
    return solution;
  } else {
    return []; // No solution found
  }
}

// Routes

// Health check
app.get('/api', (req, res) => {
  res.json({ message: 'Sudoku Master API is running!' });
});

// Authentication endpoints
app.post('/api/users/register', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    // Check if user already exists
    if (users.find(u => u.username === username)) {
      return res.status(400).json({ error: 'Username already exists' });
    }

    // Hash the password
    const hashedPassword = await hashPassword(password);

    const newUser = {
      id: users.length + 1,
      username: username,
      theme: 'default'
    };

    users.push({ ...newUser, password: hashedPassword });
    
    // Initialize user stats
    userStats.push({
      id: userStats.length + 1,
      userId: newUser.id,
      eloRating: 1200,
      gamesPlayed: 0,
      gamesWon: 0,
      averageTimeSeconds: 0
    });

    // Generate JWT tokens
    const accessToken = generateAccessToken(newUser);
    const refreshToken = generateRefreshToken(newUser);
    
    // Store refresh token
    refreshTokens.push({
      token: refreshToken,
      userId: newUser.id,
      createdAt: new Date()
    });

    console.log(`✅ User registered: ${username}`);

    res.json({
      user: newUser,
      accessToken,
      refreshToken,
      expiresIn: JWT_ACCESS_EXPIRY
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

app.post('/api/users/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }
    
    const user = users.find(u => u.username === username);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Compare password with hashed password
    const isPasswordValid = await comparePassword(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT tokens
    const { password: _, ...userWithoutPassword } = user;
    const accessToken = generateAccessToken(userWithoutPassword);
    const refreshToken = generateRefreshToken(userWithoutPassword);
    
    // Store refresh token
    refreshTokens.push({
      token: refreshToken,
      userId: user.id,
      createdAt: new Date()
    });

    console.log(`✅ User logged in: ${username}`);

    res.json({
      user: userWithoutPassword,
      accessToken,
      refreshToken,
      expiresIn: JWT_ACCESS_EXPIRY
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Token refresh endpoint
app.post('/api/users/refresh', (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      return res.status(401).json({ error: 'Refresh token required' });
    }

    // Check if refresh token exists in our storage
    const storedToken = refreshTokens.find(t => t.token === refreshToken);
    if (!storedToken) {
      return res.status(403).json({ error: 'Invalid refresh token' });
    }

    // Verify the refresh token
    const decoded = verifyToken(refreshToken, 'refresh');
    
    // Find the user
    const user = users.find(u => u.id === decoded.id);
    if (!user) {
      return res.status(403).json({ error: 'User not found' });
    }

    // Generate new access token
    const { password: _, ...userWithoutPassword } = user;
    const newAccessToken = generateAccessToken(userWithoutPassword);

    console.log(`🔄 Token refreshed for user: ${user.username}`);

    res.json({
      accessToken: newAccessToken,
      expiresIn: JWT_ACCESS_EXPIRY
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(403).json({ error: 'Invalid or expired refresh token' });
  }
});

app.get('/api/users/me', authenticateToken, (req, res) => {
  try {
    const user = users.find(u => u.id === req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const { password: _, ...userWithoutPassword } = user;
    res.json(userWithoutPassword);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to get user information' });
  }
});

app.post('/api/users/logout', (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    if (refreshToken) {
      // Remove refresh token from storage
      refreshTokens = refreshTokens.filter(t => t.token !== refreshToken);
      console.log('🔓 User logged out and refresh token removed');
    }
    
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    console.error('Logout error:', error);
    res.json({ message: 'Logged out successfully' }); // Always succeed logout
  }
});

// Password reset endpoint
app.post('/api/users/reset-password', async (req, res) => {
  try {
    const { username } = req.body;
    
    if (!username) {
      return res.status(400).json({ error: 'Username is required' });
    }
    
    // Find user by username
    const userIndex = users.findIndex(u => u.username === username);
    if (userIndex === -1) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Generate a temporary password
    const tempPassword = 'temp' + Math.random().toString(36).substring(2, 10);
    
    // Hash the temporary password
    const hashedTempPassword = await hashPassword(tempPassword);
    
    // Update user's password
    users[userIndex].password = hashedTempPassword;
    
    // Invalidate all existing refresh tokens for this user
    refreshTokens = refreshTokens.filter(t => t.userId !== users[userIndex].id);
    
    console.log(`🔑 Password reset for user: ${username}, temp password: ${tempPassword}`);
    
    res.json({
      message: 'Password reset successful',
      temporaryPassword: tempPassword,
      instructions: 'Use this temporary password to log in, then change it immediately for security.'
    });
    
  } catch (error) {
    console.error('Password reset error:', error);
    res.status(500).json({ error: 'Password reset failed' });
  }
});

// Sudoku game endpoints
app.get('/api/sudoku/generate', (req, res) => {
  const difficulty = req.query.difficulty || 'easy';
  
  if (!['easy', 'medium', 'hard'].includes(difficulty)) {
    return res.status(400).json({ error: 'Invalid difficulty level' });
  }

  const puzzle = generateSudokuPuzzle(difficulty);
  res.json(puzzle);
});

app.post('/api/sudoku/validate', (req, res) => {
  const { grid, row, col, value } = req.body;
  
  if (!grid || row === undefined || col === undefined || value === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const isValid = validateMove(grid, row, col, value);
  res.json({ isValid });
});

app.post('/api/sudoku/solve', (req, res) => {
  const { grid } = req.body;
  
  if (!grid) {
    return res.status(400).json({ error: 'Grid is required' });
  }

  const solution = solveSudoku(grid);
  res.json({ solution });
});

app.post('/api/sudoku/save-progress', authenticateToken, (req, res) => {
  try {
    const { puzzleId, currentGrid, isCompleted, timeSpentSeconds } = req.body;
    const userId = req.user.id; // Get userId from JWT token
    
    const progress = {
      id: gameProgress.length + 1,
      userId,
      puzzleId,
      currentGrid,
      isCompleted,
      timeSpentSeconds,
      createdAt: new Date().toISOString()
    };

    gameProgress.push(progress);
    
    // Update user stats if completed
    if (isCompleted) {
      const stats = userStats.find(s => s.userId === userId);
      if (stats) {
        stats.gamesPlayed += 1;
        stats.gamesWon += 1;
        stats.averageTimeSeconds = Math.round(
          (stats.averageTimeSeconds * (stats.gamesPlayed - 1) + timeSpentSeconds) / stats.gamesPlayed
        );
      }
    }

    console.log(`💾 Progress saved for user ${req.user.username}: ${isCompleted ? 'completed' : 'in progress'}`);
    res.json(progress);
  } catch (error) {
    console.error('Save progress error:', error);
    res.status(500).json({ error: 'Failed to save progress' });
  }
});

app.get('/api/sudoku/user-stats/:userId', authenticateToken, (req, res) => {
  try {
    const userId = parseInt(req.params.userId);
    
    // Ensure user can only access their own stats
    if (userId !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    const stats = userStats.find(s => s.userId === userId);
    
    if (!stats) {
      return res.status(404).json({ error: 'User stats not found' });
    }

    res.json(stats);
  } catch (error) {
    console.error('Get user stats error:', error);
    res.status(500).json({ error: 'Failed to get user stats' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Sudoku Master API server running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api`);
});