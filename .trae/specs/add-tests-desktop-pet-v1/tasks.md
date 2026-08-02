# Tasks
- [ ] Task 1: helper-win 测试体系（cargo test）
  - [x] 盘点 helper-win 模块边界，识别可测单元（配置解析、事件队列、HTTP 路由）
  - [x] 增加 Rust 单元测试（cfg(test) 或 tests/）
  - [x] 增加最小 HTTP 集成测试（启动服务在随机端口/0 端口或测试端口）
  - [ ] 确保 `cargo test` 在 Windows 上可稳定运行

- [x] Task 2: Godot 最小自检（headless）
  - [x] 新增 `res://tests/self_check.gd`：断言 MemoryStore 可写、ConfigStore 缺失配置能返回缺失提示、HelperBridge 不可用时可读 detail
  - [x] 自检脚本不依赖 UI 节点树；只加载必要脚本并调用关键方法
  - [x] 自检失败时退出码非 0（便于脚本判定）

- [x] Task 3: 一键验证脚本
  - [x] 新增 `scripts/verify.ps1`：运行 helper-win `cargo test`
  - [x] 支持可选参数 `-GodotExe`；不提供则尝试从常见位置探测；都不可用则提示“跳过 Godot 自检”
  - [x] 若可运行 Godot，则执行 headless 自检并检查退出码

- [ ] Task 4: 补齐验收与文档
  - [ ] 更新 `add-tests-desktop-pet-v1/checklist.md` 并在实现后逐条勾选
  - [x] 在脚本输出中打印“通过/失败”的关键信息（不包含任何密钥）

- [ ] Task 5: 在具备工具链环境完成验证
  - [ ] 在 Windows 安装 Rust 工具链（rustup/cargo）后运行 `scripts/verify.ps1`
  - [ ] 若本机已安装 Godot4，提供 `-GodotExe` 或设置 `GODOT4_EXE` 后运行 Godot headless 自检
  - [ ] 根据输出结果勾选 checklist.md 中剩余项

# Task Dependencies
- Task 2 depends on Task 1（可并行进行，但建议先定 helper 端口/行为）
- Task 3 depends on Task 1, Task 2
- Task 4 depends on Task 1, Task 2, Task 3
- Task 5 depends on Task 3
