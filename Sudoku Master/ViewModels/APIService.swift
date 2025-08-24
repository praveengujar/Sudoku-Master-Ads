import Foundation
import Network
import Combine

// MARK: - Optimized API Service with Caching and Performance Improvements

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    // Updated to correct Sudoku Master project Cloud Run deployment (2025-08-18)
    let baseURL = "https://sudoku-master-api-93673815784.us-central1.run.app/api"
    
    // Performance optimizations
    private let session: URLSession
    private let cache = NSCache<NSString, CachedResponse>()
    private var activeTasks: [String: Task<Any, Error>] = [:]
    private let requestQueue = DispatchQueue(label: "api.requests", qos: .userInitiated)
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "network.monitor")
    @Published var isConnected = true
    
    // Request deduplication and retry logic
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Cache configuration
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private let maxCacheSize = 50
    
    private init() {
        // Optimized URLSession configuration for better performance
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0  // Reduced from 30s
        config.timeoutIntervalForResource = 30.0  // Reduced from 60s
        config.httpMaximumConnectionsPerHost = 6  // Increased from 1 for better concurrency
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024)
        config.httpCookieStorage = nil
        config.httpCookieAcceptPolicy = .never
        
        // Enable HTTP/2 for multiplexing and better performance
        config.httpShouldUsePipelining = true
        config.waitsForConnectivity = false
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        self.session = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
        session.invalidateAndCancel()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Simple Authentication (No Token Refresh)
    // Note: This backend uses simple username/password auth without JWT tokens
    
    // MARK: - Authentication Methods (Optimized)
    
    func login(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/users/login"
        let body: [String: String] = ["username": username, "password": password]
        
        // Try simplified approach first for login
        do {
            return try await performSimpleRequest(
                endpoint: endpoint,
                method: "POST",
                body: body
            )
        } catch {
            print("🔄 Simple request failed, trying optimized request: \(error)")
            // Fallback to optimized request
            return try await performOptimizedRequest(
                endpoint: endpoint,
                method: "POST",
                body: body,
                cachePolicy: .reloadIgnoringCacheData
            )
        }
    }
    
    func register(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/users/register"
        let body: [String: String] = ["username": username, "password": password]
        
        // Try simplified approach first for registration
        do {
            return try await performSimpleRequest(
                endpoint: endpoint,
                method: "POST",
                body: body
            )
        } catch {
            print("🔄 Simple registration failed, trying optimized request: \(error)")
            // Fallback to optimized request
            return try await performOptimizedRequest(
                endpoint: endpoint,
                method: "POST",
                body: body,
                cachePolicy: .reloadIgnoringCacheData
            )
        }
    }
    
    func getCurrentUser() async throws -> User {
        let endpoint = "\(baseURL)/users/me"
        return try await performOptimizedRequest(
            endpoint: endpoint,
            method: "GET",
            body: EmptyRequest(),
            cachePolicy: .returnCacheDataElseLoad,
            cacheTimeout: 60 // Cache user data for 1 minute
        )
    }
    
    func logout() async throws {
        let endpoint = "\(baseURL)/users/logout"
        let _: EmptyResponse = try await performOptimizedRequest(
            endpoint: endpoint,
            method: "POST",
            body: EmptyRequest(),
            cachePolicy: .reloadIgnoringCacheData
        )
        
        // Clear cache on logout
        cache.removeAllObjects()
    }
    
    // MARK: - Sudoku Game Methods (Optimized)
    
    func generatePuzzle(difficulty: SudokuDifficulty) async throws -> SudokuPuzzle {
        let endpoint = "\(baseURL)/sudoku/generate?difficulty=\(difficulty.rawValue)"
        print("🎯 API Request: \(endpoint)")
        print("🎯 Difficulty: \(difficulty.rawValue)")
        
        // Don't cache puzzle generation to ensure fresh puzzles
        let puzzle: SudokuPuzzle = try await performOptimizedRequest(
            endpoint: endpoint,
            method: "GET",
            body: EmptyRequest(),
            cachePolicy: .reloadIgnoringCacheData
        )
        
        print("🎯 Received puzzle ID: \(puzzle.id) with \(puzzle.grid.flatMap { $0 }.compactMap { $0 }.count) filled cells")
        return puzzle
    }
    
    func saveGameProgress(userId: Int, puzzleId: Int, currentGrid: SudokuGrid, isCompleted: Bool, timeSpentSeconds: Int) async throws -> GameplayRecord {
        let endpoint = "\(baseURL)/sudoku/save-progress"
        let body = SaveGameProgressRequest(
            userId: userId,
            puzzleId: puzzleId,
            currentGrid: currentGrid,
            isCompleted: isCompleted,
            timeSpentSeconds: timeSpentSeconds
        )
        
        return try await performOptimizedRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            cachePolicy: .reloadIgnoringCacheData
        )
    }
    
    func getUserStats(userId: Int) async throws -> UserStats {
        let endpoint = "\(baseURL)/sudoku/user-stats/\(userId)"
        return try await performOptimizedRequest(
            endpoint: endpoint,
            method: "GET",
            body: EmptyRequest(),
            cachePolicy: .returnCacheDataElseLoad,
            cacheTimeout: 30 // Cache stats for 30 seconds
        )
    }
    
    func validateMove(grid: SudokuGrid, row: Int, col: Int, value: Int) async throws -> Bool {
        let endpoint = "\(baseURL)/sudoku/validate"
        let body = ValidateMoveRequest(grid: grid, row: row, col: col, value: value)
        
        // Cache validation results for better performance
        let cacheKey = "validate_\(gridHash(grid))_\(row)_\(col)_\(value)"
        
        let response: [String: Bool] = try await performOptimizedRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            cachePolicy: .returnCacheDataElseLoad,
            cacheTimeout: 60,
            customCacheKey: cacheKey
        )
        
        return response["isValid"] ?? false
    }
    
    func solvePuzzle(grid: SudokuGrid) async throws -> SudokuGrid {
        let endpoint = "\(baseURL)/sudoku/solve"
        let body = SolvePuzzleRequest(grid: grid)
        
        // Cache puzzle solutions
        let cacheKey = "solve_\(gridHash(grid))"
        
        let response: [String: SudokuGrid] = try await performOptimizedRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            cachePolicy: .returnCacheDataElseLoad,
            cacheTimeout: 300,
            customCacheKey: cacheKey
        )
        
        return response["solution"] ?? []
    }
    
    // MARK: - Simple Request Method (Fallback)
    
    private func performSimpleRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U? = nil
    ) async throws -> T {
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        // Create basic URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add body if provided
        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }
        
        // Use basic URLSession
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.serverError(statusCode: 401)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Simple JSON decoding
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Simple decode error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 Response data: \(responseString)")
            }
            print("🔍 Expected type: \(T.self)")
            #endif
            throw APIError.decodingError(error: error)
        }
    }
    
    // MARK: - Optimized Request Performance
    
    private func performOptimizedRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U? = nil,
        cachePolicy: CachePolicy = .returnCacheDataElseLoad,
        cacheTimeout: TimeInterval? = nil,
        customCacheKey: String? = nil,
        retryCount: Int = 0
    ) async throws -> T {
        
        // Generate cache key
        let cacheKey = customCacheKey ?? generateCacheKey(endpoint: endpoint, method: method, body: body)
        
        // Check cache first (if policy allows)
        if cachePolicy == .returnCacheDataElseLoad || cachePolicy == .returnCacheDataDontLoad {
            if let cachedResponse = getCachedResponse(for: cacheKey),
               !cachedResponse.isExpired(timeout: cacheTimeout ?? self.cacheTimeout) {
                let data = cachedResponse.data
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                } catch {
                    // If cached data is corrupted, remove it and continue
                    cache.removeObject(forKey: NSString(string: cacheKey))
                }
            }
            
            if cachePolicy == .returnCacheDataDontLoad {
                throw APIError.cacheDataNotAvailable
            }
        }
        
        // Deduplicate concurrent requests
        if let existingTask = activeTasks[cacheKey] {
            return try await existingTask.value as! T
        }
        
        // Create new task
        let task = Task<Any, Error> {
            defer { activeTasks.removeValue(forKey: cacheKey) }
            
            return try await executeRequest(
                endpoint: endpoint,
                method: method,
                body: body,
                cacheKey: cacheKey,
                retryCount: retryCount
            ) as T
        }
        
        activeTasks[cacheKey] = task
        return try await task.value as! T
    }
    
    private func executeRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U?,
        cacheKey: String,
        retryCount: Int
    ) async throws -> T {
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Add request body if provided
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 401:
                // Unauthorized - clear stored credentials and fail
                // Note: This backend doesn't support token refresh, so we clear credentials
                try? KeychainManager.shared.clearUserCredentials()
                throw APIError.serverError(statusCode: 401)
                
            case 200...299:
                // Success - decode and cache response
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Debug: Print response data for troubleshooting (development only)
                #if DEBUG
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 API Response: \(responseString)")
                }
                #endif
                
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    
                    // Cache successful responses
                    cacheResponse(data: data, for: cacheKey)
                    
                    return decodedResponse
                } catch {
                    print("❌ JSON Decoding Error: \(error)")
                    print("❌ Failed to decode type: \(T.self)")
                    throw APIError.decodingError(error: error)
                }
                
            case 429:
                // Rate limiting - retry with exponential backoff
                if retryCount < maxRetries {
                    let delay = baseRetryDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await executeRequest(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        cacheKey: cacheKey,
                        retryCount: retryCount + 1
                    )
                }
                throw APIError.rateLimited
                
            case 500...599:
                // Server error - retry with backoff
                if retryCount < maxRetries {
                    let delay = baseRetryDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await executeRequest(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        cacheKey: cacheKey,
                        retryCount: retryCount + 1
                    )
                }
                throw APIError.serverError(statusCode: httpResponse.statusCode)
                
            default:
                print("API Error: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseString)")
                }
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
            
        } catch let error as URLError {
            // Network error - retry with backoff if appropriate
            if retryCount < maxRetries && isRetryableNetworkError(error) {
                let delay = baseRetryDelay * pow(2.0, Double(retryCount))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    cacheKey: cacheKey,
                    retryCount: retryCount + 1
                )
            }
            throw APIError.networkError(error: error)
        } catch {
            throw error
        }
    }
    
    // MARK: - Cache Management
    
    private func generateCacheKey<U: Encodable>(endpoint: String, method: String, body: U?) -> String {
        var key = "\(method)_\(endpoint)"
        
        if let body = body {
            do {
                let data = try JSONEncoder().encode(body)
                let bodyHash = data.hashValue
                key += "_\(bodyHash)"
            } catch {
                // If encoding fails, use a simple key
                key += "_\(String(describing: body).hashValue)"
            }
        }
        
        return key
    }
    
    private func cacheResponse(data: Data, for key: String) {
        let cachedResponse = CachedResponse(data: data, timestamp: Date())
        cache.setObject(cachedResponse, forKey: NSString(string: key))
    }
    
    private func getCachedResponse(for key: String) -> CachedResponse? {
        return cache.object(forKey: NSString(string: key))
    }
    
    private func gridHash(_ grid: SudokuGrid) -> String {
        return grid.flatMap { $0.map { $0?.description ?? "nil" } }.joined().hashValue.description
    }
    
    // MARK: - Helper Methods
    
    private func isRetryableNetworkError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Cache Cleanup
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    func clearExpiredCache() {
        // This would require keeping track of all cache keys
        // For now, we rely on NSCache's automatic eviction
    }
}

