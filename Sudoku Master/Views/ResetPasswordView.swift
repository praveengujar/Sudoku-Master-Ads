import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your username to reset your password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Username input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your username", text: $username)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)
                
                // Reset button
                Button(action: {
                    handlePasswordReset()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text("Reset Password")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(username.isEmpty ? Color.gray : Color.orange)
                    .cornerRadius(10)
                }
                .disabled(username.isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
                
                // Instructions
                VStack(spacing: 12) {
                    Text("How it works:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text("Enter your username above")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text("We'll verify your account exists")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text("Your password will be temporarily reset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("4.")
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text("Log in with the new temporary password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.vertical)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handlePasswordReset() {
        guard !username.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.requestPasswordReset(username: username)
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = """
                    Password reset successful! 
                    
                    A temporary password has been generated for your account. Check the app console/logs for the temporary password (in production, this would be sent via email/SMS).
                    
                    Please log in with your username and the temporary password, then change it immediately for security.
                    """
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}