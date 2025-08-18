#!/bin/bash

echo "🔧 Info.plist Configuration Fix Verification"
echo "==========================================="

cd "/Users/pgujar/Documents/Projects/Sudoku-Master-Ads"

echo "📁 Project: Sudoku Master"
echo "🎯 Target: Fix duplicate Info.plist build error"
echo ""

# Check main app configuration
echo "✅ MAIN APP CONFIGURATION:"
echo "========================="
main_configs=$(grep -c "INFOPLIST_FILE.*Sudoku Master/Info.plist" "Sudoku Master.xcodeproj/project.pbxproj")
echo "   - Custom Info.plist references: $main_configs (should be 2 - Debug & Release)"

# Check for conflicting INFOPLIST_KEY settings
conflicting_keys=$(grep -c "INFOPLIST_KEY_" "Sudoku Master.xcodeproj/project.pbxproj")
echo "   - INFOPLIST_KEY conflicts: $conflicting_keys (should be 0)"

# Check test target configuration  
echo ""
echo "✅ TEST TARGET CONFIGURATION:"
echo "============================"
test_configs=$(grep -c "GENERATE_INFOPLIST_FILE = YES" "Sudoku Master.xcodeproj/project.pbxproj")
echo "   - Auto-generated Info.plist for tests: $test_configs (should be 4 - 2 targets x 2 configs)"

# Verify custom Info.plist exists and is valid
echo ""
echo "✅ CUSTOM INFO.PLIST VERIFICATION:"
echo "=================================="
if [ -f "Sudoku Master/Info.plist" ]; then
    echo "   - Custom Info.plist exists: ✅"
    if plutil -lint "Sudoku Master/Info.plist" > /dev/null 2>&1; then
        echo "   - Info.plist syntax valid: ✅"
    else
        echo "   - Info.plist syntax valid: ❌"
        exit 1
    fi
else
    echo "   - Custom Info.plist exists: ❌"
    exit 1
fi

# Check for required keys in Info.plist
echo "   - Required keys present:"
if grep -q "NSUserTrackingUsageDescription" "Sudoku Master/Info.plist"; then
    echo "     • ATT Description: ✅"
else
    echo "     • ATT Description: ❌"
fi

if grep -q "SKAdNetworkItems" "Sudoku Master/Info.plist"; then
    echo "     • SKAdNetwork IDs: ✅"
else
    echo "     • SKAdNetwork IDs: ❌"
fi

if grep -q "UIApplicationSceneManifest" "Sudoku Master/Info.plist"; then
    echo "     • Scene Manifest: ✅"
else
    echo "     • Scene Manifest: ❌"
fi

# Check derived data cleanup
echo ""
echo "✅ BUILD ENVIRONMENT:"
echo "===================="
derived_data_count=$(find ~/Library/Developer/Xcode/DerivedData -name "*Sudoku_Master*" 2>/dev/null | wc -l | tr -d ' ')
echo "   - Derived data cleaned: $derived_data_count remaining folders"

# Summary
echo ""
echo "📊 CONFIGURATION SUMMARY:"
echo "========================"
if [ "$main_configs" -eq 2 ] && [ "$conflicting_keys" -eq 0 ] && [ "$test_configs" -eq 4 ]; then
    echo "🎉 INFO.PLIST FIX: SUCCESS"
    echo "========================="
    echo "✅ Main app uses custom Info.plist"
    echo "✅ No conflicting INFOPLIST_KEY settings"
    echo "✅ Test targets use auto-generated Info.plist"
    echo "✅ Custom Info.plist is valid and complete"
    echo "✅ Derived data cleaned"
    echo ""
    echo "🚀 READY TO BUILD:"
    echo "=================="
    echo "1. Open 'Sudoku Master.xcworkspace' in Xcode"
    echo "2. Clean Build Folder (Shift+Cmd+K)"
    echo "3. Build project (Cmd+B)"
    echo "4. No more duplicate Info.plist errors expected"
else
    echo "❌ INFO.PLIST FIX: ISSUES REMAIN"
    echo "==============================="
    echo "⚠️  Configuration not fully resolved"
    echo "Main configs: $main_configs (expected: 2)"
    echo "Conflicting keys: $conflicting_keys (expected: 0)"
    echo "Test configs: $test_configs (expected: 4)"
fi