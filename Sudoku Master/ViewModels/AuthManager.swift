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
            await autoLogin()
        }
    }
    
    @MainActor
    func autoLogin() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if biometric is required first
            let biometricRequired = try keychainManager.getBiometricEnabled()
            
            if biometricRequired {
                // If biometric is required, don't auto-login on app startup
                // User will need to use the biometric login button manually
                print("⚠️ Biometric authentication required - skipping auto-login")
                print("ℹ️ User can use 'Sign in with Face ID' button to authenticate")
                return
            }
            
            // Try to get stored credentials (non-biometric protected)
            guard let authTokens = try await keychainManager.getAuthTokens() else {
                // No stored credentials, user needs to login
                print("⚠️ No stored credentials found")
                return
            }
            
            // Use stored username and password to auto-login
            let username = authTokens.accessToken // We stored username as accessToken
            let password = authTokens.refreshToken ?? "" // We stored password as refreshToken
            
            // Attempt login with stored credentials
            let user = try await APIService.shared.login(username: username, password: password)
            
            // Successfully authenticated with stored credentials
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
            
            print("✅ Auto-login successful for user: \(user.username)")
            
        } catch {
            // Handle different types of errors
            if let keychainError = error as? KeychainError,
               case .biometricAuthenticationRequired = keychainError {
                // Biometric authentication was cancelled or failed
                print("⚠️ Biometric authentication required - user needs to authenticate manually")
                self.currentUser = nil
                self.isAuthenticated = false
                // Don't clear credentials, just let user try biometric login manually
            } else {
                // Other login errors - clear invalid credentials
                try? keychainManager.clearAuthTokens()
                self.currentUser = nil
                self.isAuthenticated = false
                print("⚠️ Auto-login failed: \(error.localizedDescription)")
                print("⚠️ Cleared stored credentials")
            }
        }
    }
    
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
            try keychainManager.saveAuthTokens(
                accessToken: username, // Store username as token for now
                refreshToken: password, // Store password as refresh token for now
                userId: user.id,
                username: user.username,
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
            guard let authTokens = try await keychainManager.getAuthTokens() else {
                self.error = "No stored credentials found. Please login with username and password first."
                return
            }
            
            // Use stored credentials to login
            let username = authTokens.accessToken // We stored username as accessToken
            let password = authTokens.refreshToken ?? "" // We stored password as refreshToken
            
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
            
            // Clear stored tokens from Keychain
            try keychainManager.clearAuthTokens()
            
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestMode = false
            self.biometricEnabled = false
            self.error = nil
            
            print("✅ Logout successful and tokens cleared")
            
        } catch {
            // Even if API logout fails, clear local tokens
            try? keychainManager.clearAuthTokens()
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
                if let authTokens = try? await keychainManager.getAuthTokens() {
                    try keychainManager.saveAuthTokens(
                        accessToken: authTokens.accessToken, // Keep stored username
                        refreshToken: authTokens.refreshToken, // Keep stored password
                        userId: user.id,
                        username: user.username,
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
}