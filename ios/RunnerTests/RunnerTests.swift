import Flutter
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testCurrentPositionPluginRejectsMissingCaptureId() {
    let plugin = CurrentPositionPlugin()
    let completed = expectation(description: "structured Flutter error")

    plugin.handle(FlutterMethodCall(methodName: "capture", arguments: [:])) { result in
      guard let error = result as? FlutterError else {
        XCTFail("Expected FlutterError, received \(String(describing: result))")
        completed.fulfill()
        return
      }
      XCTAssertEqual(error.code, "invalid")
      XCTAssertEqual(error.message, "Missing capture ID")
      XCTAssertNil(error.details)
      completed.fulfill()
    }

    wait(for: [completed], timeout: 1)
  }
}
