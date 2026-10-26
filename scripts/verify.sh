#!/usr/bin/env bash
# today-proxy 部署后四连验证
#   bash verify.sh [PORT]
# 退出码 0 = 全部通过；非 0 = 有失败，看输出

PORT="${1:-8770}"
BASE="http://127.0.0.1:${PORT}"
pass=0; fail=0
ok()  { echo "  ✅ $*"; pass=$((pass+1)); }
bad() { echo "  ❌ $*"; fail=$((fail+1)); }

echo "[1/4] 进程"
# 注意：若部署在 Android 主环境而本 shell 在 PRoot 沙箱内，ps 看不到对方进程，
# 此时以 /health 200 为准（本脚本实测踩过：ps 失败但服务完全正常）。
if ps aux 2>/dev/null | grep -v grep | grep -q '[s]erver.py'; then
    ok "server.py 进程存在"
else
    echo "  ·  ps 未见进程（可能是沙箱隔离），以 /health 为准"
fi

echo "[2/4] 端口/健康"
h=$(curl -s -o /tmp/_tp_h.json -w '%{http_code}' --max-time 10 "$BASE/health" 2>/dev/null)
if [ "$h" = "200" ]; then
    ok "/health = 200 : $(head -c 120 /tmp/_tp_h.json)"
else
    bad "/health = $h（预期 200）"
fi

echo "[3/4] 模型列表"
m=$(curl -s -o /tmp/_tp_m.json -w '%{http_code}' --max-time 10 "$BASE/v1/models" 2>/dev/null)
if [ "$m" = "200" ]; then
    n=$(python3 -c "import json;print(len(json.load(open('/tmp/_tp_m.json'))['data']))" 2>/dev/null)
    ok "/v1/models = 200，${n:-?} 个模型"
else
    bad "/v1/models = $m"
fi

echo "[4/4] 真实推理（部署成功的最终判据）"
c=$(curl -s -o /tmp/_tp_c.json -w '%{http_code}' --max-time 60 \
    "$BASE/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model":"deepseek-v4.1-flash","messages":[{"role":"user","content":"reply: PONG"}],"max_tokens":30}' 2>/dev/null)
if [ "$c" = "200" ]; then
    ok "chat = 200，内容: $(python3 -c "import json;print(json.load(open('/tmp/_tp_c.json'))['choices'][0]['message'].get('content','')[:60])" 2>/dev/null)"
else
    bad "chat = $c（响应：$(head -c 200 /tmp/_tp_c.json 2>/dev/null)）"
fi

echo
echo "结果：通过 $pass · 失败 $fail"
[ "$fail" = "0" ]
