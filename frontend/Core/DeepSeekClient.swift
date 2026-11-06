import Foundation
import Security

/// The only live service in the mock app. Credentials belong to this app alone.
enum LiveAssistantConfiguration {
  static let model = "deepseek-flash"
  static let baseURL = URL(string: "https://api.deepseek.com")!
  static let keychainService = "com.adjacentgarden.cloudpath.mock.live-ai"
  static let keychainAccount = "deepseek"
  private static let bootstrapLock = NSLock()

  static var hasEnvironmentKey: Bool { environmentKey != nil }
  static var hasStoredKey: Bool {
    try? importLocalBootstrapIfPresent()
    return storedKey != nil
  }
  static var hasKey: Bool { apiKey != nil }
  static var apiKey: String? {
    try? importLocalBootstrapIfPresent()
    return environmentKey ?? storedKey
  }

  /// One-time local simulator setup. This file is never bundled or sent to a service.
  static func importLocalBootstrapIfPresent() throws {
    bootstrapLock.lock()
    defer { bootstrapLock.unlock() }
    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return }
    let file = documents.appendingPathComponent(".deepseek-setup.json")
    guard FileManager.default.fileExists(atPath: file.path) else { return }
    let setup: LocalBootstrap
    do { setup = try JSONDecoder().decode(LocalBootstrap.self, from: Data(contentsOf: file)) }
    catch { throw DeepSeekError.localSetup }
    try saveKey(setup.api_key)
    do { try FileManager.default.removeItem(at: file) }
    catch { throw DeepSeekError.localSetup }
  }

  static func saveKey(_ key: String) throws {
    let value = try validatedKey(key)
    let attributes: [String: Any] = [
      kSecValueData as String: Data(value.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    var status = SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(keychainQuery.merging(attributes) { _, value in value } as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw DeepSeekError.keychain(status) }
  }

  static func clearKey() throws {
    let status = SecItemDelete(keychainQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw DeepSeekError.keychain(status)
    }
  }

  fileprivate static func validatedKey(_ key: String) throws -> String {
    let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty,
      value.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 })
    else { throw DeepSeekError.invalidKey }
    return value
  }

  private static var keychainQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecAttrSynchronizable as String: false,
    ]
  }

  private static var environmentKey: String? {
    guard let value = ProcessInfo.processInfo.environment["BOOKCOURSE_DEEPSEEK_API_KEY"] else {
      return nil
    }
    return try? validatedKey(value)
  }

  private static var storedKey: String? {
    var query = keychainQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data, let value = String(data: data, encoding: .utf8)
    else { return nil }
    return try? validatedKey(value)
  }

  private struct LocalBootstrap: Decodable {
    var api_key: String
  }
}

struct DeepSeekToolCall: Sendable, Equatable {
  var id: String
  var name: String
  var arguments: [String: JSONValue]
}

struct DeepSeekMessage: Sendable, Equatable {
  var content: String
  var toolCalls: [DeepSeekToolCall]
  var reasoningContent: String?
}

/// Error descriptions never include request headers, credentials, or raw provider responses.
enum DeepSeekError: LocalizedError, Equatable {
  case missingKey
  case invalidKey
  case keychain(OSStatus)
  case localSetup
  case invalidRequest
  case connection(Int)
  case http(Int)
  case invalidResponse
  case invalidToolArguments
  case responseLimit

  var errorDescription: String? {
    switch self {
    case .missingKey: return "尚未配置 DeepSeek API Key，请在“设置 → AI模型与工具”中添加。"
    case .invalidKey: return "API Key 不能为空或包含空格、换行，请重新输入。"
    case .keychain(let status): return "无法更新本机钥匙串（\(status)），请重试。"
    case .localSetup: return "无法完成本机 DeepSeek 配置导入，请在设置中重新保存 API Key。"
    case .invalidRequest: return "无法编码本次 AI 请求，请重新提问。"
    case .connection(let code):
      return code == URLError.timedOut.rawValue
        ? "DeepSeek 连接超时，请稍后重试。" : "无法连接 DeepSeek，请检查网络后重试。"
    case .http(let status):
      switch status {
      case 400, 422: return "DeepSeek 无法处理本次请求（HTTP \(status)），请重新提问。"
      case 401: return "DeepSeek API Key 无效，请在设置中更新。"
      case 402: return "DeepSeek 账户余额不足，请充值后重试。"
      case 403: return "DeepSeek 拒绝访问，请检查 API Key 权限。"
      case 404: return "DeepSeek 模型或接口暂不可用，请稍后重试。"
      case 429: return "DeepSeek 请求过于频繁，请稍后重试。"
      case 500...599: return "DeepSeek 服务暂时不可用（HTTP \(status)），请稍后重试。"
      default: return "DeepSeek 请求失败（HTTP \(status)），请稍后重试。"
      }
    case .invalidResponse: return "DeepSeek 返回了无法读取的回复，请重新提问。"
    case .invalidToolArguments: return "DeepSeek 返回的工具参数不完整，请重新提问。"
    case .responseLimit: return "DeepSeek 回复超出本次长度限制，请缩小问题后重试。"
    }
  }
}

