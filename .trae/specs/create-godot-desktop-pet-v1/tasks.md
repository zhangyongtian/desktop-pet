# Tasks
- [x] Task 1: 明确 v1 技术选型与目录结构
  - [x] 确定 Godot 版本（优先 LTS）与脚本语言（GDScript）
  - [x] 约定工程目录（Godot 工程、Windows Helper、安装器脚本）与产物目录
  - [x] 定义运行时数据目录：按 Windows 标准（AppData / user://）

- [x] Task 2: 创建 Godot 桌宠最小可运行壳
  - [x] 建立 Godot 项目与基础场景
  - [x] 实现动画状态机骨架：闲置/忙碌/休息/睡觉/互动
  - [x] 实现点击宠物弹出面板入口（作为任务与输入入口）

- [x] Task 3: 任务管理 v1
  - [x] 任务数据模型：Todo/Done/Archived（Done 可隐藏但保留）
  - [x] 任务 UI：新增/勾选完成/查看隐藏项
  - [x] 将任务事件写入记忆流水（用于报表）

- [x] Task 4: 记忆流水 v1（本地存储）
  - [x] 定义事件模型：timestamp、source（clipboard/typing/manual/task）、text、metadata（可选）
  - [x] 实现本地持久化（优先 SQLite；如先行可用 JSONL 过渡）
  - [x] 实现短期原文缓冲区与长期精华存储区

- [x] Task 5: 剪贴板采集 v1
  - [x] 实现 Windows 剪贴板监听并将文本写入记忆流水
  - [x] 验证：复制/剪切/粘贴后可产生事件

- [x] Task 6: 全局打字采集 v1（Windows Helper）
  - [x] 选定 Helper 技术栈（Rust/C++/C# 其一）并实现常驻进程
  - [x] 实现全局输入监听并以片段形式输出文本事件（允许 IME 噪声）
  - [x] 与 Godot 进程通信（本地 HTTP/WebSocket/NamedPipe 其一）
  - [x] 安全护栏：暂停/恢复/紧急停止（至少支持从桌宠 UI 触发）

- [x] Task 7: 分段总结与淡忘机制 v1（DeepSeek）
  - [x] 定义触发阈值（时间/字数）与冷却策略
  - [x] 实现“原文→总结→写入精华→删除原文”的流水线
  - [x] 提示词：Report 模式（专业模板、禁止胡编）与 Chat 模式（人设陪聊/安慰）

- [x] Task 8: 报表生成 v1（专业化）
  - [x] 日报模板与生成入口
  - [x] 周报/月报/半年报模板与生成入口
  - [x] 验证：内容条目化、结果导向、尽量量化、无依据时不编造

- [x] Task 9: 新闻陪聊与情绪安慰 v1
  - [x] 新闻话题生成：陪聊为主，不要求出处链接
  - [x] 情绪信号识别与安慰/激励：带冷却时间，避免打扰
  - [x] 人设文案：路飞式（傲气/热血/吐槽但不冒犯）

- [x] Task 10: 配置与安全 v1
  - [x] DeepSeek 配置录入与保存（endpoint/model/key）
  - [x] 确保不在日志/文档/代码中输出明文密钥
  - [x] 用户称呼设置与持久化

- [x] Task 11: Windows 安装包 v1（Inno Setup）
  - [x] 安装向导：可选择安装目录
  - [x] 可选自启任务（默认不勾选）
  - [x] 卸载：提供勾选项清除 AppData 记忆
  - [x] 打包产物：安装包可在干净 Windows 环境安装/卸载

# Task Dependencies
- Task 4 depends on Task 2
- Task 5 depends on Task 4
- Task 6 depends on Task 4
- Task 7 depends on Task 4, Task 10
- Task 8 depends on Task 7
- Task 9 depends on Task 7
- Task 11 depends on Task 2, Task 6
