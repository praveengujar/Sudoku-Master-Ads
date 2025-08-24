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
        Task {
            await performSingleAuthenticationFlow()
        }
    }
    
    @MainActor
    private func performSingleAuthenticationFlow() async {
        isLoading = true
        defer { isLoading = false }
        
        // Clear any existing error messages
        self.error = nil
        
        do {
            // Check if we have stored credentials first (no biometric prompt)
            guard try keychainManager.hasStoredCredentials() else {
                print("⚠️ No stored credentials found - user needs to login manually")
                return
            }
            
            // Get the username to show in logs (doesn't trigger biometric)
            let storedUsername = try keychainManager.getUsernameIfAvailable() ?? "Unknown"
            print("✅ Found stored credentials for user: \(storedUsername)")
            
            // Check if biometric is required
            let biometricRequired = try keychainManager.getBiometricEnabled()
            
            if biometricRequired {
                print("⚠️ Biometric authentication required - skipping auto-login")
                print("ℹ️ User can use 'Sign in with \(biometricDisplayName)' button to authenticate")
                return
            }
            
            // Only now try to get credentials (this will prompt Face ID if needed)
            guard let userCredentials = try await keychainManager.getUserCredentials() else {
                print("⚠️ Could not retrieve stored credentials - clearing them")
                try? keychainManager.clearUserCredentials()
                return
            }
            
            // Validate credentials are not empty
            if userCredentials.username.isEmpty || userCredentials.password.isEmpty {
                print("⚠️ Stored credentials are empty - clearing them")
                try? keychainManager.clearUserCredentials()
                return
            }
            
            print("✅ Retrieved valid credentials for user: \(userCredentials.username)")
            
            // Test credentials with API and auto-login if valid
            await performAutoLoginWithCredentials(userCredentials)
            
        } catch {
            print("⚠️ Error in authentication flow: \(error.localizedDescription)")
            try? keychainManager.clearUserCredentials()
        }
    }
    
    @MainActor
    private func performAutoLoginWithCredentials(_ credentials: UserCredentials) async {
        do {
            print("🔄 Attempting auto-login for user: \(credentials.username)")
            
            // Attempt login with stored credentials
            let user = try await APIService.shared.login(username: credentials.username, password: credentials.password)
            
            // Successfully authenticated with stored credentials
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
            
            print("✅ Auto-login successful for user: \(user.username)")
            
        } catch {
            print("⚠️ Auto-login failed: \(error.localizedDescription)")
            
            // Only clear credentials if it's an authentication error (401)
            let errorMessage = error.localizedDescription
            if errorMessage.contains("credentials") || errorMessage.contains("401") {
                try? keychainManager.clearUserCredentials()
                try? keychainManager.setBiometricEnabled(false)
                biometricEnabled = false
                print("⚠️ Cleared invalid stored credentials and disabled biometric")
            } else {
                print("ℹ️ Keeping stored credentials - error may be temporary")
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
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await APIService.shared.login(username: username, password: password)
            
            // Store user credentials in Keychain for persistent login
            try keychainManager.saveUserCredentials(
                username: username,
                password: password,
                userId: user.id,
                requireBiometric: enableBiometric
            )
            
            self.currentUser = user
            self.isAuthenticated = true
            self.biometricEnabled = enableBiometric
            self.error = nil
            
            print("✅ Login successful and tokens stored with biometric: \(enableBiometric)")
            
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
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get stored credentials with biometric authentication
            guard let userCredentials = try await keychainManager.getUserCredentials() else {
                self.error = "No stored credentials found. Please login with username and password first."
                return
            }
            
            // Use stored credentials to login
            let username = userCredentials.username
            let password = userCredentials.password
            
            let user = try await APIService.shared.login(username: username, password: password)
            
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
            
            print("✅ Biometric login successful for user: \(user.username)")
            
        } catch {
            if let biometricError = error as? BiometricError {
                self.error = biometricError.localizedDescription
            } else if let keychainError = error as? KeychainError {
                self.error = keychainError.localizedDescription
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
            
            // Clear stored credentials from Keychain
            try keychainManager.clearUserCredentials()
            
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestMode = false
            self.biometricEnabled = false
            self.error = nil
            
            print("✅ Logout successful and tokens cleared")
            
        } catch {
            // Even if API logout fails, clear local credentials
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
            try keychainManager.setBiometricEnabled(enabled)
            self.biometricEnabled = enabled
            
            // If enabling biometric and user is logged in, re-save credentials with biometric protection
            if enabled && isAuthenticated, let user = currentUser {
                // Get current stored credentials
                if let userCredentials = try? await keychainManager.getUserCredentials() {
                    try keychainManager.saveUserCredentials(
                        username: userCredentials.username,
                        password: userCredentials.password,
                        userId: user.id,
                        requireBiometric: true
                    )
                }
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
            return try keychainManager.hasStoredCredentials()
        } catch {
            return false
        }
    }
    
    // MARK: - Debug and Maintenance Methods
    
    @MainActor
    func clearStoredCredentials() {
        do {
            try keychainManager.clearUserCredentials()
            self.biometricEnabled = false
            self.isAuthenticated = false
            self.currentUser = nil
            print("✅ Manually cleared all stored credentials")
        } catch {
            print("⚠️ Error clearing credentials: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func debugStoredCredentials() async {
        do {
            let hasCredentials = try keychainManager.hasStoredCredentials()
            let biometricEnabled = try keychainManager.getBiometricEnabled()
            
            print("🔍 Debug Stored Credentials:")
            print("   - Has Credentials: \(hasCredentials)")
            print("   - Biometric Enabled: \(biometricEnabled)")
            print("   - Biometric Available: \(keychainManager.isBiometricAvailable())")
            
            if hasCredentials {
                if let credentials = try await keychainManager.getUserCredentials() {
                    print("   - Username: \(credentials.username)")
                    print("   - Password: [REDACTED - Length: \(credentials.password.count)]")
                    print("   - User ID: \(credentials.userId)")
                } else {
                    print("   - ⚠️ Could not retrieve credentials despite hasStoredCredentials = true")
                }
            }
        } catch {
            print("🔍 Debug Error: \(error.localizedDescription)")
        }
    }
}