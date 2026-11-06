# CloudPath · SwiftUI Mock 客户端

这里是 `AdjacentGarden/mock` 的原生 iPhone / iPad 演示前端，基于 `AdjacentGarden/LLM_Study_App` 当前的 SwiftUI 实现。**普通启动即使用纯本地 mock，Debug 与 Release 均不连接真实后端或模型。** 完整说明和演示步骤见 [根 README](../README.md)。

PDF 仅保存到设备。前端按阶段模拟上传、解析和预处理进度，使用固定演示课程生成课文、问题、闪卡、学习计划、图片与视频。生成内容与上传 PDF 正文无关，不执行 OCR 或真实 PDF 内容解析。助手也返回本地演示结果。

## 构建与运行

需要完整 Xcode、Python 3 和 iOS 17+ Simulator runtime。首次构建需要下载锁定的 Swift Package 依赖。

```bash
python3 scripts/generate-project.py
./scripts/build.sh
./scripts/run-simulator.sh --device SIMULATOR_UDID --no-build
```

或使用 Xcode 打开 `BookCourse.xcodeproj`，运行 `BookCourse` scheme。无需 `.env`、API key、验证码或开发服务地址。新增 Swift 源文件后重新运行工程生成脚本。

## 代码位置

- `Resources/Data/MockBooks/`：其余十本书/专题课的 220 节原创课程、1320 张闪卡、660 道练习。
- `Resources/Content/assets/mock-books/`：每节专属图解、6 秒讲解短片与本地示例讲义。
- `Mock/MockBookContent.swift`、`MockCatalogService.swift`：统一课程装配与旧占位数据升级。
- `Mock/`：mock 服务、统一延迟与数据映射。异步步骤通常等待 0.5–2 秒，并支持取消。
- `Resources/Data/`：预置课程、题目、闪卡、书架、社区、笔记及页面场景。
- `Resources/Content/`：随 App 打包的图片、封面、教材页和媒体资源。
- `Core/`：本地持久化、上传与准备任务、学习记录、服务适配。
- `Features/`：课程、学习、媒体、笔记、发现、助手与个人页面。
- `App/`、`DesignSystem/`：应用入口、路由、共享界面与动效。
- `Tests/MockFlowTests.swift`：无后端的 PDF → 课程 → 学习闭环集成测试。

## 流程测试

```bash
python3 scripts/validate-content.py
./scripts/test.sh --device SIMULATOR_UDID --only BookCourseTests/MockFlowTests
./scripts/test.sh --device SIMULATOR_UDID --only BookCourseUITests/MockUITests
```

测试在独立临时目录使用空白 PDF，检查可见进度、生成内容、练习反馈、闪卡、学习完成和持久化，并验证取消后可从本机原件重试。UI 烟测从「使用示例 PDF」开始，覆盖上传、课程生成、图片、视频播放与助手，并保留截图。工程只编译 `Mock*.swift` 测试，历史的真实云端用例保留源码供追溯。

固定页面场景仍可用，例如：

```bash
./scripts/run-simulator.sh --device SIMULATOR_UDID --no-build -- \
  --fixture --route lesson --chapter c2s1 --fixture-session mock-lesson
```

`--fixture-session` 使用独立目录，换一个名称即可开启新的固定演示场景。普通启动的数据会在当前安装中保留。学习内容始终来自内置样例，页面上的引用和页码也属于该样例。

`docs/`、`References/`、许可证与第三方来源文件从原项目保留以便追溯；其中的真实后端部署地址、联网说明或历史验证结论不适用于本 mock 客户端。以本文件、根 README 和 `Mock/` 的实现为准。
