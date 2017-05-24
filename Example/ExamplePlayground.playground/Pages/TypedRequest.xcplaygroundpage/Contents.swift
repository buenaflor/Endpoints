import UIKit
import PlaygroundSupport
import Endpoints
import ExampleCore
import Unbox
PlaygroundPage.current.needsIndefiniteExecution = true

struct RandomImage: ResponseParser {
    var url: URL
    
    static func parse(data: Data, encoding: String.Encoding) throws -> RandomImage {
        let dict = try [String: Any].parse(data: data, encoding: encoding)
        
        guard let data = dict["data"] as? [String : Any], let url = data["image_url"] as? String else {
            throw DecodingError.missingData
        }
        
        return RandomImage(url: URL(string: url)!)
    }
}

struct RandomCall: Call {
    typealias ResponseType = RandomImage
    
    var tag: String
    
    var request: URLRequestEncodable {
        return Request(.get, "gifs/random", query: [ "tag": tag, "api_key": "dc6zaTOxFJmzC" ])
    }
}

let client = AnyClient(baseURL: URL(string: "https://api.giphy.com/v1/")!)
let call = RandomCall(tag: "cat")
let session = Session(with: client)

session.start(call: call) { result in
    result.onSuccess { value in
        let url = value.url
        print("image url: \(url)")
    }
    
    PlaygroundPage.current.finishExecution()
}