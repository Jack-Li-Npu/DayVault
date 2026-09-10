#!/bin/zsh
set -euo pipefail

keychain_service="com.dayvault.local-ai"
keychain_account="dayvault-local"

echo "请输入本地测试 API Key（输入内容不会显示）："
security add-generic-password \
  -U \
  -a "$keychain_account" \
  -s "$keychain_service" \
  -w >/dev/null

echo "已保存到 macOS 钥匙串；密钥没有写入项目。"
