#!/usr/bin/env bash
# bump-outdated-casks.sh
#
# 遍历 Casks/*.rb,用 `brew livecheck` 检测每个 cask 是否有新版本:
#   - outdated -> 下载新版本、计算 sha256、改写脚本、用 brew fetch 校验、提交
#   - 否则     -> 跳过
# 最后若有提交,直接推送到 main。
#
# 设计要点:检测逻辑复用各 cask 自身声明的 `livecheck` 块,新增 cask 零额外配置。
set -euo pipefail

TAP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CASKS_DIR="$TAP_DIR/Casks"
cd "$TAP_DIR"

command -v jq >/dev/null 2>&1 || brew install jq

# 用 GitHub Actions bot 身份提交,便于区分人工与自动提交
git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

bumped=0
failed=0

shopt -s nullglob
for cask_file in "$CASKS_DIR"/*.rb; do
  cask="$(basename "$cask_file" .rb)"
  echo "::group::cask: $cask"

  json="$(brew livecheck --cask "$cask" --json 2>/dev/null || true)"
  if [[ -z "$json" ]]; then
    echo "livecheck 无输出,跳过"
    echo "::endgroup::"
    continue
  fi

  status="$(printf '%s' "$json" | jq -r --arg c "$cask" '.[$c].status // empty')"
  latest="$(printf '%s' "$json" | jq -r --arg c "$cask" '.[$c].latest // empty')"
  current="$(printf '%s' "$json" | jq -r --arg c "$cask" '.[$c].current // empty')"

  if [[ "$status" != "outdated" ]]; then
    echo "状态=$status (current=$current latest=$latest),跳过"
    echo "::endgroup::"
    continue
  fi

  echo "发现新版本: $current -> $latest"

  # ruby 脚本:提取 url、下载、算 sha256、改写文件;输出新 sha256
  err_log="$(mktemp)"
  if ! new_sha="$(ruby "$TAP_DIR/.github/scripts/cask_bump.rb" "$cask_file" "$latest" 2>"$err_log")"; then
    echo "下载/改写失败:"
    cat "$err_log"
    git checkout -- "$cask_file" 2>/dev/null || true
    failed=$((failed + 1))
    echo "::endgroup::"
    continue
  fi
  rm -f "$err_log"

  # brew fetch 按新 version+sha256 重新下载并校验哈希,失败则回滚
  if brew fetch --cask "$cask" >/dev/null 2>&1; then
    git add "$cask_file"
    git commit -m "bump: $cask $current -> $latest" >/dev/null
    bumped=$((bumped + 1))
    echo "已提交 $cask ($current -> $latest, sha256=$new_sha)"
  else
    echo "brew fetch 校验失败,回滚"
    git checkout -- "$cask_file"
    failed=$((failed + 1))
  fi

  echo "::endgroup::"
done

if [[ "$bumped" -gt 0 ]]; then
  git push
  echo "✅ 已推送 $bumped 个 cask 更新到 main"
else
  echo "ℹ️ 无过期 cask 需更新"
fi

if [[ "$failed" -gt 0 ]]; then
  echo "⚠️ $failed 个 cask 更新失败,详见上方日志"
fi
