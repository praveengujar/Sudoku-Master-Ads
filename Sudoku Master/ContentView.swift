import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        if authManager.isLoggedInOrGuest {
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