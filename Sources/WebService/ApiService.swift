//
//  ApiService.swift
//  WebService
//
//  Created by Pankaj on 18/02/25.
//

import Foundation
import Network

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public enum APIRequest {
    case getRequest(url: URL, headers: [String: Any]?)
    case postRequest(url: URL, body: Data?, headers: [String: Any]?)
    case uploadMultipart(url: URL, parameters: [String: Any], files: [File], headers: [String: Any]?)
    case restRequest(url: URL, method: HTTPMethod, body: Data?, headers: [String: Any]?)
    
    public struct File {
        public let data: Data
        public let fileName: String
        public let mimeType: String
    }
}

// MARK: - API Errors
enum APIError: Error,LocalizedError {
    case networkUnavailable
    case invalidResponse
    case networkError(String)
    case serverError(Int)
    case decodingError(String)
    case unknown(String)
    case unauthorized
    case forbidden
    case clientError
    case notFound
    
    var errorMessage: String {
        switch self {
        case .networkUnavailable:
            return "The Internet connection appears to be offline. Please check your connection and try again."
        case .invalidResponse:
            return "Invalid response from the server. Please try again later."
        case .networkError(let message):
            return "Network error occurred: \(message). Please check your connection."
        case .serverError(let statusCode):
            return "Server error (\(statusCode)). Please try again later."
        case .decodingError(let message):
            return "Failed to process the response: \(message)."
        case .unknown(let message):
            return "An unexpected error occurred: \(message). Please try again."
        case .unauthorized:
            return "You are not authorized to perform this action. Please log in again."
        case .forbidden:
            return "Access denied. You do not have permission to access this resource."
        case .clientError:
            return "There was an error in your request. Please check and try again."
        case .notFound:
            return "The requested resource could not be found. Please verify the URL and try again."
        }
    }
    // ✅ Override `LocalizedError`'s `errorDescription` to return `errorMessage`
    var errorDescription: String? {
        return errorMessage
    }
}


