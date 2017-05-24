import UIKit
import PlaygroundSupport
import Endpoints
import ExampleCore
import Unbox
PlaygroundPage.current.needsIndefiniteExecution = true

struct RandomImage: ResponseDecodable {
    var url: URL

    static func responseDecoder() -> AnyResponseDecoder<RandomImage> {
        return AnyResponseDecoder(Decoder())
    }

    class Decoder: ResponseDecoder {
        func decode(response: HTTPURLResponse, data: Data) throws -> RandomImage {
            let dict = try [String: Any].responseDecoder().decode(response: response, data: data)

            guard let data = dict["data"] as? [String : Any], let url = data["image_url"] as? String else {
                throw DecodingError.invalidData(description: "invalid response. url not found")
            }

            return RandomImage(url: URL(string: url)!)
        }
    }
}

let client = AnyClient(baseURL: URL(string: "https://api.giphy.com/v1/")!)
let call = AnyCall<RandomImage>(Request(.get, "gifs/random", query: [ "tag": "cat", "api_key": "dc6zaTOxFJmzC" ]))
let session = Session(with: client)
session.debug = true
session.start(call: call) { result in
    result.onSuccess { value in
        let url = value.url
        print("image url: \(url)")
    }
    
    PlaygroundPage.current.finishExecution()
}
