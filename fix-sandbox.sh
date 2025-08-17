#!/bin/bash

# Fix sandbox issues with FBAudienceNetwork and other frameworks
# Run this script to resolve build sandbox errors

set -e

echo "🔧 Fixing sandbox issues for Sudoku Master..."

# 1. Clean derived data
echo "📦 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Sudoku_Master-* 2>/dev/null || true

# 2. Clean build folder in project
echo "🧹 Cleaning build artifacts..."
cd "/Users/pgujar/Documents/Projects/Sudoku-Master-Ads"
rm -rf build 2>/dev/null || true

# 3. Reinstall pods
echo "📲 Reinstalling CocoaPods..."
pod deintegrate 2>/dev/null || true
pod install

# 4. Fix permissions on frameworks
echo "🔐 Fixing framework permissions..."
find Pods -name "*.framework" -type d -exec chmod -R 755 {} \; 2>/dev/null || true

echo "✅ Sandbox fixes applied!"
echo ""
echo "Next steps:"
echo "1. Open Sudoku Master.xcworkspace (NOT .xcodeproj)"
echo "2. Product → Clean Build Folder (Shift+Cmd+K)"
echo "3. Build project (Cmd+B)"
echo ""
echo "If you still see sandbox errors:"
echo "1. Xcode → Settings → Locations → Derived Data"
echo "2. Click the arrow and delete the folder"
echo "3. Restart Xcode and rebuild"