# 活体复核记录（部署完成约 7 小时后）

复核时间：2026-10-26 17:56 (Asia/Shanghai)
复核方式：在部署机（手机沙箱）上直接打本地端口，非回放历史日志。

## /health

```json
{"ok": true, "accounts": 2, "healthy": 2, "auth_required": false,
 "pool": [
   {"label": "acct_UQ4eMp", "healthy": true, "usage": 37.0, "cooldown": 0, "inflight": 0},
   {"label": "acct_GcMqsz", "healthy": true, "usage": 1.0,  "cooldown": 0, "inflight": 0}
 ]}
```

## /ui/pool（账号明细）

| label | plan | model | usage | ok/err | healthy |
|---|---|---|---|---|---|
| acct_UQ4eMp | pro | model.glm-5.3 | 37% | 8/4 | ✅ |
| acct_GcMqsz | pro | model.deepseek-v4.1-flash | 1% | 6/4 | ✅ |

- `concurrency: 2`，`max_usage: 98.0`
- ok/err 里的 4 次错误为历史累积（当天调试期产生），当前无冷却、无 inflight。

## /v1/models

```json
{"object": "list", "data": [
  {"id": "deepseek-v4.1-flash", "owned_by": "today", "upstream": "model.deepseek-v4.1-flash"},
  {"id": "glm-5.3",             "owned_by": "today", "upstream": "model.glm-5.3"}
]}
```

短名对外、长名映射上游，符合 README §2.4 的约定。

## 推理实测

| 模型 | HTTP | 耗时 | completion_tokens |
|---|---|---|---|
| deepseek-v4.1-flash | 200 | 6.2s | 121 |
| glm-5.3 | 200 | 21.9s | — |

注：正文带「分析：…」前缀，证明 `INJECT_REASONING_HINT` 注入生效（README §3 第 5 条）。

## 结论

**部署成功且持续在线**。号池健康、额度充足（37%/1%）、推理链路通。
唯一未做项：公网暴露层（nginx + AUTH_TOKENS + HTTPS），当前为内网使用，见 README §4。
