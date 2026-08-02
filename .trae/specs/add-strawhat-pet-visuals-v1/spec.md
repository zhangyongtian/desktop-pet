# 草帽桌宠形象与丝滑动效 v1 Spec

## Why
当前桌宠仅显示一个按钮占位，缺少“草帽形象”的直观角色存在感。用户希望启动后能看到草帽形象，并且具备更丝滑的状态动效（闲置/忙碌/睡觉）。

## What Changes
- 新增：桌宠主体从文字按钮替换为“草帽形象”显示
- 新增：闲置/忙碌/睡觉三态表现，并随系统事件切换
- 新增：形象资源运行时自动获取与本地缓存（首次下载、后续复用）
- 新增：允许用户在设置中覆盖形象资源来源（URL 或本地文件）
- **BREAKING**：桌宠主场景节点从 Button 为主改为图像节点为主（保留点击弹窗能力）

## Impact
- Affected specs: 桌宠 UI、动画状态机、设置页
- Affected code: `apps/desktop-pet/godot/scenes/Main.tscn` 与相关脚本；不影响 helper 采集与报表逻辑

## ADDED Requirements

### Requirement: 草帽形象展示
系统 SHALL 在桌面上以图像方式展示桌宠主体（草帽形象），替代当前文字按钮。

#### Scenario: 启动展示
- **WHEN** 用户启动桌宠
- **THEN** 桌宠主体显示草帽形象并可被点击

### Requirement: 三态表现（idle/busy/sleep）
系统 SHALL 提供三种视觉状态：
- idle：默认状态
- busy：检测到文本事件写入记忆流水后进入，持续一小段时间
- sleep：用户长时间无操作或长时间无新事件后进入

#### Scenario: idle → busy
- **WHEN** 新的记忆事件写入（来自 helper 或任务等）
- **THEN** 桌宠进入 busy 动效并在超时后回到 idle

#### Scenario: idle → sleep
- **WHEN** 超过设定的闲置阈值无新事件
- **THEN** 桌宠进入 sleep 动效

#### Scenario: sleep → idle
- **WHEN** 新事件到来或用户点击桌宠
- **THEN** 桌宠回到 idle

### Requirement: 运行时自动获取资源并缓存
系统 SHALL 支持在首次启动时从网络获取三态资源，并缓存到 `user://pet_assets/`，后续启动优先使用缓存。

#### Scenario: 首次下载
- **WHEN** 本地缓存不存在
- **THEN** 系统下载 idle/busy/sleep 资源并保存到 `user://pet_assets/`

#### Scenario: 缓存命中
- **WHEN** 本地缓存存在
- **THEN** 系统直接加载缓存资源，不再重复下载

### Requirement: 资源可覆盖
系统 SHALL 允许用户在“设置”中覆盖三态资源来源：
- 方式 1：设置三态 URL
- 方式 2：选择本地图片文件并复制到 `user://pet_assets/`

#### Scenario: 覆盖资源后生效
- **WHEN** 用户保存新的资源来源
- **THEN** 桌宠立即或在下次启动时使用新资源

## MODIFIED Requirements
无。

## REMOVED Requirements
无。

## Notes
- 用户希望“看起来就是路飞”属于版权高风险方向。本 Spec 不引入版权授权流程；资源来源由用户自行提供或自行承担使用风险。
- v1 以“图片 + 过渡动效（淡入淡出/轻微摆动）”实现丝滑观感；Spine/Live2D 需要独立资源制作与运行库接入，建议作为后续版本。

