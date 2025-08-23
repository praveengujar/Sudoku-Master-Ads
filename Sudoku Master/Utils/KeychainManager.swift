import Foundation
import Security
import LocalAuthentication

// MARK: - Keychain Manager for Secure Authentication Storage

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Keychain Keys
    private struct Keys {
        static let accessToken = "com.sudokumaster.accessToken"
        static let refreshToken = "com.sudokumaster.refreshToken"
        static let userId = "com.sudokumaster.userId"
        static let username = "com.sudokumaster.username"
        static let biometricEnabled = "com.sudokumaster.biometricEnabled"
    }
    
    // MARK: - Biometric Authentication
    
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func getBiometricType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        return context.biometryType
    }
    
    func hasStoredCredentials() throws -> Bool {
        // Check if we have the essential credentials stored (without triggering biometric auth)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Keys.username,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        guard isBiometricAvailable() else {
            throw BiometricError.notAvailable
        }
        
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        
        let reason = "Authenticate to access your Sudoku Master account"
        
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            print("✅ Biometric authentication successful")
            return result
        } catch let error as LAError {
            print("⚠️ LAError during biometric authentication: \(error.localizedDescription)")
            switch error.code {
            case .userCancel, .userFallback, .systemCancel:
                throw BiometricError.authenticationFailed("Authentication was cancelled")
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw BiometricError.notAvailable
            case .authenticationFailed:
                throw BiometricError.authenticationFailed("Authentication failed")
            default:
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
        } catch {
            print("⚠️ Unknown error during biometric authentication: \(error.localizedDescription)")
            throw BiometricError.authenticationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Token Storage with Biometric Protection
    
    func saveAuthTokens(accessToken: String, refreshToken: String?, userId: Int, username: String, requireBiometric: Bool = false) throws {
        
        // Save access token
        try saveToKeychain(
            key: Keys.accessToken,
            data: accessToken.data(using: .utf8)!,
            requireBiometric: requireBiometric
        )
        
        // Save refresh token if provided
        if let refreshToken = refreshToken {
            try saveToKeychain(
                key: Keys.refreshToken,
                data: refreshToken.data(using: .utf8)!,
                requireBiometric: requireBiometric
            )
        }
        
        // Save user ID
        try saveToKeychain(
            key: Keys.userId,
            data: String(userId).data(using: .utf8)!,
            requireBiometric: false // User ID doesn't need biometric protection
        )
        
        // Save username
        try saveToKeychain(
            key: Keys.username,
            data: username.data(using: .utf8)!,
            requireBiometric: false
        )
        
        // Save biometric preference
        try saveToKeychain(
            key: Keys.biometricEnabled,
            data: String(requireBiometric).data(using: .utf8)!,
            requireBiometric: false
        )
        
        print("✅ Auth tokens saved to Keychain with biometric: \(requireBiometric)")
    }
    
    func getAuthTokens() async throws -> AuthTokens? {
        do {
            // Create shared authentication context to avoid multiple biometric prompts
            let context = LAContext()
            context.localizedFallbackTitle = "Use Passcode"
            
            // Retrieve tokens with shared context
            guard let accessTokenData = try getFromKeychainWithContext(key: Keys.accessToken, context: context),
                  let accessToken = String(data: accessTokenData, encoding: .utf8),
                  let userIdData = try getFromKeychainWithContext(key: Keys.userId, context: context),
                  let userIdString = String(data: userIdData, encoding: .utf8),
                  let userId = Int(userIdString),
                  let usernameData = try getFromKeychainWithContext(key: Keys.username, context: context),
                  let username = String(data: usernameData, encoding: .utf8) else {
                print("⚠️ Could not retrieve all required authentication data from Keychain")
                return nil
            }
            
            // Refresh token is optional
            let refreshTokenData = try? getFromKeychainWithContext(key: Keys.refreshToken, context: context)
            let refreshToken = refreshTokenData.flatMap { String(data: $0, encoding: .utf8) }
            
            return AuthTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userId: userId,
                username: username
            )
            
        } catch {
            print("⚠️ Error getting auth tokens: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getBiometricEnabled() throws -> Bool {
        guard let data = try getFromKeychain(key: Keys.biometricEnabled),
              let value = String(data: data, encoding: .utf8) else {
            return false
        }
        return value == "true"
    }
    
    func setBiometricEnabled(_ enabled: Bool) throws {
        try saveToKeychain(
            key: Keys.biometricEnabled,
            data: String(enabled).data(using: .utf8)!,
            requireBiometric: false
        )
    }
    
    // MARK: - Clear Authentication Data
    
    func clearAuthTokens() throws {
        try deleteFromKeychain(key: Keys.accessToken)
        try deleteFromKeychain(key: Keys.refreshToken)
        try deleteFromKeychain(key: Keys.userId)
        try deleteFromKeychain(key: Keys.username)
        try deleteFromKeychain(key: Keys.biometricEnabled)
        
        print("✅ Auth tokens cleared from Keychain")
    }
    
    // MARK: - Private Keychain Operations
    
    private func saveToKeychain(key: String, data: Data, requireBiometric: Bool) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add biometric protection if requested and available
        if requireBiometric && isBiometricAvailable() {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryAny,
                nil
            )
            if let access = access {
                query[kSecAttrAccessControl as String] = access
                query.removeValue(forKey: kSecAttrAccessible as String)
            }
        }
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveError(status)
        }
    }
    
    private func getFromKeychain(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            // Handle biometric authentication failures (status codes for user cancel and auth failure)
            if status == -128 || status == -25293 || status == -25300 {
                throw KeychainError.biometricAuthenticationRequired
            }
            throw KeychainError.retrieveError(status)
        }
        
        return result as? Data
    }
    
    private func getFromKeychainWithContext(key: String, context: LAContext) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            // Handle biometric authentication failures (status codes for user cancel and auth failure)
            if status == -128 || status == -25293 || status == -25300 {
                throw KeychainError.biometricAuthenticationRequired
            }
            throw KeychainError.retrieveError(status)
        }
        
        return result as? Data
    }
    
    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Don't throw error if item doesn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteError(status)
        }
    }
}

// MARK: - Supporting Types

struct AuthTokens {
    let accessToken: String
    let refreshToken: String?
    let userId: Int
    let username: String
}

enum KeychainError: Error, LocalizedError {
    case saveError(OSStatus)
    case retrieveError(OSStatus)
    case deleteError(OSStatus)
    case biometricAuthenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .saveError(let status):
            return "Failed to save to Keychain: \(status)"
        case .retrieveError(let status):
            return "Failed to retrieve from Keychain: \(status)"
        case .deleteError(let status):
            return "Failed to delete from Keychain: \(status)"
        case .biometricAuthenticationRequired:
            return "Biometric authentication is required to access your account"
        }
    }
}

enum BiometricError: Error, LocalizedError {
    case authenticationFailed(String)
    case notAvailable
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Biometric authentication failed: \(message)"
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        }
    }
}