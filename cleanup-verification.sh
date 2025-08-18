#!/bin/bash

# Comprehensive cleanup verification script for Meta-only integration

echo "🧹 Comprehensive Ad Network Cleanup Verification"
echo "==============================================="

cd "/Users/pgujar/Documents/Projects/Sudoku-Master-Ads"

# Function to check and report
check_clean() {
    local description="$1"
    local command="$2"
    local expected_result="$3"
    
    echo -n "Checking $description... "
    
    if eval "$command" > /dev/null 2>&1; then
        if [ "$expected_result" = "should_be_empty" ]; then
            echo "❌ FOUND REMNANTS"
            return 1
        else
            echo "✅ FOUND AS EXPECTED"
            return 0
        fi
    else
        if [ "$expected_result" = "should_be_empty" ]; then
            echo "✅ CLEAN"
            return 0
        else
            echo "❌ NOT FOUND"
            return 1
        fi
    fi
}

echo ""
echo "🔍 GOOGLE ADMOB CLEANUP VERIFICATION"
echo "====================================="

# Check for Google AdMob imports
check_clean "Google AdMob imports in Swift files" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l "import GoogleMobileAds" {} \;' \
    "should_be_empty"

# Check for GAD* references
check_clean "GAD* class references" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l "GADBanner\|GADInterstitial\|GADRewarded\|GADMobileAds" {} \;' \
    "should_be_empty"

# Check for AdMob configuration
check_clean "AdMob configuration in Info.plist" \
    'grep -i "GADApplicationIdentifier\|admob" "Sudoku Master/Info.plist"' \
    "should_be_empty"

# Check for Google User Messaging Platform
check_clean "Google User Messaging Platform imports" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l "GoogleUserMessagingPlatform\|UMP" {} \;' \
    "should_be_empty"

echo ""
echo "🔍 TIKTOK ADS CLEANUP VERIFICATION"
echo "=================================="

# Check for TikTok imports
check_clean "TikTok/ByteDance imports" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l -i "tiktok\|bytedance\|adsGlobal" {} \;' \
    "should_be_empty"

# Check for BU* references (TikTok SDK classes)
check_clean "TikTok BU* class references" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l "BUReward\|BUInterstitial\|BUBanner" {} \;' \
    "should_be_empty"

# Check for TikTok configuration
check_clean "TikTok configuration in Info.plist" \
    'grep -i "tiktok\|bytedance" "Sudoku Master/Info.plist"' \
    "should_be_empty"

echo ""
echo "✅ META AUDIENCE NETWORK VERIFICATION"
echo "====================================="

# Check for Meta imports (should exist)
check_clean "Meta Audience Network imports" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l "import FBAudienceNetwork" {} \;' \
    "should_exist"

# Check for FB* class usage (should exist)
check_clean "Meta FB* class references" \
    'find "Sudoku Master" -name "*.swift" -exec grep -l "FB[A-Z]" {} \;' \
    "should_exist"

# Check for Meta configuration in Info.plist (should exist)
check_clean "Meta SKAdNetwork configuration" \
    'grep -A 1 "v9wttpbfk9.skadnetwork" "Sudoku Master/Info.plist"' \
    "should_exist"

echo ""
echo "🔍 PODFILE VERIFICATION"
echo "======================"

# Check Podfile is clean
echo -n "Checking Podfile for Google/TikTok references... "
if grep -i "google-mobile-ads\|googleusermessagingplatform\|ads-global\|tiktok" Podfile > /dev/null 2>&1; then
    echo "❌ FOUND OLD REFERENCES"
else
    echo "✅ CLEAN"
fi

echo -n "Checking Podfile for Meta reference... "
if grep -i "FBAudienceNetwork" Podfile > /dev/null 2>&1; then
    echo "✅ META FOUND"
else
    echo "❌ META MISSING"
fi

echo ""
echo "🔍 PODS DIRECTORY VERIFICATION"
echo "=============================="

echo -n "Checking for Google AdMob SDK in Pods... "
if [ -d "Pods/Google-Mobile-Ads-SDK" ]; then
    echo "❌ STILL PRESENT"
else
    echo "✅ REMOVED"
fi

echo -n "Checking for Google User Messaging Platform in Pods... "
if [ -d "Pods/GoogleUserMessagingPlatform" ]; then
    echo "❌ STILL PRESENT"
else
    echo "✅ REMOVED"
fi

echo -n "Checking for TikTok SDK in Pods... "
if [ -d "Pods/Ads-Global" ]; then
    echo "❌ STILL PRESENT"
else
    echo "✅ REMOVED"
fi

echo -n "Checking for Meta Audience Network in Pods... "
if [ -d "Pods/FBAudienceNetwork" ]; then
    echo "✅ PRESENT"
else
    echo "❌ MISSING"
fi

echo ""
echo "🔍 PROJECT CONFIGURATION VERIFICATION"
echo "====================================="

echo -n "Checking workspace exists... "
if [ -d "Sudoku Master.xcworkspace" ]; then
    echo "✅ PRESENT"
else
    echo "❌ MISSING"
fi

echo -n "Checking custom Info.plist configuration... "
if grep -q "INFOPLIST_FILE.*Sudoku Master/Info.plist" "Sudoku Master.xcodeproj/project.pbxproj"; then
    echo "✅ CONFIGURED"
else
    echo "❌ NOT CONFIGURED"
fi

echo ""
echo "📊 FINAL CLEANUP SUMMARY"
echo "========================"

# Count files with imports
meta_files=$(find "Sudoku Master" -name "*.swift" -exec grep -l "FBAudienceNetwork" {} \; | wc -l | tr -d ' ')
google_files=$(find "Sudoku Master" -name "*.swift" -exec grep -l "GoogleMobileAds\|GoogleUserMessagingPlatform" {} \; | wc -l | tr -d ' ')
tiktok_files=$(find "Sudoku Master" -name "*.swift" -exec grep -l -i "tiktok\|bytedance\|ads-global" {} \; | wc -l | tr -d ' ')

echo "📁 Swift Files Analysis:"
echo "   - Meta Audience Network imports: $meta_files files"
echo "   - Google AdMob imports: $google_files files"
echo "   - TikTok imports: $tiktok_files files"

echo ""
echo "📋 Dependencies in Podfile.lock:"
grep -E "FBAudienceNetwork|Google-Mobile-Ads|GoogleUserMessagingPlatform|Ads-Global" Podfile.lock | sed 's/^/   - /' || echo "   - Only Meta and Firebase dependencies found"

echo ""
if [ "$google_files" -eq 0 ] && [ "$tiktok_files" -eq 0 ] && [ "$meta_files" -gt 0 ]; then
    echo "🎉 CLEANUP VERIFICATION: SUCCESS"
    echo "================================"
    echo "✅ All Google AdMob references removed"
    echo "✅ All TikTok references removed"
    echo "✅ Meta Audience Network properly integrated"
    echo "✅ Project ready for simplified Meta-only build"
else
    echo "❌ CLEANUP VERIFICATION: ISSUES FOUND"
    echo "====================================="
    echo "⚠️  Manual review required for remaining references"
fi