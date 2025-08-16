# Info.plist Configuration for Ad Networks

## Required Info.plist Entries

Add the following entries to your `Info.plist` file or configure them in Xcode's target settings under "Info":

### **1. Google AdMob Configuration**

```xml
<!-- Google AdMob App ID - Replace with your actual App ID -->
<key>GADApplicationIdentifier</key>
<string>YOUR_ADMOB_APP_ID</string>

<!-- AdMob delay measurement for better performance -->
<key>GADDelayAppMeasurementInit</key>
<true/>

<!-- SKAdNetwork IDs for iOS 14+ attribution -->
<key>SKAdNetworkItems</key>
<array>
    <!-- Google -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>4fzdc2evr5.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>2fnua5tdw4.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>ydx93a7ass.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>5a6flpkh64.skadnetwork</string>
    </dict>
    <!-- Meta/Facebook -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>v9wttpbfk9.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>n38lu8286q.skadnetwork</string>
    </dict>
    <!-- TikTok -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>22mmun2rn5.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>238da6jt44.skadnetwork</string>
    </dict>
    <!-- Add more as needed -->
</array>
```

### **2. App Tracking Transparency (ATT)**

```xml
<!-- App Tracking Transparency usage description -->
<key>NSUserTrackingUsageDescription</key>
<string>This app uses tracking to provide personalized ads and improve your gaming experience. Your privacy is important to us.</string>
```

### **3. TikTok Audience Network Configuration**

```xml
<!-- TikTok App ID -->
<key>TikTokAppID</key>
<string>YOUR_TIKTOK_CLIENT_KEY</string>

<!-- URL Schemes for TikTok -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>tiktok</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>ttYOUR_TIKTOK_CLIENT_KEY</string>
        </array>
    </dict>
</array>

<!-- LSApplicationQueriesSchemes for TikTok -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktokopensdk</string>
    <string>tiktoksharesdk</string>
    <string>snssdk1233</string>
    <string>snssdk1180</string>
</array>
```

### **4. Privacy Manifests (iOS 17+)**

```xml
<!-- Privacy tracking domains -->
<key>NSPrivacyTrackingDomains</key>
<array>
    <string>googleadservices.com</string>
    <string>googlesyndication.com</string>
    <string>facebook.com</string>
    <string>bytedance.com</string>
</array>

<!-- Privacy collected data types -->
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeDeviceID</string>
        <key>NSPrivacyCollectedDataTypeLinked</key>
        <false/>
        <key>NSPrivacyCollectedDataTypeTracking</key>
        <true/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array>
            <string>NSPrivacyCollectedDataTypePurposeAdvertising</string>
        </array>
    </dict>
</array>
```

### **5. Photo Library Usage (if needed for TikTok sharing)**

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to save screenshots of your completed puzzles.</string>
```

## **Configuration Steps:**

1. **In Xcode**: Open your project → Select target → Go to "Info" tab
2. **Add entries**: Click "+" to add new entries with the keys and values above
3. **Replace placeholders**: 
   - `YOUR_ADMOB_APP_ID` → Your actual AdMob App ID
   - `YOUR_TIKTOK_CLIENT_KEY` → Your actual TikTok Client Key
4. **Validate**: Ensure all entries are correctly typed and formatted

## **Important Notes:**

- **Test Mode**: During development, use test ad unit IDs
- **Privacy**: Update privacy policy to reflect data collection
- **SKAdNetwork**: Keep the list updated as networks add new IDs
- **App Store**: Review guidelines for ad content and user experience