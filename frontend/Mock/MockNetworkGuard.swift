import Foundation

/// Defense in depth for URLSession consumers. Mock services only read bundle/file URLs.
final class MockNetworkGuard: URLProtocol {
  static func install() { URLProtocol.registerClass(MockNetworkGuard.self) }
  override class func canInit(with request: URLRequest) -> Bool {
    ["http", "https"].contains(request.url?.scheme?.lowercased() ?? "")
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
  }
  override func stopLoading() { }
}
