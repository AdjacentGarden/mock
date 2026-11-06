import Foundation
import XCTest
@testable import BookCourse

/// All traffic is intercepted by a per-session stub; these tests never read the Keychain.
final class MockDeepSeekClientTests: XCTestCase {
  private let fakeKey = "test-only-deepseek-key-never-a-real-credential"
  private let messages: [[String: JSONValue]] = [
    ["role": .string("user"), "content": .string("解释这个概念")]
  ]

  func testPinnedModelAndFunctionSchemaAreSentWithCompleteToolHistory() async throws {
    let schema: [String: JSONValue] = [
      "type": .string("function"),
      "function": .object([
        "name": .string("search_textbook"), "description": .string("搜索本机教材"),
        "parameters": .object([
          "type": .string("object"),
          "properties": .object(["query": .object(["type": .string("string")])]),
          "required": .array([.string("query")]),
          "additionalProperties": .bool(false),
        ]),
      ]),
    ]
    let history: [[String: JSONValue]] = [
      ["role": .string("system"), "content": .string("根据本机资料回答。")],
      messages[0],
      ["role": .string("assistant"), "content": .null, "tool_calls": .array([
        .object([
          "id": .string("call-history"), "type": .string("function"),
          "function": .object([
            "name": .string("search_textbook"), "arguments": .string("{\"query\":\"细胞\"}")
          ]),
        ])
      ])],
      ["role": .string("tool"), "tool_call_id": .string("call-history"),
        "content": .string("细胞是生物体结构和功能的基本单位。")],
    ]
    let fixture = try DeepSeekTransportFixture(
      data: reply(content: .string("这是根据资料生成的回答。"), reasoning: "optional reasoning"))
    defer { fixture.finish() }
    let result = try await DeepSeekClient(apiKey: fakeKey, session: fixture.session)
      .complete(messages: history, tools: [schema])

    let request = try XCTUnwrap(fixture.stub.requests.first)
    let body = try JSONDecoder().decode(
      [String: JSONValue].self, from: XCTUnwrap(fixture.stub.bodies.first))
    XCTAssertEqual(fixture.stub.requests.count, 1)
    XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/chat/completions")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(fakeKey)")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(body["model"], .string("deepseek-flash"))
    XCTAssertEqual(body["thinking"], .object(["type": .string("disabled")]))
    XCTAssertEqual(body["stream"], .bool(false))
    XCTAssertEqual(body["max_tokens"], .number(4096))
    XCTAssertEqual(body["messages"], .array(history.map { .object($0) }))
    XCTAssertEqual(body["tools"], .array([.object(schema)]))
    XCTAssertEqual(result.content, "这是根据资料生成的回答。")
    XCTAssertEqual(result.reasoningContent, "optional reasoning")
    XCTAssertTrue(result.toolCalls.isEmpty)
  }

  func testNullableContentAndMultipleToolCallsDecodeWithoutChangingIDsOrArguments() async throws {
    let calls: [JSONValue] = [
      toolCall(id: "call-1", name: "search_textbook", arguments: "{\"query\":\"细胞\",\"limit\":3}"),
      toolCall(id: "call-2", name: "save_note", arguments: "{\"title\":\"重点\",\"tags\":[\"复习\"],\"pinned\":true,\"anchor\":null}"),
    ]
    let fixture = try DeepSeekTransportFixture(data: reply(content: .null, calls: calls))
    defer { fixture.finish() }
    let result = try await DeepSeekClient(apiKey: fakeKey, session: fixture.session)
      .complete(messages: messages, tools: [])

    XCTAssertEqual(result.content, "")
    XCTAssertNil(result.reasoningContent)
    XCTAssertEqual(result.toolCalls, [
      DeepSeekToolCall(id: "call-1", name: "search_textbook", arguments: [
        "query": .string("细胞"), "limit": .number(3),
      ]),
      DeepSeekToolCall(id: "call-2", name: "save_note", arguments: [
        "title": .string("重点"), "tags": .array([.string("复习")]),
        "pinned": .bool(true), "anchor": .null,
      ]),
    ])
    let body = try JSONDecoder().decode(
      [String: JSONValue].self, from: XCTUnwrap(fixture.stub.bodies.first))
    XCTAssertNil(body["tools"], "No empty tools array should be sent for a plain completion")
  }

  func testHTTPAuthenticationAndRateLimitErrorsDoNotEchoProviderBodyOrCredential() async throws {
    for code in [401, 429] {
      let marker = "provider-raw-secret-error"
      let raw: [String: JSONValue] = [
        "error": .object(["message": .string("\(marker): \(fakeKey)")])
      ]
      let fixture = try DeepSeekTransportFixture(status: code, data: JSONEncoder().encode(raw))
      defer { fixture.finish() }
      do {
        _ = try await DeepSeekClient(apiKey: fakeKey, session: fixture.session)
          .complete(messages: messages, tools: [])
        XCTFail("HTTP \(code) must fail without a mock response")
      } catch let error as DeepSeekError {
        XCTAssertEqual(error, .http(code))
        XCTAssertFalse(error.localizedDescription.contains(fakeKey))
        XCTAssertFalse(error.localizedDescription.contains(marker))
        XCTAssertFalse(String(describing: error).contains(fakeKey))
        XCTAssertFalse(error.localizedDescription.isEmpty)
      } catch {
        XCTFail("Expected a typed DeepSeek HTTP error")
      }
      XCTAssertEqual(fixture.stub.requests.count, 1, "HTTP failure must not trigger fallback or retry")
    }
  }

  func testMalformedOrNonObjectToolArgumentsFailBeforeAnyToolCanRun() async throws {
    for arguments in ["{\"title\":", "[]", "\"wrong\"", "null"] {
      let fixture = try DeepSeekTransportFixture(data: reply(content: .null, calls: [
        toolCall(id: "invalid-call", name: "save_note", arguments: arguments)
      ]))
      defer { fixture.finish() }
      do {
        _ = try await DeepSeekClient(apiKey: fakeKey, session: fixture.session)
          .complete(messages: messages, tools: [])
        XCTFail("Malformed function arguments must not be accepted")
      } catch let error as DeepSeekError {
        XCTAssertEqual(error, .invalidToolArguments)
      } catch {
        XCTFail("Expected a typed malformed-tool-arguments error")
      }
    }
  }

  func testCancellingAnInFlightRequestPropagatesCancellationAndStopsTransport() async throws {
    let fixture = try DeepSeekTransportFixture(data: nil)
    defer { fixture.finish() }
    let client = DeepSeekClient(apiKey: fakeKey, session: fixture.session)
    let task = Task { try await client.complete(messages: messages, tools: []) }
    await fulfillment(of: [fixture.stub.started], timeout: 2)
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("A cancelled completion must not return text")
    } catch is CancellationError {
      // The public contract preserves structured cancellation, rather than a connection error.
    } catch {
      XCTFail("Cancellation must remain CancellationError")
    }
    await fulfillment(of: [fixture.stub.stopped], timeout: 2)
    XCTAssertEqual(fixture.stub.requests.count, 1)
  }

  func testGuardAllowsOnlyTheExactHTTPSPostEndpoint() {
    for url in ["https://api.deepseek.com/chat/completions", "https://api.deepseek.com:443/chat/completions"] {
      var request = URLRequest(url: URL(string: url)!)
      request.httpMethod = "POST"
      XCTAssertFalse(MockNetworkGuard.canInit(with: request))
    }
    for url in [
      "http://api.deepseek.com/chat/completions", "https://example.com/chat/completions",
      "https://api.deepseek.com/models", "https://api.deepseek.com/chat/completions/",
      "https://api.deepseek.com/chat/completions?extra=1", "https://api.deepseek.com/chat/completions#fragment",
      "https://api.deepseek.com:8443/chat/completions", "https://user@api.deepseek.com/chat/completions",
      "https://api.deepseek.com/chat/%63ompletions",
    ] {
      var request = URLRequest(url: URL(string: url)!)
      request.httpMethod = "POST"
      XCTAssertTrue(MockNetworkGuard.canInit(with: request), url)
    }
    let get = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
    XCTAssertTrue(MockNetworkGuard.canInit(with: get))
  }

  private func reply(content: JSONValue, calls: [JSONValue] = [], reasoning: String? = nil) throws -> Data {
    var message: [String: JSONValue] = ["role": .string("assistant"), "content": content]
    if !calls.isEmpty { message["tool_calls"] = .array(calls) }
    if let reasoning { message["reasoning_content"] = .string(reasoning) }
    return try JSONEncoder().encode(["choices": JSONValue.array([
      .object(["message": .object(message), "finish_reason": .string(calls.isEmpty ? "stop" : "tool_calls")])
    ])])
  }

  private func toolCall(id: String, name: String, arguments: String) -> JSONValue {
    .object([
      "id": .string(id), "type": .string("function"),
      "function": .object(["name": .string(name), "arguments": .string(arguments)]),
    ])
  }
}

