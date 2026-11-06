import Foundation

/// Keep the backend mock-only; the assistant's exact DeepSeek endpoint is the sole exception.
final class MockNetworkGuard: URLProtocol {
  static func install() { URLProtocol.registerClass(MockNetworkGuard.self) }
  override class func canInit(with request: URLRequest) -> Bool {
    if isLiveAssistantRequest(request) { return false }
    return ["http", "https"].contains(request.url?.scheme?.lowercased() ?? "")
  }
  static func isLiveAssistantRequest(_ request: URLRequest) -> Bool {
    guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return false }
    return components.scheme?.lowercased() == "https"
      && components.host?.lowercased() == "api.deepseek.com"
      && (components.port == nil || components.port == 443)
      && components.path == "/chat/completions"
      && components.percentEncodedPath == "/chat/completions"
      && components.user == nil && components.password == nil
      && components.query == nil && components.fragment == nil
      && request.httpMethod == "POST"
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
  }
  override func stopLoading() { }
}
