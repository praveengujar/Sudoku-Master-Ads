import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isGuestMode = false
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        checkExistingUser()
    }
    
    func checkExistingUser() {
        Task {
            await loadCurrentUser()
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
    func login(username: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await APIService.shared.login(username: username, password: password)
            self.currentUser = user
            self.isAuthenticated = true
            self.error = nil
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
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestMode = false
            self.error = nil
        } catch {
            self.error = "Logout failed: \(error.localizedDescription)"
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
}