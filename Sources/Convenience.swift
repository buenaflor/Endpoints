import Foundation

extension URL: URLRequestEncodable {
    public var urlRequest: URLRequest {
        return URLRequest(url: self)
    }
}

extension URLRequest: URLRequestEncodable {
    public var urlRequest: URLRequest {
        return self
    }
}

public struct BasicAuthorization {
    public let user: String
    public let password: String
    
    public init(user: String, password: String) {
        self.user = user
        self.password = password
    }
    
    public var key: String {
        return "Authorization"
    }
    
    public var value: String {
        var value = "\(user):\(password)"
        let data = value.data(using: .utf8)!
        
        value = data.base64EncodedString(options: .endLineWithLineFeed)
        
        return "Basic \(value)"
    }
    
    public var header: Parameters {
        return [ key: value ]
    }
}

public struct AnyCall<Response: ResponseDecodable>: Call {
    public typealias DecodedType = Response
    
    public var request: URLRequestEncodable

    public init(_ request: URLRequestEncodable) {
        self.request = request
    }
}

public extension HTTPURLResponse {
    /// Checks if an HTTP status code is acceptable
    /// - returns: `true` if `code` is between 200 and 299.
    func hasAcceptableStatus() -> Bool {
        return (200..<300).contains(statusCode)
    }

    /// - throws: `StatusCodeError.unacceptable` with `reason` set to `nil`
    /// if `httpResponse` contains an unacceptable status code.
    func validateStatusCode() throws {
        guard hasAcceptableStatus() else {
            throw StatusCodeError(statusCode)
        }
    }
}

public extension DecodedResult {
    var errrorStatusCode: Int? {
        return (error as? StatusCodeError)?.code
    }
}

/// Encapsulates the result produced by a `URLSession`s
/// `completionHandler` block.
///
/// Mainly used by `Session` and `Client` to simplify the passing of
/// parameters.
public struct URLSessionTaskResult {
    public var response: URLResponse?
    public var data: Data?
    public var error: Error?

    public init(response: URLResponse?=nil, data: Data?=nil, error: Error?=nil) {
        self.response = response
        self.data = data
        self.error = error
    }
}

public protocol URLResponseHolder {
    var response: URLResponse? { get }
}

extension URLResponseHolder {
    /// Returns `response` cast to `HTTPURLResponse`.
    public var httpResponse: HTTPURLResponse? {
        return response as? HTTPURLResponse
    }
}

extension URLSessionTaskResult: URLResponseHolder {}
extension URLSessionTask: URLResponseHolder {}
