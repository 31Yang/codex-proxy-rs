# v3.24.0

## 修复与改进

- 仪表盘与用量统计改用独立统计数据和持久化聚合，减少大规模请求历史查询的开销，支持历史回填、迟到更新和删除后的统计重建
- 请求历史保留账号、客户端 Key 与分组快照，配置变更或删除后仍可查询原始归属；运行中的恢复租约独立存储，减少对历史记录的频繁更新和重复校验
- 修复混用 OpenAI 与 xAI 等 Provider 时，已知模型被其他 Provider 的未知模型兜底抢先匹配的问题，Grok 请求优先使用声明支持该模型的 Provider（#391）
- 修复原生 Responses Lite WebSocket 在前导重试期间丢失中断意图的问题；未启用中间件链时及时交付响应 ID，并在重试换号后继续转发中断（#390）
- 统一管理端缓存输入、缓存写入和推理输出 Token 的字段与展示，改善健康时间线浮层跟随鼠标时的平滑度

## 升级事项

- 本次数据库变更集中在 `0028_request_analytics.sql`，已发布的 `0001`–`0027` 保持不变。升级前备份数据库、停止旧版本写入并预留迁移窗口；迁移完成后不能直接换回旧二进制运行
- 管理 API 的 `cachedTokens`、`cacheWriteTokens`、`reasoningTokens` 分别更名为 `cachedInputTokens`、`cacheWriteInputTokens`、`reasoningOutputTokens`，不保留旧字段别名；自定义客户端和报表需同步调整
- 若源码部署已执行未发布 `main` 中原有的 `0028`–`0035` 迁移，其迁移历史与本版不兼容，不能直接升级，需单独迁移数据；不要修改 `_sqlx_migrations` 的 checksum 绕过校验
