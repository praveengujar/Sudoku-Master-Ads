import SwiftUI

struct SudokuBoardView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @Environment(\.colorScheme) var colorScheme
    
    // Calculated colors
    var gridColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
    }
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.05) : Color.white
    }
    
    var selectedBackgroundColor: Color {
        colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if sudokuStore.isLoading {
                ProgressView("Loading puzzle...")
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(0..<9) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9) { col in
                                SudokuCell(row: row, col: col)
                            }
                        }
                    }
                }
                .overlay(
                    // Grid lines
                    GridLines()
                )
                .aspectRatio(1, contentMode: .fit)
                .padding()
                .background(backgroundColor)
                .cornerRadius(8)
                .shadow(radius: 3)
            }
            
            // Timer display
            HStack {
                Image(systemName: "clock")
                Text(formatTime(sudokuStore.timeSpentSeconds))
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(.top, 8)
        }
    }
    
    // Format seconds to mm:ss
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// Individual cell in the Sudoku grid
struct SudokuCell: View {
    let row: Int
    let col: Int
    @EnvironmentObject var sudokuStore: SudokuStore
    @Environment(\.colorScheme) var colorScheme
    
    var isOriginal: Bool {
        sudokuStore.originalGrid[row][col] != nil
    }
    
    var isSelected: Bool {
        sudokuStore.selectedCell.row == row && sudokuStore.selectedCell.col == col
    }
    
    var isHighlighted: Bool {
        let selectedRow = sudokuStore.selectedCell.row
        let selectedCol = sudokuStore.selectedCell.col
        
        if selectedRow == nil || selectedCol == nil {
            return false
        }
        
        // Highlight the same row, column, or 3x3 box as the selected cell
        return row == selectedRow || col == selectedCol ||
               (row / 3 == selectedRow! / 3 && col / 3 == selectedCol! / 3)
    }
    
    var hasError: Bool {
        let position = CellPosition(row: row, col: col)
        return sudokuStore.errors[position] ?? false
    }
    
    var isHintCell: Bool {
        return sudokuStore.hintCell.row == row && sudokuStore.hintCell.col == col
    }
    
    var cellValue: Int? {
        return sudokuStore.grid[row][col]
    }
    
    var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.5)
        } else if isHintCell {
            return Color.green.opacity(0.3)
        } else if isHighlighted {
            return Color.blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    var textColor: Color {
        if hasError {
            return .red
        } else if isOriginal {
            return colorScheme == .dark ? .white : .black
        } else if isHintCell && sudokuStore.hintCell.value != nil {
            return .green
        } else {
            return .blue
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(backgroundColor)
            
            // Number
            if let value = cellValue {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(isOriginal ? .bold : .regular)
                    .foregroundColor(textColor)
            } else if isHintCell, let hintValue = sudokuStore.hintCell.value {
                Text("\(hintValue)")
                    .font(.title2)
                    .foregroundColor(textColor)
                    .opacity(0.7)
            }
            
            // Error indicator
            if hasError {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.red, lineWidth: 2)
                    .padding(1)
            }
            
            // Selection indicator
            if isSelected {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.blue, lineWidth: 3)
                    .padding(1)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            print("Cell tapped at (\(row), \(col))")
            sudokuStore.setSelectedCell(row: row, col: col)
        }
    }
}

// Grid lines for the Sudoku board
struct GridLines: View {
    @Environment(\.colorScheme) var colorScheme
    
    var thinLineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
    }
    
    var thickLineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Thin horizontal lines
                ForEach(1..<9) { index in
                    if index % 3 != 0 {
                        Path { path in
                            let y = geometry.size.height * CGFloat(index) / 9.0
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(thinLineColor, lineWidth: 1)
                    }
                }
                
                // Thin vertical lines
                ForEach(1..<9) { index in
                    if index % 3 != 0 {
                        Path { path in
                            let x = geometry.size.width * CGFloat(index) / 9.0
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                        .stroke(thinLineColor, lineWidth: 1)
                    }
                }
                
                // Thick horizontal lines
                ForEach(0..<4) { index in
                    Path { path in
                        let y = geometry.size.height * CGFloat(index * 3) / 9.0
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(thickLineColor, lineWidth: 2)
                }
                
                // Thick vertical lines
                ForEach(0..<4) { index in
                    Path { path in
                        let x = geometry.size.width * CGFloat(index * 3) / 9.0
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    .stroke(thickLineColor, lineWidth: 2)
                }
            }
        }
    }
}