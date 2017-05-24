import XCTest
import Endpoints
@testable import ExampleCore

class BinClientTests: XCTestCase {
    let input = "inout"
    
    var tester: ClientTester<BinClient>!
    
    override func setUp() {
        tester = ClientTester(test: self, client: BinClient())
    }
    
    func testGetOutput() {
        tester.test(call: BinClient.GetOutput(value: input)) { result in
            XCTAssertTrue(result.isSuccess)
            
            XCTAssertEqual(self.input, result.value?.value)
        }
    }
    
    func testGetOutputFunctional() {
        tester.test(call: BinClient.getOutput(value: input)) { result in
            XCTAssertTrue(result.isSuccess)
            
            XCTAssertEqual(self.input, result.value?.value)
        }
    }
}
