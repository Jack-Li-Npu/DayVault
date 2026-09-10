#!/bin/zsh
set -euo pipefail

script_directory="${0:A:h}"
project_root="${script_directory:h}"
keychain_service="com.dayvault.local-ai"
keychain_account="dayvault-local"
local_endpoint="http://localhost:8000"

if ! command -v deno >/dev/null 2>&1; then
  echo "缺少 Deno。请先安装 Deno，再重新运行。" >&2
  exit 1
fi

if ! xcrun simctl list devices booted | rg -q "Booted"; then
  echo "没有已启动的 iPhone 模拟器。请先从 Xcode 启动一个模拟器。" >&2
  exit 1
fi

api_key="$(security find-generic-password \
  -a "$keychain_account" \
  -s "$keychain_service" \
  -w 2>/dev/null || true)"
if [[ -z "$api_key" ]]; then
  echo "尚未配置密钥。请先运行 Scripts/configure-local-ai.sh。" >&2
  exit 1
fi

export OPENAI_API_KEY="$api_key"
export OPENAI_BASE_URL="https://api.3366.ai"
export DAYVAULT_OPENAI_MODEL="gpt-5.6-luna"
export DAYVAULT_OPENAI_REASONING_EFFORT="medium"
export DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW="true"
export DAYVAULT_SERVER_HOST="127.0.0.1"
unset api_key

xcrun simctl spawn booted launchctl setenv DAYVAULT_AI_ENDPOINT "$local_endpoint"

cleanup() {
  xcrun simctl spawn booted launchctl unsetenv DAYVAULT_AI_ENDPOINT >/dev/null 2>&1 || true
  unset OPENAI_API_KEY
}
trap cleanup EXIT INT TERM

echo "本地 AI 代理已连接：gpt-5.6-luna · medium"
echo "保持此终端开启，然后在 Xcode 中重新运行 DayVault。按 Control-C 停止。"

deno run --quiet \
  --allow-env=OPENAI_API_KEY,OPENAI_BASE_URL,DAYVAULT_OPENAI_MODEL,DAYVAULT_OPENAI_REASONING_EFFORT,DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW,DAYVAULT_SERVER_HOST \
  --allow-net=api.3366.ai,127.0.0.1:8000,localhost:8000 \
  "$project_root/supabase/functions/generate-plan/index.ts"
