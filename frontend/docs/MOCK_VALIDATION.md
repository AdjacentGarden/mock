# Mock 验收记录

验证日期：2026-11-06（Asia/Shanghai）。

基于 LLM_Study_App 的 frontend，原始提交：`1028abd9384543c280f802ebb8a7eb298e447272`。

## 初始版本已执行

- Debug iOS Simulator 构建通过。
- Release arm64 iOS Simulator 构建通过。
- 19 项 mock 单元/集成测试通过：空白 PDF 上传与预处理、课程生成、添加资料保留旧课文和进度、题目反馈、闪卡、持久化、取消重试、目录型课程、助手与笔记、媒体播放/历史/会话隔离、真实网络传输阻断。
- 4 项 UI 测试通过：PDF → 课程完整流程；图片与视频生成、播放及重开；助手、发现、个人页；不带 `--fixture` 的普通启动和个性化引导。
- 普通启动用例注入不可用的真实服务地址，仍可完成本地引导并进入学习页。
- 图片/视频结果使用随应用打包的文件；视频可播放性和播放进度均已验证。

测试设备为独立的 iPhone 17 Pro 模拟器，iOS 26.5。没有使用真实后端、模型服务或账号凭据。

## 复现

```bash
cd frontend
python3 scripts/generate-project.py
./scripts/build.sh
./scripts/test.sh --device SIMULATOR_UDID --all
./scripts/build.sh --configuration Release \
  --destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -- ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
```

工程只编译 `Mock*.swift` 测试。保留的生产云协议测试不属于本 mock 仓库的测试集合。

本次没有验证真机或 iOS 17 运行时。PDF 业务流程不提取正文；演示课程、练习、图像、视频和助手回复均为本地预置内容。语音使用本地模拟录音和预设转写，不采集麦克风。

## 全书内容升级

2026-11-06：保留生物课程，补齐其余 10 本书/专题课，共 220 节、880 段讲解、1320 张闪卡、660 道练习，以及各 220 份图解、6 秒短片和本地示例讲义。

- 所有目录节点、数据归属、四段教学结构、六卡三题、正确选项、非空解析和媒体文件均通过全量校验。
- 23 项单元/集成用例通过，包括新增的所有书籍首尾章节阅读、答题、熟悉度记录、讲义跳转、旧占位数据升级、题目与助手的学科一致性，以及各书视频可播放性。
- Debug、Release arm64 Simulator 构建通过；Release 也启用完整本地书库。
- 新内容在独立 QA 模拟器验证，本轮没有在用户手动使用的模拟器上执行 UI 自动点击。
- 旧课程的书籍、章节和课时 ID 保持稳定，已完成任务与闪卡熟悉度随升级保留。

新增验收入口：`python3 scripts/validate-mock-books.py` 和 `BookCourseTests/MockBookContentTests`。
