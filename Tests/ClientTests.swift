import XCTest
@testable import Endpoints

class ClientTests: XCTestCase {
    var tester: ClientTester<AnyClient>!
    let baseURL = URL(string: "http://httpbin.org")!
    override func setUp() {
        tester = ClientTester(test: self, client: AnyClient(baseURL: baseURL))
    }

    func testTask() {
        let exp = expectation(description: "")

        let c = AnyCall<[String: Any]>(URL(string: "http://httpbin.org/get")!)
        let task = DecodingTask(call: c) { result in
            XCTAssertTrue(result.isSuccess)
            exp.fulfill()
        }
        task.debug = true
        task.start()

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testClientCall() {
        let exp = expectation(description: "")

        let c = AnyCall<Data>(Request(.get, "get"))
        let cc = ClientCall(client: tester.session.client, call: c)
        let task = DecodingTask(call: cc) { result in
            XCTAssertTrue(result.isSuccess)
            exp.fulfill()
        }
        task.debug = true
        task.start()

        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testCancellation() {
        let c = AnyCall<Data>(Request(.get, "get"))
        
        let exp = expectation(description: "")
        let task = tester.session.start(call: c) { result in
            XCTAssertTrue(result.wasCancelled)
            XCTAssertNotNil(result.error)
            XCTAssertNotNil(result.urlError)
            
            result.onError { error in
                XCTFail("was cancelled. this is not considered an error. should not be called.")
            }.onSuccess { value in
                XCTFail("was cancelled. should not be called.")
            }
            exp.fulfill()
        }
        
        task.cancel()
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testTimeoutError() {
        var urlReq = Request(.get, "delay/1").urlRequest
        urlReq.timeoutInterval = 0.5
        
        let c = AnyCall<Data>(urlReq)
        
        tester.test(call: c) { result in
            XCTAssertFalse(result.isSuccess)
            
            XCTAssertEqual(result.error?.localizedDescription, "The request timed out.")

            let error = result.error as! URLError
            XCTAssertEqual(error.code, URLError.timedOut)
        }
    }
    
    func testStatusError() {
        let c = AnyCall<Data>(Request(.get, "status/400"))
        
        let tsk = tester.test(call: c) { result in
            XCTAssertFalse(result.isSuccess)
            XCTAssertEqual(result.error?.localizedDescription, "bad request")
            
            if let error = result.error as? StatusCodeError {
                XCTAssertEqual(error.code, 400)
            } else {
                XCTFail("wrong error: \(String(describing: result.error))")
            }
        }
        XCTAssertEqual(tsk.httpResponse?.statusCode, 400)
    }
    
    func testGetData() {
        let c = AnyCall<Data>(Request(.get, "get"))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
        }
    }
    
    func testPostRawString() {
        let body = "body"
        let c = AnyCall<[String: Any]>(Request(.post, "post", header: [ "Content-Type": "raw" ], body: body))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)

            result.onSuccess { value in
                XCTAssertEqual(value["data"] as? String, body)
                
                if let headers = value["headers"] as? [String: String] {
                    XCTAssertEqual(headers["Content-Type"], "raw")
                } else {
                    XCTFail("headers not found")
                }
            }
        }
    }
    
    func testPostString() {
        //foundation urlrequest defaults to form encoding
        let body = "key=value"
        let c = AnyCall<[String: Any]>(Request(.post, "post", body: body))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)

