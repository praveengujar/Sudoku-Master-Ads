import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoginMode = true
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color.blue.opacity(0.1).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // App logo
                        VStack {
                            Image(systemName: "square.grid.3x3.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.blue)
                                .padding()
                            
                            Text("Sudoku Master")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Challenge your mind with logic puzzles")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.bottom)
                        }
                        .padding(.vertical)
                        
                        // Authentication form
                        VStack(spacing: 15) {
                            // Form heading
                            Text(isLoginMode ? "Welcome Back" : "Create Account")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Username field
                            TextField("Username", text: $username)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            // Password field
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            
                            // Confirm password field (only in register mode)
                            if !isLoginMode {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            
                            // Show any error message from auth manager
                            if let error = authManager.error {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                            
                            // Action button
                            Button(action: {
                                handleAuthentication()
                            }) {
                                Text(isLoginMode ? "Sign In" : "Create Account")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .disabled(authManager.isLoading)
                            .overlay(
                                Group {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                            
                            // Toggle between login and register
                            Button(action: {
                                isLoginMode.toggle()
                                // Clear fields when switching modes
                                password = ""
                                confirmPassword = ""
                            }) {
                                Text(isLoginMode ? "New user? Create an account" : "Already have an account? Sign in")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                            }
                            .padding(.top, 10)
                            
                            // Guest mode
                            Button(action: {
                                authManager.continueAsGuest()
                            }) {
                                Text("Continue as Guest")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .padding(.top, 10)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10)
                        
                        // Features list
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Game Features")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            FeatureRow(icon: "square.grid.3x3.fill", title: "Multiple Difficulty Levels", description: "Challenge yourself with easy, medium, and hard puzzles")
                            FeatureRow(icon: "lightbulb", title: "Helpful Hints", description: "Get unstuck with smart hints when you need them")
                            FeatureRow(icon: "arrow.clockwise", title: "Auto-Solve", description: "See the solution with a single tap")
                            FeatureRow(icon: "person.crop.circle.badge.checkmark", title: "Track Progress", description: "Save your games and monitor your improvement")
                            FeatureRow(icon: "wifi.slash", title: "Offline Mode", description: "Play anywhere, even without internet connection")
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // Handle login or registration
    private func handleAuthentication() {
        // Input validation
        if username.isEmpty || password.isEmpty {
            alertMessage = "Please enter both username and password."
            showAlert = true
            return
        }
        
        if !isLoginMode {
            // Registration validation
            if password != confirmPassword {
                alertMessage = "Passwords do not match."
                showAlert = true
                return
            }
            
            // Password strength check
            if password.count < 6 {
                alertMessage = "Password must be at least 6 characters long."
                showAlert = true
                return
            }
        }
        
        // Perform authentication
        Task {
            if isLoginMode {
                await authManager.login(username: username, password: password)
            } else {
                await authManager.register(username: username, password: password)
            }
        }
    }
}

// Feature row component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}