# 桌宠可启动可使用闭环 v1 Spec

## Why
当前项目已具备桌宠核心能力（采集、记忆、总结、报表、陪聊、安装器脚本），但从用户视角仍存在“需要手动启动多个进程、启动步骤不明确、首次配置不顺畅”的摩擦。用户要求：直到能在安装后直接启动并使用为止。

## What Changes
- 新增：桌宠应用启动时自动启动/连接 Windows helper（无需用户手动运行 helper）
- 新增：安装包将 helper 与桌宠一并安装，并保证卸载行为一致
- 新增：首次启动引导（至少引导填写 DeepSeek endpoint/model/key 与称呼）
- 新增：运行健康检查与降级策略（helper 未启动/端口占用/无 key 时的可理解提示）
- 新增：一键启动验证流程（面向开发/验收的最小复现步骤）

## Impact
- Affected specs: 启动流程、进程管理、安装器、设置页
- Affected code:
  - Godot：启动 helper、状态提示、首次引导
  - helper-win：支持可配置端口/单实例约束（如需要）
  - installer：打包 helper 与桌宠产物；卸载清理策略保持一致

## ADDED Requirements

### Requirement: 安装后可直接启动使用
系统 SHALL 在用户安装完成后，双击桌宠即可进入可使用状态（无需用户额外手动启动 helper 进程）。

#### Scenario: 安装后启动
- **WHEN** 用户通过安装包完成安装并启动桌宠
- **THEN** 桌宠自动启动或连接 helper
- **AND** 开始采集剪贴板与打字事件并写入记忆流水

### Requirement: helper 自动启动与生命周期管理
系统 SHALL 在桌宠启动时确保 helper 可用：
- 若 helper 未运行，桌宠 SHALL 尝试启动 helper（安装目录下的 helper 可执行文件）
- 若 helper 已运行，桌宠 SHALL 直接连接
- 桌宠退出时，SHALL 不强制杀掉 helper（避免误伤其他会话），但应提供“紧急停止”作为显式关闭能力

#### Scenario: helper 未运行
- **WHEN** 桌宠启动且检测 helper 不可达
- **THEN** 桌宠启动 helper 并在可用后开始拉取事件

#### Scenario: helper 已运行
- **WHEN** 桌宠启动且 helper 健康检查通过
- **THEN** 桌宠不重复启动 helper，仅建立连接

### Requirement: 首次启动引导（DeepSeek 与称呼）
系统 SHALL 在检测到 DeepSeek 未配置时引导用户完成最小配置：
- endpoint
- model
- api key
- 用户称呼

#### Scenario: 未配置时引导
- **WHEN** 用户首次启动且 DeepSeek 配置缺失
- **THEN** 桌宠提示用户前往设置页完成配置，并给出可复制的 endpoint 示例格式

### Requirement: 关键失败路径可理解提示
系统 SHALL 对以下情况给出可理解的 UI 提示并保持应用可用：
- helper 启动失败或端口不可用
- DeepSeek key 未配置或请求失败

#### Scenario: helper 不可用
- **WHEN** helper 无法连接
- **THEN** 桌宠提示“采集暂不可用”，并允许用户继续使用任务/本地面板功能

#### Scenario: LLM 不可用
- **WHEN** DeepSeek 未配置或请求失败
- **THEN** 桌宠提示“总结/报表/陪聊暂不可用”，并不阻塞采集与任务

### Requirement: 安装器产物闭环
系统 SHALL 在安装包中包含：
- 桌宠主程序
- helper 可执行文件
- 必要的运行依赖（随产物分发）

卸载时：
- 用户可选择是否清除 AppData 记忆目录
- 程序文件与 StartMenu 项被移除

#### Scenario: 安装包含 helper
- **WHEN** 用户安装
- **THEN** 安装目录包含 helper 可执行文件，桌宠可从该路径启动 helper

## MODIFIED Requirements
无。

## REMOVED Requirements
无。

