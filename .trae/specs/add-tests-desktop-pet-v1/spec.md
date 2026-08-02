# 桌宠 v1 测试与自检 Spec

## Why
当前桌宠已具备可运行闭环，但缺少可重复的自动化验证手段，导致回归成本高、安装包与采集链路易出现环境差异问题。需要补齐最小测试与自检能力，确保“能启动、能采集、能总结、能卸载清理”在开发机上可稳定复现。

## What Changes
- 新增：helper-win 的 Rust 单元测试与最小 HTTP 端点集成测试（health/events/control 基础行为）
- 新增：Godot 侧的最小自检脚本（不引入第三方测试框架），用于验证关键模块可加载、配置缺失降级提示可触发、记忆写入路径可用
- 新增：一键验证脚本（PowerShell）串联 `cargo test` 与 Godot headless 自检（可选：若未安装 Godot 则只运行 Rust 测试并提示跳过）
- 新增：验收清单对“测试通过”的要求

## Impact
- Affected specs: 验证流程、可维护性、回归保障
- Affected code:
  - helper-win：新增 `tests/` 或 `mod tests`；必要时对内部模块做小幅可测性调整
  - godot：新增 `res://tests/` 自检脚本与最小场景（仅测试，不影响运行）
  - tools：新增 `scripts/verify.ps1`（或等价位置）用于一键执行验证

## ADDED Requirements

### Requirement: Rust 测试（helper-win）
系统 SHALL 提供可通过 `cargo test` 运行的测试集合，覆盖：
- bind 地址解析/默认值
- 事件缓冲与分页/拉取行为的核心逻辑（若存在）
- HTTP `/health` 返回 200 且内容为 `ok`
- `/events` 返回 JSON 数组（可为空）
- `/control` 的基础请求返回码（不要求真实关停进程）

#### Scenario: helper-win tests pass
- **WHEN** 在 `apps/desktop-pet/helper-win` 执行 `cargo test`
- **THEN** 所有测试通过

### Requirement: Godot 自检（headless）
系统 SHALL 提供无需外部插件的 Godot 自检入口，验证：
- MemoryStore 可写入 `user://memory/*`
- ConfigStore 缺失 API Key 时，报表/陪聊调用返回缺失配置错误码或错误信息（不崩溃）
- HelperBridge 在 helper 不可用时进入降级状态（可读到 availability detail）

#### Scenario: godot self-check pass
- **WHEN** 使用 `godot --headless --quit --script res://tests/self_check.gd` 运行
- **THEN** 进程退出码为 0

### Requirement: 一键验证脚本
系统 SHALL 提供一键验证脚本，至少包含：
- 执行 helper-win 的 `cargo test`
- 若检测到 Godot 可执行文件路径可用，则运行 Godot headless 自检；否则提示跳过

#### Scenario: verify script success
- **WHEN** 执行一键验证脚本
- **THEN** Rust 测试通过
- **AND**（若可运行 Godot）Godot 自检通过

## MODIFIED Requirements
无。

## REMOVED Requirements
无。

