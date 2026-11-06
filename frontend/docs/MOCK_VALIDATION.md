# Mock 验收记录

验证日期：2026-11-06（Asia/Shanghai）。

基于 LLM_Study_App 的 frontend，原始提交：`1028abd9384543c280f802ebb8a7eb298e447272`。

## 已执行

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
