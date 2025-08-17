#!/bin/bash

# Comprehensive build fix for Sudoku Master
# Resolves GoogleMobileAds, FBAudienceNetwork, and PromisesSwift module issues

set -e

echo "🔧 Running comprehensive build fix for Sudoku Master..."

# 1. Clean everything
echo "🧹 Cleaning all build artifacts..."
cd "/Users/pgujar/Documents/Projects/Sudoku-Master-Ads"
rm -rf ~/Library/Developer/Xcode/DerivedData/Sudoku_Master-* 2>/dev/null || true
rm -rf build 2>/dev/null || true

# 2. Clean and reinstall pods
echo "📦 Reinstalling CocoaPods with fixes..."
pod deintegrate 2>/dev/null || true
pod install

# 3. Fix permissions
echo "🔐 Fixing framework permissions..."
find Pods -name "*.framework" -type d -exec chmod -R 755 {} \; 2>/dev/null || true

# 4. Verify key modules
echo "🔍 Verifying key modules..."
if [ ! -f "Pods/Target Support Files/PromisesObjC/PromisesObjC.modulemap" ]; then
    echo "❌ PromisesObjC module map missing"
    exit 1
fi

if [ ! -d "Pods/PromisesSwift" ]; then
    echo "❌ PromisesSwift missing"
    exit 1
fi

if [ ! -d "Pods/Google-Mobile-Ads-SDK" ]; then
    echo "❌ Google-Mobile-Ads-SDK missing"
    exit 1
fi

echo "✅ All modules verified!"

echo "✅ Build fix complete!"
echo ""
echo "Next steps:"
echo "1. Open Sudoku Master.xcworkspace (NOT .xcodeproj)"
echo "2. Product → Clean Build Folder (Shift+Cmd+K)"
echo "3. Build project (Cmd+B)"
echo ""
echo "Key fixes applied:"
echo "- ✅ Disabled sandbox restrictions for FBAudienceNetwork"
echo "- ✅ Added explicit PromisesObjC and PromisesSwift dependencies"
echo "- ✅ Fixed module map paths for FBLPromises"
echo "- ✅ Set proper framework search paths"
echo "- ✅ Fixed permissions on all frameworks"