actor DeepSeekClient {
  private let explicitAPIKey: String?
  private let session: URLSession

  init(apiKey: String? = nil, session: URLSession? = nil) {
    explicitAPIKey = apiKey
    if let session {
      self.session = session
    } else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.urlCache = nil
      configuration.httpCookieStorage = nil
      configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
      configuration.timeoutIntervalForRequest = 90
      configuration.timeoutIntervalForResource = 120
      // The guard still blocks every other backend, even for this dedicated session.
      configuration.protocolClasses = [MockNetworkGuard.self]
      self.session = URLSession(
        configuration: configuration, delegate: DeepSeekSessionDelegate(), delegateQueue: nil)
    }
  }

  func complete(messages: [[String: JSONValue]], tools: [[String: JSONValue]]) async throws
    -> DeepSeekMessage
  {
    try Task.checkCancellation()
    guard let configuredKey = explicitAPIKey ?? LiveAssistantConfiguration.apiKey else {
      throw DeepSeekError.missingKey
    }
    let key = try LiveAssistantConfiguration.validatedKey(configuredKey)
    var body: [String: JSONValue] = [
      "model": .string(LiveAssistantConfiguration.model),
      "messages": .array(messages.map { .object($0) }),
      "thinking": .object(["type": .string("disabled")]),
      "stream": .bool(false),
      "max_tokens": .number(4096),
    ]
    if !tools.isEmpty { body["tools"] = .array(tools.map { .object($0) }) }
    var request = URLRequest(
      url: LiveAssistantConfiguration.baseURL.appendingPathComponent("chat/completions"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    do { request.httpBody = try JSONEncoder().encode(body) }
    catch { throw DeepSeekError.invalidRequest }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      if Task.isCancelled || (error as? URLError)?.code == .cancelled {
        throw CancellationError()
      }
      throw DeepSeekError.connection((error as? URLError)?.errorCode ?? URLError.unknown.rawValue)
    }
    try Task.checkCancellation()
    guard let response = response as? HTTPURLResponse else { throw DeepSeekError.invalidResponse }
    guard (200..<300).contains(response.statusCode) else { throw DeepSeekError.http(response.statusCode) }

    let completion: WireCompletion
    do { completion = try JSONDecoder().decode(WireCompletion.self, from: data) }
    catch { throw DeepSeekError.invalidResponse }
    guard let choice = completion.choices.first else { throw DeepSeekError.invalidResponse }
    if choice.finish_reason == "length" { throw DeepSeekError.responseLimit }
    let toolCalls = try (choice.message.tool_calls ?? []).map { call in
      guard call.type == "function", !call.id.isEmpty, !call.function.name.isEmpty,
        let arguments = call.function.arguments.data(using: .utf8),
        let values = try? JSONDecoder().decode([String: JSONValue].self, from: arguments)
      else { throw DeepSeekError.invalidToolArguments }
      return DeepSeekToolCall(id: call.id, name: call.function.name, arguments: values)
    }
    let content = choice.message.content ?? ""
    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !toolCalls.isEmpty else {
      throw DeepSeekError.invalidResponse
    }
    try Task.checkCancellation()
    return DeepSeekMessage(
      content: content, toolCalls: toolCalls, reasoningContent: choice.message.reasoning_content)
  }

  private struct WireCompletion: Decodable {
    var choices: [Choice]
    struct Choice: Decodable {
      var message: Message
      var finish_reason: String?
    }
    struct Message: Decodable {
      var content: String?
      var tool_calls: [ToolCall]?
      var reasoning_content: String?
    }
    struct ToolCall: Decodable {
      var id: String
      var type: String
      var function: Function
    }
    struct Function: Decodable {
      var name: String
      var arguments: String
    }
  }
}

/// Never forward the credential to a redirected host or endpoint.
private final class DeepSeekSessionDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
