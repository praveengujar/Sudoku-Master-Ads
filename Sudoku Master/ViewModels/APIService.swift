import Foundation

// API endpoints and service methods
class APIService {
    static let shared = APIService()
    let baseURL = "https://sudoku-master-app.replit.app/api"
    
    private init() {}
    
    // MARK: - Authentication Methods
    
    func login(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/users/login"
        let body: [String: String] = ["username": username, "password": password]
        
        return try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func register(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/users/register"
        let body: [String: String] = ["username": username, "password": password]
        
        return try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func getCurrentUser() async throws -> User {
        let endpoint = "\(baseURL)/users/me"
        return try await performRequest(endpoint: endpoint, method: "GET", body: nil as Never?)
    }
    
    func logout() async throws {
        let endpoint = "\(baseURL)/users/logout"
        let _: EmptyResponse = try await performRequest(endpoint: endpoint, method: "POST", body: nil as Never?)
    }
    
    // MARK: - Sudoku Game Methods
    
    func generatePuzzle(difficulty: SudokuDifficulty) async throws -> SudokuPuzzle {
        let endpoint = "\(baseURL)/sudoku/generate?difficulty=\(difficulty.rawValue)"
        return try await performRequest(endpoint: endpoint, method: "GET", body: nil as Never?)
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
        return try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    func getUserStats(userId: Int) async throws -> UserStats {
        let endpoint = "\(baseURL)/sudoku/user-stats/\(userId)"
        return try await performRequest(endpoint: endpoint, method: "GET", body: nil as Never?)
    }
    
    // MARK: - Utility Methods
    
   func performRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String, 
        body: U? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            print("Server error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response body: \(responseString)")
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response body: \(responseString)")
            }
            throw APIError.decodingError(error: error)
        }
    }
}

// Empty response type for endpoints that don't return data
struct EmptyResponse: Decodable {}

// API error types
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(error: Error)
    case networkError(error: Error)
    
    var localizedDescription: String {
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
        }
    }
}

// MARK: - Request Body Structs

struct SaveGameProgressRequest: Encodable {
    let userId: Int
    let puzzleId: Int
    let currentGrid: SudokuGrid
    let isCompleted: Bool
    let timeSpentSeconds: Int
}

struct ValidateMoveRequest: Encodable {
    let grid: SudokuGrid
    let row: Int
    let col: Int
    let value: Int
}

struct SolvePuzzleRequest: Encodable {
    let grid: SudokuGrid
}
