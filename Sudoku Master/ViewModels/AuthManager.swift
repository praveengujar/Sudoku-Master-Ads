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
            self.error = "Login failed: \(error.localizedDescription)"
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
            self.error = "Registration failed: \(error.localizedDescription)"
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
    }
    
    var isLoggedInOrGuest: Bool {
        return isAuthenticated || isGuestMode
    }
}