// MARK: - Supporting Types

// Empty request type for iOS 14+ compatibility
struct EmptyRequest: Codable {
    // Empty struct for GET requests that don't need a body
}

private class CachedResponse {
    let data: Data
    let timestamp: Date
    
    init(data: Data, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
    
    func isExpired(timeout: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > timeout
    }
}

enum CachePolicy {
    case reloadIgnoringCacheData
    case returnCacheDataElseLoad
    case returnCacheDataDontLoad
}

// MARK: - Enhanced Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(error: Error)
    case networkError(error: Error)
    case rateLimited
    case cacheDataNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .cacheDataNotAvailable:
            return "Cached data not available"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .serverError:
            return "The server is experiencing issues. Please try again later."
        case .rateLimited:
            return "You're making requests too quickly. Please wait a moment and try again."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Request Body Structs (Enhanced)

struct SaveGameProgressRequest: Encodable {
    let userId: Int
    let puzzleId: Int
    let currentGrid: SudokuGrid
    let isCompleted: Bool
    let timeSpentSeconds: Int
    let timestamp: Date = Date()
}

struct ValidateMoveRequest: Encodable {
    let grid: SudokuGrid
    let row: Int
    let col: Int
    let value: Int
    let timestamp: Date = Date()
}

struct SolvePuzzleRequest: Encodable {
    let grid: SudokuGrid
    let timestamp: Date = Date()
}

// Empty response type for endpoints that don't return data
struct EmptyResponse: Decodable {}

// Removed RefreshToken types as backend doesn't support token refresh