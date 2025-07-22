import Foundation
import Network

// Class for monitoring network connectivity status
class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionDescription = "Connected"
    
    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionDescription(path)
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    private func updateConnectionDescription(_ path: NWPath) {
        if path.status == .satisfied {
            if path.isExpensive {
                connectionDescription = "Connected (Cellular)"
            } else {
                connectionDescription = "Connected (WiFi)"
            }
        } else if path.status == .unsatisfied {
            connectionDescription = "No Connection"
        } else {
            connectionDescription = "Unknown Status"
        }
    }
    
    deinit {
        networkMonitor.cancel()
    }
}