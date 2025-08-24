import Foundation
import SwiftUI
import LocalAuthentication

// MARK: - LABiometryType Extension

extension LABiometryType {
    var iconName: String {
        switch self {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "person.badge.key"
        }
    }
}

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isGuestMode = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var biometricEnabled = false
    @Published var biometricType: LABiometryType = .none
    
    private let keychainManager = KeychainManager.shared
    
    // Prevent multiple simultaneous authentication attempts
    private var isAuthenticating = false
    private var lastAuthAttempt: Date?
    
    init() {
        setupBiometrics()
        checkExistingUser()
    }
    
    private func setupBiometrics() {
        biometricType = keychainManager.getBiometricType()
        do {
            biometricEnabled = try keychainManager.getBiometricEnabled()
        } catch {
            biometricEnabled = false
        }
    }
    
    func checkExistingUser() {
        print("🔍 AuthManager.checkExistingUser() called")
        Task {
            await performSingleAuthenticationFlow()
        }
    }
    
    @MainActor
    private func performSingleAuthenticationFlow() async {
        // Prevent multiple simultaneous authentication attempts
        guard !isAuthenticating else {
            print("⚠️ Authentication already in progress - skipping")
            return
        }
        
        // Rate limiting: prevent authentication attempts within 2 seconds of each other
        let now = Date()
        if let lastAttempt = lastAuthAttempt, now.timeIntervalSince(lastAttempt) < 2.0 {
            print("⚠️ Authentication rate limited - too soon after last attempt")
            return
        }
        
        lastAuthAttempt = now
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        isLoading = true
        defer { isLoading = false }
        
        // Clear any existing error messages
        self.error = nil
        
        do {
            // Check if we have stored JWT tokens first (no biometric prompt)
            guard try keychainManager.hasStoredTokens() else {
                print("⚠️ No stored JWT tokens found - user needs to login manually")
                return
            }
            
            print("✅ Found stored JWT tokens")
            
            // Check if biometric is required
            let biometricRequired = try keychainManager.getBiometricEnabled()
            
            if biometricRequired {
                print("⚠️ Biometric authentication required - skipping auto-login")
                print("ℹ️ User can use 'Sign in with \(biometricDisplayName)' button to authenticate")
                return
            }
            
            // Try to authenticate with stored JWT tokens
            await performJWTAutoLogin()
            
        } catch {
            print("⚠️ Error in JWT authentication flow: \(error.localizedDescription)")
            try? keychainManager.clearAuthTokens()
        }
    }
    
    @MainActor
    private func performJWTAutoLogin() async {
        do {
            print("🔄 Attempting JWT auto-login with stored tokens")
            
            // Try to get current user using stored JWT tokens
            let user = try await APIService.shared.getCurrentUser()
            
            // Successfully authenticated with JWT tokens
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
            
            print("✅ JWT auto-login successful for user: \(user.username)")
            
        } catch {
            print("⚠️ JWT auto-login failed: \(error.localizedDescription)")
            
            // Handle specific error types
            if let apiError = error as? APIError {
                switch apiError {
                case .authenticationRequired:
                    // JWT tokens are invalid or expired beyond refresh
                    print("🔐 JWT tokens invalid - clearing stored tokens")
                    try? keychainManager.clearAuthTokens()
                    try? keychainManager.setBiometricEnabled(false)
                    biometricEnabled = false
                    self.error = "Your saved login has expired. Please sign in again."
                    
                case .serverError(let statusCode) where statusCode == 401:
                    // Server returned 401 - tokens might be revoked
                    print("🔐 Server returned 401 - clearing JWT tokens")
                    try? keychainManager.clearAuthTokens()
                    self.error = "Authentication expired. Please sign in again."
                    
                default:
                    // Other API errors (network, server issues) - keep tokens
                    print("ℹ️ Keeping stored tokens - error may be temporary: \(error)")
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("network") || errorMessage.contains("server") {
                        self.error = "Network issue. Your login will be restored when connection improves."
                    } else {
                        self.error = "Unable to sign in automatically. Please try manual login."
                    }
                }
            } else {
                // Non-API errors
                print("ℹ️ Non-API error during JWT auto-login: \(error)")
                self.error = "Unable to sign in automatically. Please try manual login."
            }
            
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // Removed old validation methods - now consolidated into performSingleAuthenticationFlow
    // Removed duplicate autoLogin method - now using performSingleAuthenticationFlow
    
    @MainActor
    func loadCurrentUser() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await APIService.shared.getCurrentUser()
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            // User is not logged in or there was an error
            self.currentUser = nil
            self.isAuthenticated = false
            // Don't show error when just checking for existing user
        }
    }
    
    @MainActor
    func login(username: String, password: String, enableBiometric: Bool = false) async {
        // Prevent multiple simultaneous login attempts
        guard !isAuthenticating else {
            print("⚠️ Login already in progress - skipping")
            return
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await APIService.shared.login(username: username, password: password)
            
            // JWT tokens are already stored by APIService.login()
            // Update biometric setting for tokens if requested
            if enableBiometric {
                try await updateTokensBiometricProtection(enabled: true)
            }
            
            self.currentUser = user
            self.isAuthenticated = true
            self.biometricEnabled = enableBiometric
            self.error = nil
            
            print("✅ JWT login successful with biometric: \(enableBiometric)")
            
        } catch {
            print("🔍 Login Error Details: \(error)")
            let errorMessage = error.localizedDescription
            if errorMessage.contains("connect") || errorMessage.contains("server") || errorMessage.contains("parse") {
                self.error = "Network issue. Try 'Continue as Guest' to play offline, or check your internet connection."
            } else if errorMessage.contains("credentials") || errorMessage.contains("401") {
                self.error = "Invalid username or password. Please try again."
            } else {
                self.error = "Login failed: \(errorMessage)"
            }
            self.isAuthenticated = false
        }
    }
    
    @MainActor
    func loginWithBiometric() async {
        guard keychainManager.isBiometricAvailable() else {
            self.error = "Biometric authentication is not available on this device"
            return
        }
        
        // Prevent multiple simultaneous biometric login attempts
        guard !isAuthenticating else {
            print("⚠️ Biometric login already in progress - skipping")
            return
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get stored JWT tokens with biometric authentication
            guard let authTokens = try await keychainManager.getAuthTokens() else {
                self.error = "No stored authentication tokens found. Please login with username and password first."
                return
            }
            
            print("✅ Retrieved JWT tokens via biometric authentication")
            
            // Try to get current user using the retrieved tokens
            let user = try await APIService.shared.getCurrentUser()
            
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
            
            print("✅ Biometric JWT login successful for user: \(user.username)")
            
        } catch {
            if let biometricError = error as? BiometricError {
                self.error = biometricError.localizedDescription
            } else if let keychainError = error as? KeychainError {
                self.error = keychainError.localizedDescription
            } else if let apiError = error as? APIError, case .authenticationRequired = apiError {
                self.error = "Your stored login has expired. Please sign in again."
                try? keychainManager.clearAuthTokens()
            } else {
                self.error = "Biometric login failed: \(error.localizedDescription)"
            }
            self.isAuthenticated = false
        }
    }
    
    @MainActor
    func register(username: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await APIService.shared.register(username: username, password: password)
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
        } catch {
            print("🔍 Registration Error Details: \(error)")
            let errorMessage = error.localizedDescription
            if errorMessage.contains("connect") || errorMessage.contains("server") || errorMessage.contains("parse") {
                self.error = "Network issue. Try 'Continue as Guest' to play offline, or check your internet connection."
            } else if errorMessage.contains("exists") || errorMessage.contains("400") {
                self.error = "Username already exists. Please choose a different username."
            } else {
                self.error = "Registration failed: \(errorMessage)"
            }
            self.isAuthenticated = false
        }
    }
    
    @MainActor
    func logout() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await APIService.shared.logout()
            
            // JWT tokens are cleared by APIService.logout()
            // Also clear legacy credentials for complete cleanup
            try? keychainManager.clearUserCredentials()
            
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestMode = false
            self.biometricEnabled = false
            self.error = nil
            
            print("✅ JWT logout successful and all tokens cleared")
            
        } catch {
            // Even if API logout fails, clear local tokens
            try? keychainManager.clearAuthTokens()
            try? keychainManager.clearUserCredentials()
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestMode = false
            self.biometricEnabled = false
            self.error = "Logout completed with warning: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func continueAsGuest() {
        self.currentUser = nil
        self.isAuthenticated = false
        self.isGuestMode = true
        self.error = nil
        
        // Automatically enable offline mode when in guest mode
        NotificationCenter.default.post(name: NSNotification.Name("EnableOfflineMode"), object: nil)
    }
    
    var isLoggedInOrGuest: Bool {
        return isAuthenticated || isGuestMode
    }
    
    // MARK: - Biometric Management
    
    @MainActor
    func toggleBiometric(_ enabled: Bool) async {
        guard keychainManager.isBiometricAvailable() else {
            self.error = "Biometric authentication is not available on this device"
            return
        }
        
        do {
            self.biometricEnabled = enabled
            
            // If user is authenticated, update token biometric protection
            if isAuthenticated {
                try await updateTokensBiometricProtection(enabled: enabled)
            } else {
                // Just update the setting for future use
                try keychainManager.setBiometricEnabled(enabled)
            }
            
            print("✅ Biometric authentication \(enabled ? "enabled" : "disabled")")
            
        } catch {
            self.error = "Failed to update biometric setting: \(error.localizedDescription)"
        }
    }
    
    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric"
        }
    }
    
    var isBiometricAvailable: Bool {
        return keychainManager.isBiometricAvailable()
    }
    
    var hasStoredCredentials: Bool {
        do {
            // Check for JWT tokens first, fallback to legacy credentials
            return try keychainManager.hasStoredTokens() || keychainManager.hasStoredCredentials()
        } catch {
            return false
        }
    }
    
    // MARK: - JWT Token Management Helpers
    
    @MainActor
    private func updateTokensBiometricProtection(enabled: Bool) async throws {
        // Get current tokens
        guard let tokens = try await keychainManager.getAuthTokens() else {
            throw APIError.authenticationRequired
        }
        
        // Re-save tokens with new biometric setting
        try keychainManager.saveAuthTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: "15m", // Use default expiry since we can't know original value
            requireBiometric: enabled
        )
        
        // Update biometric enabled setting
        try keychainManager.setBiometricEnabled(enabled)
        
        print("✅ Updated JWT token biometric protection: \(enabled)")
    }
    
    // MARK: - Debug and Maintenance Methods
    
    @MainActor
    func clearStoredCredentials() {
        do {
            // Clear both JWT tokens and legacy credentials
            try keychainManager.clearAuthTokens()
            try keychainManager.clearUserCredentials()
            self.biometricEnabled = false
            self.isAuthenticated = false
            self.currentUser = nil
            print("✅ Manually cleared all stored credentials and JWT tokens")
        } catch {
            print("⚠️ Error clearing credentials: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func debugStoredCredentials() async {
        do {
            let hasTokens = try keychainManager.hasStoredTokens()
            let hasLegacyCredentials = try keychainManager.hasStoredCredentials()
            let biometricEnabled = try keychainManager.getBiometricEnabled()
            
            print("🔍 Debug Stored Authentication:")
            print("   - Has JWT Tokens: \(hasTokens)")
            print("   - Has Legacy Credentials: \(hasLegacyCredentials)")
            print("   - Biometric Enabled: \(biometricEnabled)")
            print("   - Biometric Available: \(keychainManager.isBiometricAvailable())")
            
            // Check JWT tokens
            if hasTokens {
                if let tokens = try await keychainManager.getAuthTokens() {
                    print("   - Access Token: [REDACTED - Length: \(tokens.accessToken.count)]")
                    print("   - Refresh Token: [REDACTED - Length: \(tokens.refreshToken.count)]")
                    print("   - Token Expiry: \(tokens.expiryDate)")
                    print("   - Token Expired: \(tokens.isExpired)")
                    print("   - Token Will Expire Soon: \(tokens.willExpireSoon)")
                } else {
                    print("   - ⚠️ Could not retrieve JWT tokens despite hasStoredTokens = true")
                }
            }
            
            // Check legacy credentials
            if hasLegacyCredentials {
                if let credentials = try await keychainManager.getUserCredentials() {
                    print("   - Legacy Username: \(credentials.username)")
                    print("   - Legacy Password: [REDACTED - Length: \(credentials.password.count)]")
                    print("   - Legacy User ID: \(credentials.userId)")
                } else {
                    print("   - ⚠️ Could not retrieve legacy credentials despite hasStoredCredentials = true")
                }
            }
        } catch {
            print("🔍 Debug Error: \(error.localizedDescription)")
        }
    }
}