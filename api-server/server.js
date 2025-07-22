const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage (replace with database in production)
let users = [];
let gameProgress = [];
let userStats = [];

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
app.post('/api/users/register', (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  // Check if user already exists
  if (users.find(u => u.username === username)) {
    return res.status(400).json({ error: 'Username already exists' });
  }

  const newUser = {
    id: users.length + 1,
    username: username,
    theme: 'default'
  };

  users.push({ ...newUser, password });
  
  // Initialize user stats
  userStats.push({
    id: userStats.length + 1,
    userId: newUser.id,
    eloRating: 1200,
    gamesPlayed: 0,
    gamesWon: 0,
    averageTimeSeconds: 0
  });

  res.json(newUser);
});

app.post('/api/users/login', (req, res) => {
  const { username, password } = req.body;
  
  const user = users.find(u => u.username === username && u.password === password);
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const { password: _, ...userWithoutPassword } = user;
  res.json(userWithoutPassword);
});

app.get('/api/users/me', (req, res) => {
  // For simplicity, return the first user or a default user
  if (users.length > 0) {
    const { password: _, ...userWithoutPassword } = users[0];
    res.json(userWithoutPassword);
  } else {
    res.status(401).json({ error: 'Not authenticated' });
  }
});

app.post('/api/users/logout', (req, res) => {
  res.json({ message: 'Logged out successfully' });
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

app.post('/api/sudoku/save-progress', (req, res) => {
  const { userId, puzzleId, currentGrid, isCompleted, timeSpentSeconds } = req.body;
  
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

  res.json(progress);
});

app.get('/api/sudoku/user-stats/:userId', (req, res) => {
  const userId = parseInt(req.params.userId);
  const stats = userStats.find(s => s.userId === userId);
  
  if (!stats) {
    return res.status(404).json({ error: 'User stats not found' });
  }

  res.json(stats);
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Sudoku Master API server running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api`);
});