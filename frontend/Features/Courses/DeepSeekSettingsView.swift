import SwiftUI

struct DeepSeekSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var keyInput = ""
  @State private var hasStoredKey = LiveAssistantConfiguration.hasStoredKey
  @State private var hasEnvironmentKey = LiveAssistantConfiguration.hasEnvironmentKey
  @State private var status: String?
  @State private var statusIsError = false
  @State private var testing = false
  @State private var testTask: Task<Void, Never>?
  @FocusState private var keyFocused: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("模型") {
          LabeledContent("服务", value: "DeepSeek")
          LabeledContent("模型", value: LiveAssistantConfiguration.model)
            .accessibilityIdentifier("ai.settings.model")
          LabeledContent("模式", value: "快速回答")
        }

        Section {
          SecureField("输入 DeepSeek API Key", text: $keyInput)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .keyboardType(.asciiCapable).privacySensitive().focused($keyFocused)
            .accessibilityLabel("DeepSeek API Key")
            .accessibilityIdentifier("ai.settings.key")
          Label(credentialStatus, systemImage: hasStoredKey || hasEnvironmentKey ? "key.fill" : "key")
            .font(DS.font(.supporting)).foregroundStyle(DS.secondary)
            .accessibilityIdentifier("ai.settings.keyStatus")
          Button("保存密钥", action: saveKey)
            .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || testing)
            .accessibilityIdentifier("ai.settings.save")
          Button("清除本机密钥", role: .destructive, action: clearKey)
            .disabled(!hasStoredKey || testing)
            .accessibilityIdentifier("ai.settings.clear")
        } header: {
          Text("API Key")
        } footer: {
          Text("密钥保存在这台设备的钥匙串中。发送提问时，对话及所需学习上下文会发送至 DeepSeek。")
        }

        Section {
          Button(action: testConnection) {
            HStack(spacing: 10) {
              if testing { ProgressView() }
              Text(testing ? "正在连接…" : "测试连接")
            }
          }
          .disabled(testing || (!hasStoredKey && !hasEnvironmentKey && keyInput.isEmpty))
          .accessibilityIdentifier("ai.settings.test")
          if testing {
            Button("取消测试") {
              testTask?.cancel()
            }.accessibilityIdentifier("ai.settings.cancelTest")
          }
          if let status {
            Text(status).font(DS.font(.supporting))
              .foregroundStyle(statusIsError ? DS.danger : DS.primary)
              .accessibilityIdentifier("ai.settings.status")
          }
        } footer: {
          Text("连接测试只发送 hello，不包含学习内容。输入了新密钥时，测试使用新密钥，点击“保存密钥”后才会保存。")
        }

        Section("助手工具") {
          Label("读取当前课程学习内容", systemImage: "doc.text.magnifyingglass")
          Label("读取与整理笔记", systemImage: "note.text")
          Label("生成闪卡与复习任务", systemImage: "chart.bar.xaxis")
          Text("助手会根据提问调用本机工具，并在对话中显示调用过程。")
            .font(DS.font(.supporting)).foregroundStyle(DS.secondary)
        }
      }
      .navigationTitle("AI模型与工具").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }.accessibilityIdentifier("ai.settings.done")
        }
      }
      .tint(DS.primary)
    }
    .onDisappear {
      testTask?.cancel()
      keyInput = ""
    }
  }

  private var credentialStatus: String {
    if hasEnvironmentKey { return "已通过运行环境配置" }
    return hasStoredKey ? "本机已保存密钥" : "尚未配置密钥"
  }

  private func refreshCredentialStatus() {
    hasStoredKey = LiveAssistantConfiguration.hasStoredKey
    hasEnvironmentKey = LiveAssistantConfiguration.hasEnvironmentKey
  }

  private func saveKey() {
    keyFocused = false
    do {
      try LiveAssistantConfiguration.saveKey(keyInput)
      keyInput = ""
      refreshCredentialStatus()
      statusIsError = false
      status = hasEnvironmentKey ? "密钥已保存。本次启动优先使用运行环境配置。" : "密钥已保存到本机钥匙串。"
    } catch {
      statusIsError = true
      status = error.localizedDescription
    }
  }

  private func clearKey() {
    keyFocused = false
    do {
      try LiveAssistantConfiguration.clearKey()
      keyInput = ""
      refreshCredentialStatus()
      statusIsError = false
      status = hasEnvironmentKey ? "本机密钥已清除。运行环境配置仍有效。" : "本机密钥已清除。"
    } catch {
      statusIsError = true
      status = error.localizedDescription
    }
  }

  private func testConnection() {
    keyFocused = false
    testTask?.cancel()
    testing = true
    status = nil
    statusIsError = false
    let draft = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    testTask = Task { @MainActor in
      defer { testing = false; testTask = nil }
      do {
        let client = DeepSeekClient(apiKey: draft.isEmpty ? nil : draft)
        _ = try await client.complete(
          messages: [["role": .string("user"), "content": .string("hello")]], tools: [])
        try Task.checkCancellation()
        status = "连接成功，DeepSeek Flash 已响应。"
      } catch is CancellationError {
        status = "测试已取消。"
      } catch {
        statusIsError = true
        status = error.localizedDescription
      }
    }
  }
}