            result.onSuccess { value in
                if let form = value["form"] as? [String: String] {
                    XCTAssertEqual(form["key"], "value")
                } else {
                    XCTFail("form not found")
                }
                
                if let headers = value["headers"] as? [String: String] {
                    XCTAssertEqual(headers["Content-Type"], "application/x-www-form-urlencoded")
                } else {
                    XCTFail("headers not found")
                }
            }
        }
    }
    
    func testPostFormEncodedBody() {
        let params = [ "key": "value" ]
        let body = FormEncodedBody(parameters: params)
        let c = AnyCall<[String: Any]>(Request(.post, "post", body: body))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
            
            result.onSuccess { value in
                if let form = value["form"] as? [String: String] {
                    XCTAssertEqual(form, params)
                } else {
                    XCTFail("form not found")
                }
                
                if let headers = value["headers"] as? [String: String] {
                    XCTAssertEqual(headers["Content-Type"], "application/x-www-form-urlencoded")
                } else {
                    XCTFail("headers not found")
                }
            }
        }
    }
    
    func testPostJSONBody() {
        let params = [ "key": "value" ]
        let body = try! JSONEncodedBody(jsonObject: params)
        let c = AnyCall<[String: Any]>(Request(.post, "post", body: body))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
            
            result.onSuccess { value in
                if let form = value["json"] as? [String: String] {
                    XCTAssertEqual(form, params)
                } else {
                    XCTFail("form not found")
                }
                
                if let headers = value["headers"] as? [String: String] {
                    XCTAssertEqual(headers["Content-Type"], "application/json")
                } else {
                    XCTFail("headers not found")
                }
            }
        }
    }
    
    func testGetString() {
        let c = AnyCall<String>(Request(.get, "get", query: [ "inputParam" : "inputParamValue" ]))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
            
            if let string = result.value {
                XCTAssertTrue(string.contains("inputParamValue"))
            }
        }
    }
    
    func testGetJSONDictionary() {
        let c = AnyCall<[String: Any]>(Request(.get, "get", query: [ "inputParam" : "inputParamValue" ]))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
            
            if let jsonDict = result.value {
                let args = jsonDict["args"]
                XCTAssertNotNil(args)
                
                if let args = args {
                    XCTAssertTrue(args is Dictionary<String, String>)
                    
                    if let args = args as? Dictionary<String, String> {
                        let param = args["inputParam"]
                        XCTAssertNotNil(param)
                        
                        if let param = param {
                            XCTAssertEqual(param, "inputParamValue")
                        }
                    }
                }
            }
        }
    }
    
    func testDecodeJSONArray() {
        let inputArray = [ "one", "two", "three" ]
        let arrayData = try! JSONSerialization.data(withJSONObject: inputArray, options: .prettyPrinted)
        let resp = FakeHTTPURLResponse(status: 200, header: nil, textEncodingName: "UTF-8")

        let decodedObject = try! [String].responseDecoder(resp, arrayData)
        
        XCTAssertEqual(inputArray, decodedObject)
    }

    func testFailStringDecoding() {
        let input = "😜 test"
        let data = input.data(using: .utf8)!
        
        do {
            let resp = FakeHTTPURLResponse(status: 200, header: nil, textEncodingName: "EUC-JP")
            let decoded = try String.responseDecoder(resp, data)
            XCTAssertEqual(decoded, input)
            XCTFail("this should actually fail")
        } catch {
            XCTAssertTrue(error is DecodingError)
            XCTAssertEqual(error.localizedDescription, "String could not be decoded with encoding 3")
        }
    }
    
    func testFailJSONDecoding() {
        let c = AnyCall<[String: Any]>(Request(.get, "xml"))
        
        tester.test(call: c) { result in
            XCTAssertFalse(result.isSuccess)

            result.onError { error in
                if let error = error as? CocoaError {
                    XCTAssertTrue(error.isPropertyListError)
                    XCTAssertEqual(error.code, CocoaError.Code.propertyListReadCorrupt)
                } else {
                    XCTFail("wrong error: \(String(describing: result.error))")
                }
            }
        }
    }
    
    struct GetOutput: Call {
        typealias DecodedType = [String: Any]
        
        let value: String
        
        var request: URLRequestEncodable {
            return Request(.get, "get", query: ["param" : value])
        }
    }
    
    func testTypedRequest() {
        let value = "value"
        
        tester.test(call: GetOutput(value: value)) { result in
            XCTAssertTrue(result.isSuccess)

            result.onSuccess { dict in
                guard let args = dict["args"] as? Dictionary<String, String> else {
                    XCTFail()
                    return
                }

                let param = args["param"]
                XCTAssertEqual(param, value)
            }
        }
    }
    
    struct ValidatingCall: Call {
        typealias DecodedType = [String: Any]
        
        var mime: String
        
        var request: URLRequestEncodable {
            return Request(.get, "response-headers", query: [ "Mime": mime ])
        }

        var resultDecoder: ResultDecoder<DecodedType> {
            return { _ in throw StatusCodeError(0) }
        }
    }
    
    class ValidatingClient: AnyClient {
        override func validate(result: URLSessionTaskResult) throws {
            throw StatusCodeError(1)
        }
    }
    
    func testClientValidation() {
        // check if call validation comes before client validation
        let client = ValidatingClient(baseURL: self.tester.session.client.baseURL)
        let tester = ClientTester(test: self, client: client)
        
        let c = AnyCall<Data>(Request(.get, "get"))
        
        tester.test(call: c) { result in
            XCTAssertFalse(result.isSuccess)
            
            guard let error = result.error as? StatusCodeError else {
                XCTFail("error expected")
                return
            }

            XCTAssertEqual(error.code, 1, "client should throw error")
        }
    }
    
    func testValidatingRequest() {
        // check if call validation comes before client validation
        let client = ValidatingClient(baseURL: self.tester.session.client.baseURL)
        let tester = ClientTester(test: self, client: client)
        
        let mime = "application/json"
        let c = ValidatingCall(mime: mime)
        
        let tsk = tester.test(call: c) { result in
            XCTAssertFalse(result.isSuccess)
            
            guard let error = result.error as? StatusCodeError else {
                XCTFail("error expected")
                return
            }

            XCTAssertEqual(error.code, 0, "request should throw error, not client")
        }

        XCTAssertEqual(tsk.httpResponse?.allHeaderFields["Mime"] as? String, mime)
    }
    
    func testBasicAuth() {
        let auth = BasicAuthorization(user: "a", password: "a")
        let c = AnyCall<Data>(Request(.get, "basic-auth/a/a", header: auth.header))
        
        tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
        }
    }
    
    func testBasicAuthFail() {
        let auth = BasicAuthorization(user: "a", password: "b")
        let c = AnyCall<Data>(Request(.get, "basic-auth/a/a", header: auth.header))
        
        tester.test(call: c) { result in
            XCTAssertFalse(result.isSuccess)
        }
    }

    func testSimpleAbsoluteURLCall() {
        let url = URL(string: "https://httpbin.org/get?q=a")!
        let c = AnyCall<Data>(url)
        
        let tsk = tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
        }
        XCTAssertEqual(tsk.httpResponse?.url, url)
    }
    
    func testSimpleRelativeURLRequestCall() {
        let url = URL(string: "get?q=a")!
        let c = AnyCall<Data>(URLRequest(url: url))
        
        let tsk = tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
        }
        XCTAssertEqual(tsk.httpResponse?.url, URL(string: url.relativeString, relativeTo: self.baseURL)?.absoluteURL)
    }
    
    func testRedirect() {
        let req = Request(.get, "/relative-redirect/2", header: ["x": "y"])
        let c = AnyCall<Data>(req)
        
        let tsk = tester.test(call: c) { result in
            XCTAssertTrue(result.isSuccess)
        }
        XCTAssertEqual(tsk.httpResponse?.url, URL(string: "get", relativeTo: self.baseURL)?.absoluteURL)
    }
}
