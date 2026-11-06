# CloudPath · 前端 Mock 演示

本仓库基于主项目前端提交 `1028abd9384543c280f802ebb8a7eb298e447272` 构建，是 [LLM_Study_App](https://github.com/AdjacentGarden/LLM_Study_App) 的独立 mock 客户端，沿用其当前的 **SwiftUI iPhone / iPad 前端**，最低支持 iOS 17。课程演示和前端联调不需要启动后端、账号服务或 OCR 服务。AI 提问已单独接入真实 DeepSeek Flash，需要本机配置 API Key。

用户选择的 PDF 只保存在 App 本机目录。上传、解析、预处理、课程生成、练习题、图片与视频生成由前端 mock 服务完成；课程内容来自内置演示数据，不分析上传 PDF 的正文。不同 PDF 会保留各自的文件名、课程与学习记录；前端根据文件名选择对应学科的预置课程，不识别 PDF 正文。无法判断学科时使用生物演示课程。AI 提问会将对话及所需的学习上下文发送至 DeepSeek，笔记、闪卡、复习任务仍写入本机。

## 运行

需要 macOS、完整 Xcode、iOS 17 或更新的 Simulator runtime，以及 Python 3。首次构建时 Xcode 需要下载工程锁定的 Swift Package 依赖；完成构建后课程演示流程可离线使用，真实 AI 需要网络。

```bash
git clone https://github.com/AdjacentGarden/mock.git
cd mock/frontend
xcode-select -p
xcrun simctl list devices available
./scripts/build.sh --regenerate-project
./scripts/run-simulator.sh --device SIMULATOR_UDID --no-build
```

也可以直接打开 `frontend/BookCourse.xcodeproj`，选择 `BookCourse` scheme 和一个 iPhone / iPad 模拟器运行。新增 Swift 文件后先运行 `python3 frontend/scripts/generate-project.py`，同步工程中的源码清单。真机运行需自行配置 Xcode 签名团队。

普通启动的 Debug 与 Release 均使用 mock 课程和真实 AI，不需要设置业务后端地址。Debug 下的 `--fixture` 参数用于固定 UI 测试场景，此时助手也使用本地固定回答，不产生模型请求。

## 真实 AI 与本机工具

在「我的 → 设置 → AI模型与工具」填入 DeepSeek API Key 并保存，可点击「测试连接」。密钥存入此 App 专属的 iOS Keychain，不写入代码、UserDefaults 或课程数据。模型固定为 `deepseek-flash`，使用官方 HTTPS Chat Completions 接口，关闭思考模式以快速回答；除该接口外的业务 HTTP 请求仍被阻止。

助手支持多轮问答以及八个本机工具：读取课程、读取当前学习内容、列出笔记、读取笔记、创建笔记、修改笔记、创建闪卡、安排复习任务。可尝试「把当前课整理成笔记并保存」「给这份笔记生成两张闪卡」「安排今天五分钟的复习」。工具过程、成功和失败会显示在对话中，创建的对象可在对应课程的笔记、闪卡和学习计划中打开，重启后保留。

缺少密钥、余额不足或网络失败会明确报错，不会回退成演示回答。重试由用户发起；App 不会自动点击或自动重放模型请求。AI 读取的是本机 mock 学习资料，不代表解析了用户 PDF；此接口不提供照片识别、OCR 或视频理解。照片笔记与语音整理继续使用本地 mock。

配置与测试细节见 [DeepSeek 接入说明](frontend/docs/DEEPSEEK.md)。

## 演示步骤

1. 打开「学习」，点击「创建课程」，选择任意 PDF，也可点击「使用示例 PDF」快速开始。查看每个文件的上传进度，也可取消后重试，或转到后台继续操作。
2. 上传成功后点击「继续整理」，观察解析、目录整理与预处理阶段，完成后进入课程设置。
3. 填写课程学习偏好，确认目录，点击「确认生成课程」。生成中显示 loading，完成后可以开始学习。
4. 打开章节，查看导学、讲解与知识点；打开问题或练习，提交答案查看反馈；翻转闪卡并标记熟悉程度。
5. 在章节的图片、视频入口发起生成，观察加载状态，完成后查看内置图片或播放本地演示视频。可以重新打开已生成结果。
6. 使用「问问 AI」、笔记、学习计划等入口演示后续交互；学习进度和个人记录保存在当前设备，重新启动后可继续。

「发现」和「我的」保留内置演示内容。账号、云端同步和生成结果均为本地模拟；页面中的教材引用属于演示课程，不代表从用户上传的 PDF 中提取。

## 完整课程内容

其余书籍和专题课采用与生物课程一致的教学结构。每节包含导读、四段图文讲解（概念、图解、辨析、应用）、六张闪卡、判断/选择/简答各一道题、学习/练习/复习计划，以及本节专属图解、6 秒本地短片和可打开的示例讲义。

| 书籍或专题课 | 课时 | 闪卡 | 练习 |
| --- | ---: | ---: | ---: |
| 数学 必修第二册 | 43 | 258 | 129 |
| 物理 必修第三册 | 25 | 150 | 75 |
| 化学 必修第二册 | 26 | 156 | 78 |
| 英语 必修第三册 | 50 | 300 | 150 |
| 高等数学 上册 | 51 | 306 | 153 |
| 理论力学 I | 7 | 42 | 21 |
| 微表情·微动作·微反应套装 | 9 | 54 | 27 |
| 生态系统与稳态 | 3 | 18 | 9 |
| 力与运动 | 3 | 18 | 9 |
| 函数与导数 | 3 | 18 | 9 |
| **合计（不含原生物课程）** | **220** | **1320** | **660** |

原有目录节点保持不变；心理套装按三卷分组提供九节原创 mock 课程。所有课程内容均为预先编写的演示材料，引用入口打开本地示例讲义，不冒充未提供的教材扫描页。照片/语音笔记、媒体及 fixture 助手使用当前课程的内容，不再借用生物讲解；普通助手由 DeepSeek 按提问和工具读取结果回答。已有通用占位课程会在启动时升级，学习位置、任务完成状态和闪卡熟悉度保留。

内容位于 `frontend/Resources/Data/MockBooks/`，媒体位于 `frontend/Resources/Content/assets/mock-books/`。修改对应生成脚本后可以重新生成内容和媒体：

```bash
cd frontend
python3 scripts/generate-extra-mock-sources.py
python3 scripts/generate-math-mock.py
python3 scripts/generate-science-mock.py
python3 scripts/generate-english-mock.py
python3 scripts/generate-psychology-mock.py
# 以下只在维护媒体素材时需要；App 运行不需要 Python 或 FFmpeg。
python3 -m venv .build/mock-media-env
.build/mock-media-env/bin/pip install -r scripts/requirements-mock-media.txt
.build/mock-media-env/bin/python scripts/render-mock-book-media.py
python3 scripts/validate-mock-books.py
```

## Mock 组织

| 位置 | 职责 |
| --- | --- |
| `frontend/Mock/` | 统一的 mock 环境、延迟、课程、媒体与助手服务；替换真实服务时的主要接入边界 |
| `frontend/Mock/MockCourseService.swift` | 将内置课程映射到当前上传资料的 ID、文件名和目录，准备课文、练习、闪卡与计划 |
| `frontend/Resources/Data/` | 课程、书架、社区、示例笔记等预置数据 |
| `frontend/Resources/Content/` | 本地封面、图示、教材页与视频等演示素材 |
| `frontend/Core/CourseUploadCoordinator.swift` | 选择文件、本机保存、上传进度、取消和重试的界面状态 |
| `frontend/Core/FeatureStates.swift` | 教材准备任务及其进度状态 |
| `frontend/Core/CloudAPI.swift` | 阻止 mock 客户端配置和调用真实后端 |
| `frontend/Core/DeepSeekClient.swift` | 专属 Keychain 配置与真实 DeepSeek 模型传输 |
| `frontend/Core/LiveAssistantSkills.swift` | 统一工具清单、本机笔记/闪卡/复习任务读写与操作回执 |
| `frontend/Core/AgentRuntime.swift` | 真实模型与本机工具循环、加载/取消/错误与持久化 |
| `frontend/Tests/MockFlowTests.swift` | 从空白 PDF 到课程、练习、复习与持久化的流程集成测试 |

异步阶段使用统一延迟工具，单次操作或单个阶段通常为 0.5–2 秒。上传进度分多次更新；预处理与课程生成按阶段完成，因此整个流程会持续数秒。等待使用可取消的异步任务，不阻塞界面。页面在等待期间保留 loading / 进度提示，完成后切换到结果。

## 验证

全书升级及 DeepSeek 接入已通过构建验证；40 项离线单元/集成测试、单独启用的真实模型综合验收均通过，详见 [验收记录](frontend/docs/MOCK_VALIDATION.md)。

```bash
cd frontend
python3 scripts/validate-content.py
./scripts/test.sh --device SIMULATOR_UDID --only BookCourseTests/MockFlowTests
./scripts/test.sh --device SIMULATOR_UDID --only BookCourseUITests/MockUITests
```

`MockFlowTests` 使用没有正文的空白 PDF 验证上传、预处理、目录确认、课程生成、练习反馈、闪卡、学习完成、重开后的本地记录，以及取消上传后的重试。`MockUITests` 通过「使用示例 PDF」运行同一上传流程，再检查问卷、生成状态、图片、视频播放和助手回复；UI 测试截图保留在 XCTest 结果中。工程只编译 `Mock*.swift` 验收用例，原项目的联网测试源码保留供追溯。实际运行结果以本次构建与测试输出为准；迁入的 `References/` 和历史文档不是本仓库的验收记录。

未来接真实接口时，应提供与 mock 服务相同职责的真实实现，再显式替换依赖与网络配置。演示仓库保持 mock 为默认实现，不通过网络失败后的回退来模拟成功。
