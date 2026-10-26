
---

## 3. 今天实际发生了什么（时间线 + 踩坑）

### 时间线（10-26，全部在这台手机上）

| 时刻 | 动作 | 结果 |
|---|---|---|
| 00:00-00:55 | 初版 server.py + core.py + pool.py 落地，首次启动 | 起来了，但模型列表为空 |
| 07:35-07:42 | 改 server.py × 3 次（协议兼容、流式、鉴权） | OpenAI + Anthropic 双协议通 |
| 08:16-08:22 | 调并发、重启、测思考注入 | 前台服务稳定 |
| 08:27-08:36 | 你给了 `Main8986/today-proxy-android`（APK 版），装上 | APK 版是另一条线，端口 8770 |
| 08:39-10:03 | 排查：云端执行环境没手机 shell，任务反复中断 | **换成本地 shell_execute 直接跑**，立通 |
| 10:05-10:13 | 加号：发现 4 个账号实际只对应 2 个手机号（重复登录 3 次） | 按 userId 去重，保留 2 个 |
| 10:32-10:37 | 193 账号升级 pro；清 config.json 脏数据 | 双 pro 到手 |
| 10:41-10:46 | `/v1/models` 返回 4 条（短名+长名重复）；Minis provider 配置 | 短名接入，清 4 条旧缓存 |

### 踩坑清单（12 条，全带解法）

1. **云端执行环境没有手机 shell** — 派给云端 subagent 的任务全部"跑不了"，
   看起来像任务反复中断。**解法**：手机相关操作必须本地 `shell_execute` 自己跑。
2. **装了 APK ≠ 服务在跑** — 你说"我已经安装了"，但前台服务起没起、端口听没听
   仍是未知数。**解法**：装完必须跑 2.3 的四连验证，别跳步。
3. **重复登录产生重复账号** — 同一手机号登 3 次就是 3 个独立 token，额度分开计、
   看着像 4 个号。**解法**：按 `user_id` 去重，每个号只留一个 token。
4. **`/v1/models` 短名长名重复** — 上游真实 ID 带 `model.` 前缀，本地注册表用短名，
   两套都吐出来就 4 条。**解法**：对外只暴露短名；Minis 里也只加短名。
5. **上游不返回 reasoning 字段** — 想要思考过程只能靠 prompt 注入逼模型写出来。
   `INJECT_REASONING_HINT=1`（默认开）会在正文前插「分析：/结论：」格式要求。
   **坑中坑**：标题生成这类客户端自动请求也会被注入、浪费 token ——
   已按 `_HINT_SKIP_MARKERS`（"生成标题"/"title generation" 等）跳过。
6. **Anthropic 协议要兼容两代** — `/v1/messages`（新）和 `/v1/complete`（旧）都开，
   否则部分 Claude 客户端连不上。
7. **SSE 流式** — `stream=true` 时按 OpenAI chunk 格式逐段推，别一次攒完再吐，
   否则客户端看着像卡死。
8. **额度百分比超过 98% 自动冷却** — `max_usage=98`，触发后该账号暂停轮询，
   防止打死账号。冷却计数在 `/ui/pool` 可见。
9. **AUTH_TOKENS 为空 = 不鉴权** — 只适合内网/本机。对外暴露必须设，
   否则你的 pro 账号就是公共免费站。
10. **session token 只存服务端** — 客户端只见 `AUTH_TOKENS`，上游 token 永不出
    `/data/`。`install.sh --uninstall` 也会提醒这两处文件要手动删。
11. **pro 账号也有模型限制** — `model` 字段记录该账号实际可用的模型
    （两个号分别锁在 glm-5.3 / deepseek-v4.1-flash），轮询时按账号能力选。
12. **免费额度判定别信 401/429 表面值** — Today 的 free/pro 行为跟 opencode.ai
    不一样，free 号也是 200 但限速，pro 号才是真无限。升级 pro 后用
    `usage_percent` 下降来确认生效。

---

## 4. 现在的状态

- **手机端（本仓库主线）**：`127.0.0.1:8770` 在线，双 pro 账号池 healthy 2/2，
  两模型推理实测 200。
- **APK 版**（`Main8986/today-proxy-android`）：装在手机上作为备用通道，
  同样监听 8770（与 Python 版互斥，别同时起）。
- **Minis provider**：已注册为 OpenAI 类型，短名接入，可从任意模型组调用。
- **未做**：对外公网暴露（无 nginx/域名层）、HTTPS、AUTH_TOKENS 仍为空 ——
  当前是纯内网使用，要对外先补这三样。

---

## 5. 文件清单

```
.
├── README.md               ← 本文
├── server.py               主服务（25 KB，双协议 + 思考注入 + 控制台）
├── core.py                 Today 私有协议封装（OTP 登录 / 推理请求 / 模型表）
├── pool.py                 账号池（轮询 / 权重 / 冷却 / 并发闸）
├── login.py                登录 CLI（send / verify，拿 session token）
├── init.py                 数据目录初始化
├── install.sh              一键部署（systemd）+ --uninstall
├── today-proxy.service     systemd unit 模板
├── Dockerfile / docker-compose.yml   Docker 部署（可选）
├── scripts/
│   └── verify.sh           部署后四连验证（进程/端口/模型/推理）
└── evidence/
    └── live-check.md       部署完成 7 小时后的活体复核记录
```

---

*记录时间：2026-10-26 18:00 (Asia/Shanghai) · 手机沙箱内完成 · 双线部署（Python 主 + APK 备）*
