import Foundation
import XCTest
@testable import BookCourse

private final class MockRequestTrap: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var requests = 0
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.requests += 1
    client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
  }
  override func stopLoading() { }
}

@MainActor final class MockNetworkTests: XCTestCase {
  func testExplicitCloudAdapterCannotIssueAnyRequest() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockRequestTrap.self]
    MockRequestTrap.requests = 0
    let api = CloudAPI(baseURL: URL(string: "https://backend.invalid")!, session: URLSession(configuration: configuration))
    do {
      let _: CloudOK = try await api.request("/api/health")
      XCTFail("Mock mode must reject the real transport")
    } catch { XCTAssertTrue(error.localizedDescription.contains("Mock")) }
    XCTAssertEqual(MockRequestTrap.requests, 0)
    XCTAssertNil(CloudAPI.configured())
  }

  func testBackgroundUploadIsRejectedBeforeOpeningTheFileOrNetwork() async throws {
    let client = BackgroundUploadTransport.client(origin: URL(string: "https://backend.invalid")!, scope: "mock-test")
    do {
      _ = try await client.upload(URLRequest(url: URL(string: "https://backend.invalid/api/upload")!),
        file: URL(fileURLWithPath: "/nonexistent/mock.pdf"), id: UUID()) { _, _ in }
      XCTFail("Mock mode must reject the background transport")
    } catch { XCTAssertTrue(error.localizedDescription.contains("Mock")) }
  }
}