private final class DeepSeekTransportFixture {
  let session: URLSession
  let stub: DeepSeekTransportStub
  private let id: String

  init(status: Int = 200, data: Data?) throws {
    let identifier = UUID().uuidString
    let responseStub = DeepSeekTransportStub(status: status, data: data)
    id = identifier
    stub = responseStub
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DeepSeekStubProtocol.self]
    configuration.httpAdditionalHeaders = ["X-DeepSeek-Test-ID": identifier]
    configuration.timeoutIntervalForRequest = 3
    session = URLSession(configuration: configuration)
    DeepSeekStubProtocol.register(responseStub, id: identifier)
  }

  func finish() {
    session.invalidateAndCancel()
    DeepSeekStubProtocol.unregister(id: id)
  }
}

private final class DeepSeekTransportStub: @unchecked Sendable {
  let status: Int
  let data: Data?
  let started = XCTestExpectation(description: "stub request starts")
  let stopped = XCTestExpectation(description: "stub request stops")
  private let lock = NSLock()
  private var recordedRequests: [URLRequest] = []
  private var recordedBodies: [Data] = []

  init(status: Int, data: Data?) { self.status = status; self.data = data }

  var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return recordedRequests }
  var bodies: [Data] { lock.lock(); defer { lock.unlock() }; return recordedBodies }

  func record(_ request: URLRequest) {
    let body: Data
    if let bytes = request.httpBody {
      body = bytes
    } else if let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var bytes = Data()
      var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count > 0 else { break }
        bytes.append(contentsOf: buffer.prefix(count))
      }
      body = bytes
    } else { body = Data() }
    lock.lock()
    recordedRequests.append(request)
    recordedBodies.append(body)
    lock.unlock()
    started.fulfill()
  }
}

private final class DeepSeekStubProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  private static var stubs: [String: DeepSeekTransportStub] = [:]
  private var activeStub: DeepSeekTransportStub?

  static func register(_ stub: DeepSeekTransportStub, id: String) {
    lock.lock(); defer { lock.unlock() }; stubs[id] = stub
  }
  static func unregister(id: String) { lock.lock(); defer { lock.unlock() }; stubs[id] = nil }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.lock.lock()
    let stub = request.value(forHTTPHeaderField: "X-DeepSeek-Test-ID").flatMap { Self.stubs[$0] }
    Self.lock.unlock()
    guard let stub, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    activeStub = stub
    stub.record(request)
    guard let data = stub.data else { return } // Stall until cancellation; never open a socket.
    guard let response = HTTPURLResponse(
      url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() { activeStub?.stopped.fulfill() }
}
