import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        if authManager.isAuthenticated {
            HomeView()
        } else {
            AuthView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}