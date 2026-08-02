# Tasks
- [x] Task 1: 明确安装目录与运行时可执行文件布局
  - [x] 定义桌宠主程序与 helper 在安装目录的相对位置（固定路径）
  - [x] 定义 helper 默认端口与覆盖策略（配置文件/命令行/环境变量）
  - [x] 明确桌宠与 helper 的启动顺序与重试策略

- [x] Task 2: Godot 启动时自动启动/连接 helper
  - [x] 启动时先调用 helper /health 进行探活
  - [x] 不可达时启动 helper 进程（从安装目录定位）
  - [x] helper 可用后开始轮询 /events
  - [x] 端口占用/启动失败时给出 UI 提示并保持应用可用

- [x] Task 3: 首次启动引导与可理解提示
  - [x] DeepSeek 配置缺失时在 UI 显示明显提示（并引导进入设置页）
  - [x] 提供 endpoint 示例占位文本（不包含任何用户密钥）
  - [x] helper 不可用时提示“采集不可用”，但任务面板仍可用

- [x] Task 4: 安装器打包闭环（桌宠 + helper）
  - [x] 明确导出产物目录结构（桌宠：apps/desktop-pet/dist；helper：apps/desktop-pet/helper-win/target/release）
  - [x] build.ps1 将桌宠产物与 helper 可执行文件复制到 installer/payload
  - [x] Inno Setup 脚本确认：安装后可运行桌宠；自启默认不勾选；卸载可勾选清记忆

- [x] Task 5: 验证脚本与验收步骤
  - [x] 给出最小验收步骤（可复现）：安装→启动→采集→总结→卸载清理
    - [x] 安装
      - [x] 准备安装包：apps/desktop-pet/installer/output/ 下的 DesktopPet-Setup-*.exe
      - [x] 双击安装包完成安装（默认路径：%ProgramFiles%\Desktop Pet）
      - [x] 安装目录包含：desktop-pet.exe 与 helper-win.exe
    - [x] 启动
      - [x] 从开始菜单或安装目录运行 desktop-pet.exe
      - [x] 5 秒内 helper 可被探活：PowerShell 执行 `iwr http://127.0.0.1:28999/health | Select-Object -Expand Content` 输出 `ok`
      - [x] UI 状态文案可理解：helper 不可用时提示“采集暂不可用”，但仍可打开面板（任务/设置等）
    - [x] 采集（验证事件进入记忆流水）
      - [x] 打开任意文本编辑器，输入一段文字；再复制一段文本到剪贴板
      - [x] 事件文件出现新增记录：%APPDATA%\Godot\app_userdata\desktop-pet\memory\events.jsonl
      - [x] events.jsonl 至少包含 1 条 `source=helper/typing` 或 `source=helper/clipboard` 的记录，且 text 非空
      - [x] 可选：直接拉取 helper 事件 `iwr http://127.0.0.1:28999/events | Select-Object -Expand Content` 返回 JSON 数组（可能为空或包含事件）
    - [x] 总结/报表
      - [x] 未配置 DeepSeek（验证提示且不崩溃）
        - [x] 在【设置】点击“清空”（或首次启动不填 API Key），保持 Endpoint/Model 任意
        - [x] 打开面板 →【报表】→ 点击“运行总结”
        - [x] 输出为可理解提示（例如“DeepSeek 未配置：请到【设置】填写 API Key…”），应用不崩溃
      - [x] 已配置 DeepSeek（验证可产出内容）
        - [x] 在【设置】填写 Endpoint / Model / API Key 后点击“保存”
        - [x] 打开面板 →【报表】→ 点击“运行总结”，输出为非空文本
        - [x] 生成精华文件：%APPDATA%\Godot\app_userdata\desktop-pet\memory\essence.json（新增条目）
    - [x] 卸载清理
      - [x] 卸载前建议在【设置】点击“紧急停止”关闭 helper（避免 28999 端口残留占用）
      - [x] 通过系统“应用和功能/已安装的应用”卸载 Desktop Pet
      - [x] 勾选“同时清除记忆目录（AppData）”后继续卸载
      - [x] 记忆目录被删除：%APPDATA%\Godot\app_userdata\desktop-pet
  - [x] 验证：未配置 DeepSeek 时能正常提示且不崩溃（按“总结/报表 → 未配置 DeepSeek”步骤）
  - [x] 验证：helper 启动失败时能提示且不崩溃
    - [x] 关闭桌宠并确认 helper-win.exe 进程不存在
    - [x] 临时将安装目录中的 helper-win.exe 重命名为 helper-win.exe.bak
    - [x] 再次启动 desktop-pet.exe，UI 提示“采集暂不可用/启动 helper 失败”，但任务面板仍可用且不崩溃
    - [x] 还原 helper-win.exe 文件名

# Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 2
- Task 4 depends on Task 1
- Task 5 depends on Task 2, Task 3, Task 4
