# Tasks
- [ ] Task 1: 资源与缓存方案落地
  - [ ] 设计 `user://pet_assets/` 缓存结构（idle/busy/sleep）
  - [ ] 设计资源来源优先级（用户覆盖 > 缓存 > 默认 URL）
  - [ ] 在设置中增加资源配置项（URL/本地选择）与保存逻辑

- [ ] Task 2: 桌宠主体替换为图像节点
  - [ ] 将 Main 场景的 PetButton 替换为可点击的图像节点（TextureButton 或 Sprite2D + Area2D）
  - [ ] 保持点击弹出面板能力不变

- [ ] Task 3: 三态动效与状态切换
  - [ ] 实现 idle/busy/sleep 三态资源切换（Texture 替换）
  - [ ] 增加淡入淡出与轻微摆动（Tween/AnimationPlayer）以提升丝滑观感
  - [ ] busy 触发：记忆事件写入时进入，超时回 idle
  - [ ] sleep 触发：闲置阈值进入；新事件/点击唤醒

- [ ] Task 4: 默认资源生成与落地方式
  - [ ] 提供默认三态 URL（运行时下载）
  - [ ] 允许用户替换为自有资源（适配“看起来就是路飞”的自用需求）

- [ ] Task 5: 验证与回归
  - [ ] 验证：首次启动可下载并缓存
  - [ ] 验证：关闭重启后从缓存加载
  - [ ] 验证：busy/sleep 状态切换符合触发条件
  - [ ] 验证：点击依然可弹出面板

# Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 2
- Task 4 depends on Task 1
- Task 5 depends on Task 1, Task 2, Task 3