// Lightweight API manager with memory-efficient calls
public actor APIManager {
    
    static let shared = APIManager()
    
    private let session: URLSession
    private let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000, diskPath: nil)
    private var isConnected = false
    private let monitor = NWPathMonitor()
    private var pendingRequests: [APIRequest] = []
    var progressHandler: ((APIRequest.File, Double) -> Void)?
    private let userDefaults = UserDefaults.standard
    
    public init() {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        session = URLSession(configuration: config)
        startNetworkMonitoring()
    }
    
    /// 📌 Start Network Monitoring (Nonisolated)
    nonisolated private func startNetworkMonitoring() {
        let queue = DispatchQueue.global(qos: .background)
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { await self.updateConnectionStatus(isConnected: path.status == .satisfied) }
        }
        monitor.start(queue: queue)
    }
    
    /// 📌 Update Connection Status Inside Actor (Isolated)
    private func updateConnectionStatus(isConnected: Bool) async {
        self.isConnected = isConnected
        if isConnected {
            await retryPendingRequests()
        }
    }
    
    /// 📌 Handle API Requests with Offline Support
    public func handleRequest(_ request: APIRequest, progress: ((APIRequest.File, Double) -> Void)? = nil) async throws -> Data {
        
        // If offline and cached data exists, return cached response
        if !isConnected, let cachedData = getCachedData(for: request) {
            return cachedData
        }
        
        // Try fetching data from API
        do {
            let responseData: Data
            switch request {
            case .getRequest(let url, let headers):
                responseData = try await fetchData(from: url, headers: headers)
            case .postRequest(let url, let body, let headers):
                responseData = try await sendData(to: url, method: .post, body: body, headers: headers)
            case .uploadMultipart(let url, let parameters, let files, let headers):
                responseData = try await uploadMultipart(to: url, parameters: parameters, files: files, headers: headers)
            case .restRequest(let url, let method, let body, let headers):
                responseData = try await sendData(to: url, method: method, body: body, headers: headers)
            }
            
            // Cache successful response
            cacheData(responseData, for: request)
            return responseData
            
        } catch {
            // If offline, store failed request for retry
            debugPrint("Is Connected with internet \(self.isConnected)")
            debugPrint("Error \(error.localizedDescription)")
            if !isConnected {
                addPendingRequest(request)
            }
            throw error
        }
    }
    
    /// 📌 Cache API Response
    private func cacheData(_ data: Data, for request: APIRequest) {
        let key = cacheKey(for: request)
        userDefaults.set(data, forKey: key)
    }
    
    /// 📌 Retrieve Cached Data
    private func getCachedData(for request: APIRequest) -> Data? {
        let key = cacheKey(for: request)
        return userDefaults.data(forKey: key)
    }
    
    /// 📌 Generate Unique Cache Key
    private func cacheKey(for request: APIRequest) -> String {
        switch request {
        case .getRequest(let url, _): return url.absoluteString
        case .postRequest(let url, _, _): return url.absoluteString
        case .uploadMultipart(let url, _, _, _): return url.absoluteString
        case .restRequest(let url, _, _, _): return url.absoluteString
        }
    }
    
    /// 📌 Store Failed Requests
    private func addPendingRequest(_ request: APIRequest) {
        pendingRequests.append(request)
    }
    
    /// 📌 Retry Failed Requests when Internet is Back
    private func retryPendingRequests() async {
        guard isConnected else { return }
        
        for request in pendingRequests {
            do {
                let _ = try await handleRequest(request)
                print("✅ Retried API: \(request)")
            } catch {
                print("❌ Retry Failed:", error.localizedDescription)
            }
        }
        pendingRequests.removeAll()
    }
    
    private func setHeaders(request: inout URLRequest, headers: [String: Any]?) {
        headers?.forEach { key, value in
            request.setValue("\(value)", forHTTPHeaderField: key)
        }
    }
    
    // MARK: - GET Request (Efficient Memory Usage)
    private func fetchData(from url: URL, headers: [String: Any]?) async throws -> Data {
        guard isConnected else {
            debugPrint("Error is \(APIError.networkUnavailable.localizedDescription)")
            throw APIError.networkUnavailable
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        setHeaders(request: &request, headers: headers)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return autoreleasepool { data }
    }
    
    // MARK: - Generic Request (For POST, PUT, DELETE)
    private func sendData(to url: URL, method: HTTPMethod, body: Data?, headers: [String: Any]?) async throws -> Data {
        
        guard isConnected else {
            debugPrint("Error is \(APIError.networkUnavailable.localizedDescription)")
            throw APIError.networkUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        setHeaders(request: &request, headers: headers)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return data
    }
    
    // MARK: - Multipart Upload with Progress Tracking
    private func uploadMultipart(to url: URL, parameters: [String: Any], files: [APIRequest.File], headers: [String: Any]?) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        setHeaders(request: &request, headers: headers)
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = UploadTaskDelegate(progressHandler: progressHandler, continuation: continuation)
            let session = URLSession(configuration: .default, delegate: uploadTask, delegateQueue: nil)
            
            // Create multipart body as a stream
            let body = createMultipartBody(parameters: parameters, files: files, boundary: boundary)
            let task = session.uploadTask(with: request, from: body)
            uploadTask.task = task
            
            task.resume()
        }
    }
    
    // MARK: - Helper: Create Multipart Form Body
    private func createMultipartBody(parameters: [String: Any], files: [APIRequest.File], boundary: String) -> Data {
        var body = Data()
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        for file in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.fileName)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }
}

// MARK: - Upload Task Delegate for Progress Tracking
private class UploadTaskDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    weak var task: URLSessionUploadTask?
    var progressHandler: ((APIRequest.File, Double) -> Void)?
    let continuation: CheckedContinuation<Data, Error>
    
    init(progressHandler: ((APIRequest.File, Double) -> Void)?, continuation: CheckedContinuation<Data, Error>) {
        self.progressHandler = progressHandler
        self.continuation = continuation
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        if let file = getCurrentUploadingFile(task) {
            DispatchQueue.main.async {
                self.progressHandler?(file, progress)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        continuation.resume(returning: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation.resume(throwing: error)
        }
    }
    
    private func getCurrentUploadingFile(_ task: URLSessionTask) -> APIRequest.File? {
        // Implement logic to match task with file if needed
        return nil
    }
}

// MARK: - Data Extension for Efficient Appending
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
