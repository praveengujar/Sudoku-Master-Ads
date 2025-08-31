import SwiftUI

struct SudokuBoardView: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    @Environment(\.colorScheme) var colorScheme
    
    // Performance optimization: cache computed colors
    private var colors: BoardColors {
        BoardColors(colorScheme: colorScheme)
    }
    
    var body: some View {
        if sudokuStore.isLoading {
            LoadingView()
        } else {
            GameBoardContent(colors: colors)
                .environmentObject(sudokuStore)
        }
    }
}

// MARK: - Performance-Optimized Sub-Views

private struct LoadingView: View {
    var body: some View {
        ProgressView("Loading puzzle...")
            .padding()
    }
}

private struct GameBoardContent: View {
    @EnvironmentObject var sudokuStore: SudokuStore
    let colors: BoardColors
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width, geometry.size.height) / 9
            
            ZStack {
                // Background
                Rectangle()
                    .fill(colors.backgroundColor)
                
                // Grid Lines
                GridLinesView(colors: colors)
                
                // Cells
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                OptimizedSudokuCell(
                                    row: row,
                                    col: col,
                                    colors: colors
                                )
                                .environmentObject(sudokuStore)
                                .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(8)  // Reduced from default padding
        .background(colors.backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 3)
    }
}

// MARK: - Optimized Cell Implementation

private struct OptimizedSudokuCell: View {
    let row: Int
    let col: Int
    let colors: BoardColors
    
    @EnvironmentObject var sudokuStore: SudokuStore
    
    // Performance optimization: memoize expensive computations
    private var cellData: CellData {
        CellData(
            isOriginal: sudokuStore.originalGrid[row][col] != nil,
            isSelected: sudokuStore.selectedCell.row == row && sudokuStore.selectedCell.col == col,
            isHighlighted: calculateHighlight(),
            hasError: sudokuStore.errors[CellPosition(row: row, col: col)] ?? false,
            isHintCell: sudokuStore.hintCell.row == row && sudokuStore.hintCell.col == col,
            cellValue: sudokuStore.grid[row][col],
            hintValue: sudokuStore.hintCell.value
        )
    }
    
    var body: some View {
        CellView(
            cellData: cellData,
            colors: colors,
            onTap: {
                sudokuStore.setSelectedCell(row: row, col: col)
            }
        )
    }
    
    private func calculateHighlight() -> Bool {
        guard let selectedRow = sudokuStore.selectedCell.row,
              let selectedCol = sudokuStore.selectedCell.col else {
            return false
        }
        
        return row == selectedRow || col == selectedCol ||
               (row / 3 == selectedRow / 3 && col / 3 == selectedCol / 3)
    }
}

// MARK: - Data Structures for Performance

private struct CellData: Equatable {
    let isOriginal: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    let hasError: Bool
    let isHintCell: Bool
    let cellValue: Int?
    let hintValue: Int?
}

private struct BoardColors {
    let gridColor: Color
    let backgroundColor: Color
    let selectedBackgroundColor: Color
    let highlightedBackgroundColor: Color
    let thinLineColor: Color
    let thickLineColor: Color
    
    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            gridColor = Color.white.opacity(0.3)
            backgroundColor = Color.black.opacity(0.05)
            selectedBackgroundColor = Color.blue.opacity(0.4)
            highlightedBackgroundColor = Color.blue.opacity(0.15)
            thinLineColor = Color.white.opacity(0.3)
            thickLineColor = Color.white.opacity(0.6)
        } else {
            gridColor = Color.black.opacity(0.3)
            backgroundColor = Color.white
            selectedBackgroundColor = Color.blue.opacity(0.3)
            highlightedBackgroundColor = Color.blue.opacity(0.08)
            thinLineColor = Color.black.opacity(0.3)
            thickLineColor = Color.black.opacity(0.6)
        }
    }
}

// MARK: - Optimized Cell View

private struct CellView: View {
    let cellData: CellData
    let colors: BoardColors
    let onTap: () -> Void
    
    private var backgroundColor: Color {
        if cellData.isSelected {
            return colors.selectedBackgroundColor
        } else if cellData.isHintCell {
            return Color.green.opacity(0.3)
        } else if cellData.isHighlighted {
            return colors.highlightedBackgroundColor
        } else {
            return Color.clear
        }
    }
    
    private var textColor: Color {
        if cellData.hasError {
            return .red
        } else if cellData.isOriginal {
            return .primary
        } else if cellData.isHintCell && cellData.hintValue != nil {
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
                .animation(.easeInOut(duration: 0.15), value: backgroundColor)
            
            // Number display
            NumberDisplayView(
                cellValue: cellData.cellValue,
                hintValue: cellData.isHintCell ? cellData.hintValue : nil,
                isOriginal: cellData.isOriginal,
                textColor: textColor
            )
            
            // Error indicator
            if cellData.hasError {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.red, lineWidth: 2)
                    .padding(1)
                    .animation(.easeInOut(duration: 0.2), value: cellData.hasError)
            }
            
            // Selection indicator
            if cellData.isSelected {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.blue, lineWidth: 3)
                    .padding(1)
                    .animation(.easeInOut(duration: 0.15), value: cellData.isSelected)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Haptic feedback for better UX
            HapticManager.shared.lightImpactOccurred()
            onTap()
        }
    }
}

// MARK: - Number Display Component

private struct NumberDisplayView: View {
    let cellValue: Int?
    let hintValue: Int?
    let isOriginal: Bool
    let textColor: Color
    
    var body: some View {
        Group {
            if let value = cellValue {
                Text("\(value)")
                    .font(.system(size: 20, weight: isOriginal ? .bold : .regular, design: .default))
                    .foregroundColor(textColor)
                    .transition(.scale.combined(with: .opacity))
            } else if let hintValue = hintValue {
                Text("\(hintValue)")
                    .font(.system(size: 20, weight: .regular, design: .default))
                    .foregroundColor(textColor)
                    .opacity(0.7)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cellValue)
        .animation(.easeInOut(duration: 0.2), value: hintValue)
    }
}

// MARK: - Optimized Grid Lines

private struct GridLinesView: View {
    let colors: BoardColors
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw thin lines
                for index in 1..<9 where index % 3 != 0 {
                    // Horizontal thin lines
                    let y = size.height * CGFloat(index) / 9.0
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        },
                        with: .color(colors.thinLineColor),
                        lineWidth: 1
                    )
                    
                    // Vertical thin lines
                    let x = size.width * CGFloat(index) / 9.0
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(colors.thinLineColor),
                        lineWidth: 1
                    )
                }
                
                // Draw thick lines
                for index in 0..<4 {
                    // Horizontal thick lines
                    let y = size.height * CGFloat(index * 3) / 9.0
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        },
                        with: .color(colors.thickLineColor),
                        lineWidth: 2
                    )
                    
                    // Vertical thick lines
                    let x = size.width * CGFloat(index * 3) / 9.0
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(colors.thickLineColor),
                        lineWidth: 2
                    )
                }
            }
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct SudokuBoardView_Previews: PreviewProvider {
    static var previews: some View {
        SudokuBoardView()
            .environmentObject(SudokuStore())
    }
}
#endif