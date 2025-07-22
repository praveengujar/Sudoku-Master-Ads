import SwiftUI

@main
struct SudokuMasterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.sudokuStore)
                .environmentObject(appDelegate.authManager)
                .environmentObject(appDelegate.networkMonitor)
                .environmentObject(appDelegate.offlineStorage)
        }
    }
}