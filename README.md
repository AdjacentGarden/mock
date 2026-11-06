# CloudPath · 前端 Mock 演示

本仓库基于主项目前端提交 `1028abd9384543c280f802ebb8a7eb298e447272` 构建，是 [LLM_Study_App](https://github.com/AdjacentGarden/LLM_Study_App) 的独立 mock 客户端，沿用其当前的 **SwiftUI iPhone / iPad 前端**，最低支持 iOS 17。它用于演示和前端联调，不需要启动后端、配置账号服务、OCR 服务或模型密钥。

用户选择的 PDF 只保存在 App 本机目录。上传、解析、预处理、课程生成、问题回答、图片与视频生成全部由前端 mock 服务完成；课程内容来自内置演示数据，不分析上传 PDF 的正文。不同 PDF 会保留各自的文件名、课程与学习记录，但生成的学习主题使用固定样例。

## 运行

需要 macOS、完整 Xcode、iOS 17 或更新的 Simulator runtime，以及 Python 3。首次构建时 Xcode 需要下载工程锁定的 Swift Package 依赖；完成构建后演示流程可离线使用。

```bash
git clone https://github.com/AdjacentGarden/mock.git
cd mock/frontend
xcode-select -p
xcrun simctl list devices available
./scripts/build.sh --regenerate-project
./scripts/run-simulator.sh --device SIMULATOR_UDID --no-build
```

也可以直接打开 `frontend/BookCourse.xcodeproj`，选择 `BookCourse` scheme 和一个 iPhone / iPad 模拟器运行。新增 Swift 文件后先运行 `python3 frontend/scripts/generate-project.py`，同步工程中的源码清单。真机运行需自行配置 Xcode 签名团队。

普通启动即进入 mock 模式，Debug 与 Release 均不需要设置服务地址。已有的 `--fixture` 参数只用于选择固定 UI 场景，不是开启 mock 的必要条件。

## 演示步骤

1. 打开「学习」，点击「创建课程」，选择任意 PDF，也可点击「使用示例 PDF」快速开始。查看每个文件的上传进度，也可取消后重试，或转到后台继续操作。
2. 上传成功后点击「继续整理」，观察解析、目录整理与预处理阶段，完成后进入课程设置。
3. 填写课程学习偏好，确认目录，点击「确认生成课程」。生成中显示 loading，完成后可以开始学习。
4. 打开章节，查看导学、讲解与知识点；打开问题或练习，提交答案查看反馈；翻转闪卡并标记熟悉程度。
5. 在章节的图片、视频入口发起生成，观察加载状态，完成后查看内置图片或播放本地演示视频。可以重新打开已生成结果。
6. 使用「问问 AI」、笔记、学习计划等入口演示后续交互；学习进度和个人记录保存在当前设备，重新启动后可继续。

「发现」和「我的」保留内置演示内容。账号、云端同步和生成结果均为本地模拟；页面中的教材引用属于演示课程，不代表从用户上传的 PDF 中提取。

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
| `frontend/Tests/MockFlowTests.swift` | 从空白 PDF 到课程、练习、复习与持久化的流程集成测试 |

异步阶段使用统一延迟工具，单次操作或单个阶段通常为 0.5–2 秒。上传进度分多次更新；预处理与课程生成按阶段完成，因此整个流程会持续数秒。等待使用可取消的异步任务，不阻塞界面。页面在等待期间保留 loading / 进度提示，完成后切换到结果。

## 验证

本次 Debug / Release 构建、19 项集成测试和 4 项 UI 测试已通过，详见 [验收记录](frontend/docs/MOCK_VALIDATION.md)。

```bash
cd frontend
python3 scripts/validate-content.py
./scripts/test.sh --device SIMULATOR_UDID --only BookCourseTests/MockFlowTests
./scripts/test.sh --device SIMULATOR_UDID --only BookCourseUITests/MockUITests
```

`MockFlowTests` 使用没有正文的空白 PDF 验证上传、预处理、目录确认、课程生成、练习反馈、闪卡、学习完成、重开后的本地记录，以及取消上传后的重试。`MockUITests` 通过「使用示例 PDF」运行同一上传流程，再检查问卷、生成状态、图片、视频播放和助手回复；UI 测试截图保留在 XCTest 结果中。工程只编译 `Mock*.swift` 验收用例，原项目的联网测试源码保留供追溯。实际运行结果以本次构建与测试输出为准；迁入的 `References/` 和历史文档不是本仓库的验收记录。

未来接真实接口时，应提供与 mock 服务相同职责的真实实现，再显式替换依赖与网络配置。演示仓库保持 mock 为默认实现，不通过网络失败后的回退来模拟成功。
