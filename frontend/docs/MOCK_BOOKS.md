# 全书 Mock 内容说明

课程规格与清单见[根 README](../../README.md#完整课程内容)。

所有内容在构建前预先编写并随 App 打包，运行时只模拟读取、准备和生成延迟。生物课程保留原有资源；其余书籍和专题课使用对应学科的原创课程、算例、练习与媒体。每节都有导读和四个讲解单元、六张闪卡、判断/选择/简答三题，以及学习、练习、复习三类计划任务。

`Resources/Data/MockBooks/{book_id}.json` 保存主题数据，`MockBookContent` 解码并供 `MockCatalogService`、媒体和助手共同使用。新增的书架/发现页课程目录保存在 `extra-sources.json`。图解、讲义与短片可用 `scripts/render-mock-book-media.py` 从同一份内容重新生成，单次生成结果仍保存在各会话自己的媒体目录中。

既有教材目录节点保持原 ID；心理学套装缺少原书目录，使用按三卷分组的九节原创演示目录。示例讲义明确标注为原创预置内容，引用只跳转到对应的本地讲义，不标为教材扫描原文。课程设置或未知 PDF 的默认预置仍保留；文件名可识别学科时使用匹配模板，不读取 PDF 正文。

心理学专题围绕可观察事实、情境、行为时序和澄清沟通编写，不把单个动作直接当作诚实与否的结论。相关经验边界参考了[表情与情境推断实验](https://pmc.ncbi.nlm.nih.gov/articles/PMC10948792/)和[表情识别训练与真实性判断实验](https://pmc.ncbi.nlm.nih.gov/articles/PMC8056713/)。课堂案例、对话和题目均为本项目原创演示材料。

内容生成脚本为 `generate-math-mock.py`、`generate-science-mock.py`、`generate-english-mock.py`、`generate-psychology-mock.py`，其后运行媒体生成与 `validate-mock-books.py`。App 本身不需要 Python、FFmpeg、后端或模型。
