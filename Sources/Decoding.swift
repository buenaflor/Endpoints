import Foundation

public typealias ResponseDecoder<D> = (HTTPURLResponse, Data) throws -> D
public typealias ResultDecoder<D> = (URLSessionTaskResult) throws -> D

/// Used by `Call` to define the expected response type for its associated
/// request.
public protocol ResponseDecodable {
    /// Returns a type-erased `ResponseDecoder`, responsible for creating
    /// instances of this type from a `HTTPURLResponse` and corresponding
    /// body `Data`.
    static var responseDecoder: ResponseDecoder<Self> { get }
}

public extension URLSessionTaskResult {
    /// Throws `error` if not-nil.
    ///
    /// Throws 'DecodingError.missingData` if `data`
    /// or `httpResponse` is `nil`.
    ///
    /// Finally delegates decoding to the block returned by
    /// `decoder.responseDecoder()` and returns the decoded
    ///  object or rethrows a decoding error.
    func decode<D>(with responseDecoder: ResponseDecoder<D>) throws -> D {
        if let error = error {
            throw error
        }

        guard let data = data, let response = httpResponse else {
            throw DecodingError.missingData
        }

        return try responseDecoder(response, data)
    }
}


// MARK: - Decodable Support

extension Data: ResponseDecodable {
    public static var responseDecoder: ResponseDecoder<Data> {
        return { _, data in return data }
    }
}

extension String: ResponseDecodable {
    public static var responseDecoder: ResponseDecoder<String> {
        return { response, data in
            let encoding = response.stringEncoding
            if let string = String(data: data, encoding: encoding) {
                return string
            } else {
                throw DecodingError.invalidData(description: "String could not be decoded with encoding \(encoding.rawValue)")
            }
        }
    }
}

extension Array: ResponseDecodable {
    public static var responseDecoder: ResponseDecoder<[Element]> {
        return decodeJSONArray
    }

    public static func decodeJSONArray(response: HTTPURLResponse, data: Data) throws -> [Element] {
        guard let array = try JSONSerialization.jsonObject(with: data) as? [Element] else {
            throw DecodingError.invalidData(description: "JSON structure is not an Array")
        }

        return array
    }
}

extension Dictionary: ResponseDecodable {
    public static var responseDecoder: ResponseDecoder<[Key: Value]> {
        return { response, data in
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [Key: Value] else {
                throw DecodingError.invalidData(description: "JSON structure is not an Object")
            }

            return dict
        }
    }
}

// MARK: - Error

/// Describes an error that occured during decoding `Data`.
public enum DecodingError: LocalizedError {

    /// `Data` is missing.
    ///
    /// Thrown by `AnyClient.decode` when the response data is `nil`.
    case missingData

    /// `Data` is in an invalid format.
    ///
    /// Thrown by `ResponseDecoder` implementations.
    case invalidData(description: String)

    public var errorDescription: String? {
        switch self {
        case .missingData:
            return "no data"
        case .invalidData(let desc):
            return desc
        }
    }
}

// MARK: - Convenience Helper

public extension HTTPURLResponse {
    /// Returns the `textEncodingName`s corresponding `String.Encoding`
    /// or `utf8`, if this is not possible.
    var stringEncoding: String.Encoding {
        var encoding = String.Encoding.utf8
        
        if let textEncodingName = textEncodingName {
            let cfStringEncoding = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfStringEncoding))
        }
        
        return encoding
    }
}

public extension JSONSerialization {
    static func jsonObject(with data: Data) throws -> Any {
        return try jsonObject(with: data, options: .allowFragments)
    }
}
