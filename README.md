# today-proxy

Today.app（today.ai）AI 反向代理 —— 把 Today 手机 App 的私有协议翻译成
**OpenAI / Anthropic 兼容 API**，多账号池轮换，纯 Python 标准库，零依赖。

```
客户端 ──HTTP──> today-proxy :8770 ──Today 私有协议──> today.ai
                (OpenAI/Anthropic 格式)    (session token + 账号池)
```

## 特性

- **双协议**：`/v1/chat/completions`（OpenAI）+ `/v1/messages`（Anthropic），
  主流客户端（OpenCode、Cherry Studio、LobeChat…）开箱即用
- **SSE 流式**：两端点都支持 `stream: true`
- **账号池**：多账号轮询、按权重分配、额度 ≥98% 自动冷却、并发闸控
- **零依赖**：Python ≥3.8 标准库，无需 pip install
- **Web 控制台**：`/ui` 页面可视化收码登录、看号池状态
- **轻量**：单进程单文件核心，systemd / Docker 一键部署

## 快速开始

### 方式一：systemd（推荐，Linux 服务器）

```bash
git clone https://github.com/haohanyu1107-dev/today-proxy-deploy.git
cd today-proxy-deploy
sudo bash install.sh
```

脚本自动完成：装 python3 → 拷贝代码到 `/opt/today-proxy` → 生成 `/etc/today-proxy.env`
（含随机 API Key）→ 注册 systemd 服务 → 健康检查。

**登录账号（必须做，否则没有模型可用）：**

```bash
cd /opt/today-proxy
python3 login.py +861NNNNNNNNN           # 发送短信验证码
python3 login.py +861NNNNNNNNN 123456    # 提交验证码，session token 写入 data/session.txt
systemctl restart today-proxy            # 重启加载
```

多账号重复执行即可，号池自动聚合；或在浏览器打开 `http://<IP>:8770/ui` 网页收码登录。

### 方式二：Docker

```bash
git clone https://github.com/haohanyu1107-dev/today-proxy-deploy.git
cd today-proxy-deploy
mkdir -p data

# 写入 session token（可多个，逗号分隔；或登录后留在 data/session.txt）
echo "你的TODAY_SESSION_TOKEN" > data/session.txt

docker compose up -d
```

### 方式三：裸跑（临时测试）

```bash
AUTH_TOKENS=sk-mykey python3 server.py
# 或
TODAY_SESSION=tok1,tok2 AUTH_TOKENS=sk-mykey LISTEN_PORT=8770 python3 server.py
```

## 验证

```bash
curl http://127.0.0.1:8770/health
# {"ok": true, "accounts": 2, "healthy": 2, ...}

curl http://127.0.0.1:8770/v1/models
# {"object":"list","data":[{"id":"deepseek-v4.1-flash",...},{"id":"glm-5.3",...}]}

curl http://127.0.0.1:8770/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <你的AUTH_TOKENS>' \
  -d '{"model":"glm-5.3","messages":[{"role":"user","content":"hi"}]}'
```

或跑仓库自带四连验证：`bash scripts/verify.sh 8770`

## 配置

所有配置走环境变量（systemd 装：`/etc/today-proxy.env`；Docker：compose 里的 environment）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `LISTEN_HOST` | `0.0.0.0` | 监听地址 |
| `LISTEN_PORT` | `8770` | 监听端口 |
| `AUTH_TOKENS` | 空 | 客户端 API Key，多个逗号分隔；**空 = 不鉴权（仅限内网）** |
| `TODAY_SESSION` | 空 | Today session token，多个逗号分隔；更推荐 `login.py` 写 `data/session.txt` |
| `POOL_WEIGHTS` | 全 1 | 号池权重，与 TODAY_SESSION 一一对应，如 `1,2,1` |
| `POOL_LABELS` | 空 | 控制台显示名，逗号分隔 |
| `LANE_CONCURRENCY` | `1` | 单账号单模型并发上限 |
| `MAX_USAGE_PERCENT` | `98` | 额度用到此百分比即停止派单（自动冷却） |
| `QUEUE_WAIT` | `120` | 无号可用时最长排队秒数，0 = 立刻 503 |
| `DEFAULT_MODEL` | `deepseek` | 请求未指定 model 时的默认值 |
| `REPLY_TIMEOUT` | `180` | 上游回复超时（秒） |
| `INJECT_REASONING_HINT` | `1` | 注入思考过程提示词（0 关闭） |

## 模型

| 对外 model 值 | 说明 |
|---|---|
| `glm-5.3` | 智谱 GLM 5.3 |
| `deepseek-v4.1-flash` / `deepseek` | DeepSeek v4.1 flash（默认） |

## API

### OpenAI 兼容

```
GET  /v1/chat/completions        # 405，仅确认路由存在
POST /v1/chat/completions        # OpenAI 格式推理（含 SSE 流式）
POST /v1/messages                # Anthropic 格式推理
GET  /v1/models                  # 模型列表
GET  /health                     # 健康检查 + 号池摘要
GET  /ui                         # Web 控制台
GET  /ui/pool                    # 号池状态 JSON
POST /ui/pool/add | /remove | /refresh   # 号池管理（见 server.py 头部注释）
```

### Anthropic 兼容

```
POST /v1/messages     （x-api-key 或 Authorization 头均可）
```

### 管理端点

```
GET  /health          健康与号池概览
GET  /ui/pool         号池明细（plan/usage/ok/err/cooldown）
GET  /ui              Web 控制台
```

## 卸载

```bash
sudo bash install.sh --uninstall
# 保留 /opt/today-proxy 与 /etc/today-proxy.env（含 session token）
# 彻底删除：sudo rm -rf /opt/today-proxy /etc/today-proxy.env
```

## 安全提示

- `AUTH_TOKENS` 为空时服务不鉴权，**不要暴露到公网**；生产环境务必设置 Key，
  并用 nginx/caddy 反代加 HTTPS。
- `data/session.txt` 与 `/etc/today-proxy.env` 含敏感 token，权限已是 600，
  不要提交进 git（`.gitignore` 已挡）、不要截图分享。

## License

MIT
