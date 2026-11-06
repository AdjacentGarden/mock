# DeepSeek 学习助手

普通启动使用真实 `deepseek-flash`，通过官方 `https://api.deepseek.com/chat/completions` 提交对话与函数工具清单。`thinking.type=disabled`、非流式响应，等待时保留现有助手 loading 和工具执行状态。PDF、课程、习题与媒体流程继续使用 Mock，不依赖业务后端。

## 本机配置

在「我的 → 设置 → AI模型与工具」保存密钥并测试连接。连接测试只发送 hello。密钥保存在 iOS Keychain，service 为 `com.adjacentgarden.cloudpath.mock.live-ai`、account 为 `deepseek`。可在设置中清除。不会显示已保存的原文密钥。

开发和自动验收可使用 `BOOKCOURSE_DEEPSEEK_API_KEY` 环境变量。也可在安装后，将不进入版本控制的本机 JSON（字段 `api_key`）放入该 App Documents 下的 `.deepseek-setup.json`。App 在启动时将其导入专属 Keychain，并立即删除该文件。不要把密钥放入 Swift、工程资源、脚本参数、截图、测试结果或仓库文件。

## 工具与持久化

| 工具 | 行为 |
| --- | --- |
| `list_courses` | 读取已保存课程、教材与章节 ID |
| `read_current_lesson` | 读取当前冻结课程/章节的本机学习内容 |
| `list_notes` / `read_note` | 列出或读取本机课程笔记及版本 |
| `create_note` | 保存课程笔记，可从对话打开 |
| `update_note` | 按版本更新已有笔记 |
| `create_flashcards` | 保存闪卡并显示在相应课程 |
| `create_review_task` | 保存指定日期的复习任务 |

模型只选择工具及参数；实际读取和保存由 `LiveAssistantSkills` 在本机执行。课程、教材、章节使用发问时的冻结上下文，换页不会改变本轮保存位置。缺少课程或有多个教材时返回可选择对象，不能编造保存位置。写操作与幂等回执处于同一数据库事务，重复操作 ID 不会重复创建对象。笔记版本冲突要求重新读取。

模型工具调用、工具回执与任务最终状态持久化在 AgentRun，包含已提交的笔记 ID。后续模型失败时，已成功提交的笔记仍保留；用户看到明确错误，并可打开已保存笔记。取消会终止整轮任务和网络传输；已提交的本机事务保留。恢复前台不会自动重新请求模型，由用户明确重试。

本功能不提供照片识别、PDF 原文解析、联网搜索或真实媒体生成。AI 不能声称已经看过未提供文字的附件。当前课文来自内置 mock 资料，不能当作用户上传 PDF 的解析结果。

## 测试

```bash
python3 frontend/scripts/generate-project.py
./frontend/scripts/test.sh --device QA_SIMULATOR_UDID --unit
```

默认单元测试完全不使用真实密钥或模型。`MockAssistantTests` 明确使用固定助手；`MockDeepSeekClientTests` 和 `MockDeepSeekRuntimeTests` 注入 URLProtocol 替身验证传输、工具循环、持久化、模型失败和取消；`MockLiveSkillTests` 验证本机技能的数据与作用域。Debug UI 测试使用 `--fixture`，仍由固定助手回答。

真实模型验收 `MockDeepSeekLiveTests` 默认为跳过。仅在独立 QA 模拟器已配置 Keychain，且其 App Documents 中存在 `.enable-deepseek-live-tests` 文件时运行：

```bash
./frontend/scripts/test.sh --device QA_SIMULATOR_UDID --only BookCourseTests/MockDeepSeekLiveTests
```

该验收发送真实知识问题、创建笔记、读取并修改笔记、生成两张闪卡与复习任务，再重新打开本机数据库核对数据。验收结束删除该启用文件，避免普通测试产生真实请求。不要在用户正操作的模拟器上运行 UI 自动化。

协议参考：[DeepSeek 工具调用](https://api-docs.deepseek.com/guides/tool_calls/)、[Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion/)。
