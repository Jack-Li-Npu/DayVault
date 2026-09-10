#!/bin/zsh
set -euo pipefail

script_directory="${0:A:h}"
project_root="${script_directory:h}"
keychain_service="com.dayvault.local-ai"
keychain_account="dayvault-local"
local_endpoint="http://127.0.0.1:8000"

if ! command -v node >/dev/null 2>&1; then
  echo "缺少 Node.js，无法重新打包最新排程指令。" >&2
  exit 1
fi
if lsof -nP -iTCP:8000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "8000 端口已有服务。请先停止原代理，避免误连旧版本。" >&2
  exit 1
fi

if ! command -v deno >/dev/null 2>&1; then
  echo "缺少 Deno。请先安装 Deno，再重新运行。" >&2
  exit 1
fi

if ! xcrun simctl list devices booted | rg -q "Booted"; then
  echo "没有已启动的 iPhone 模拟器。请先从 Xcode 启动一个模拟器。" >&2
  exit 1
fi

node "$project_root/Scripts/bundle-ai-skill.mjs"

api_key="$(security find-generic-password \
  -a "$keychain_account" \
  -s "$keychain_service" \
  -w 2>/dev/null || true)"
if [[ -z "$api_key" ]]; then
  echo "尚未配置密钥。请先运行 Scripts/configure-local-ai.sh。" >&2
  exit 1
fi

export OPENAI_API_KEY="$api_key"
if [[ -f "$project_root/.env.local" ]]; then
  source "$project_root/.env.local"
fi
: "${OPENAI_BASE_URL:?Set OPENAI_BASE_URL in your ignored .env.local}"
: "${DAYVAULT_OPENAI_MODEL:?Set DAYVAULT_OPENAI_MODEL in your ignored .env.local}"
export OPENAI_BASE_URL DAYVAULT_OPENAI_MODEL
export DAYVAULT_OPENAI_REASONING_EFFORT="${DAYVAULT_OPENAI_REASONING_EFFORT:-medium}"
provider_host="$(node -e 'const u = new URL(process.env.OPENAI_BASE_URL); if (u.protocol !== "https:" || u.username || u.password) process.exit(1); process.stdout.write(u.host)')"
export DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW="true"
export DAYVAULT_SERVER_HOST="127.0.0.1"
unset api_key

xcrun simctl spawn booted launchctl setenv DAYVAULT_AI_ENDPOINT "$local_endpoint"
# Persist only the non-secret app endpoint so Xcode/Simulator restarts do not
# silently return to the demonstration planner. Stopped proxy => explicit error.
xcrun simctl spawn booted defaults write com.dayvault.app aiPlannerEndpoint -string "$local_endpoint"

cleanup() {
  xcrun simctl spawn booted launchctl unsetenv DAYVAULT_AI_ENDPOINT >/dev/null 2>&1 || true
  unset OPENAI_API_KEY
}
trap cleanup EXIT INT TERM

echo "正在启动本地 AI 代理（私人配置不显示）。"
echo "保持此终端开启，然后在 Xcode 中重新运行 DayVault。按 Control-C 停止。"
echo "连接地址已保存在模拟器。停止代理后会明确报连接错误，不再切回本地演示。"

deno run --quiet \
  --watch="$project_root/supabase/functions/_shared,$project_root/supabase/functions/generate-plan" \
  --allow-env=OPENAI_API_KEY,OPENAI_BASE_URL,DAYVAULT_OPENAI_MODEL,DAYVAULT_OPENAI_REASONING_EFFORT,DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW,DAYVAULT_SERVER_HOST \
  --allow-net="$provider_host,127.0.0.1:8000,localhost:8000" \
  "$project_root/supabase/functions/generate-plan/index.ts"
