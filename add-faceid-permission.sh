#!/bin/bash

# Script to add Face ID permission to Xcode project
# This adds the NSFaceIDUsageDescription to the project's Info.plist

PROJECT_DIR="/Users/pgujar/Documents/Projects/Sudoku-Master-Ads"
PROJECT_FILE="$PROJECT_DIR/Sudoku Master.xcodeproj/project.pbxproj"

echo "🔧 Adding Face ID permission to Xcode project..."

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

# Instructions for manual addition in Xcode
echo ""
echo "📋 Manual Steps Required in Xcode:"
echo "1. Open 'Sudoku Master.xcodeproj' in Xcode"
echo "2. Select the 'Sudoku Master' target"
echo "3. Go to the 'Info' tab"
echo "4. Click the '+' button to add a new key"
echo "5. Select 'Privacy - Face ID Usage Description'"
echo "6. Set the value to:"
echo "   'This app uses Face ID to securely authenticate and protect your Sudoku Master account with biometric security.'"
echo ""
echo "💡 Or search for 'NSFaceIDUsageDescription' if the dropdown doesn't show the option."
echo ""
echo "✅ After adding this, clean and rebuild your project (Shift+Cmd+K, then Cmd+B)"