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

  if ! json="$(brew livecheck --cask "$cask" --json)"; then
    echo "livecheck 执行失败"
    failed=$((failed + 1))
    echo "::endgroup::"
    continue
  fi
  if [[ -z "$json" ]]; then
    echo "livecheck 无输出"
    failed=$((failed + 1))
    echo "::endgroup::"
    continue
  fi

  # Homebrew 6 返回数组且版本字段位于 `.version`;同时兼容旧版对象格式。
  if ! record="$(printf '%s' "$json" | jq -c --arg c "$cask" '
    if type == "array" then
      (first(.[] | select(.cask == $c)) // {})
    elif type == "object" then
      (.[$c] // {})
    else
      {}
    end
  ')"; then
    echo "livecheck JSON 解析失败"
    failed=$((failed + 1))
    echo "::endgroup::"
    continue
  fi

  current="$(printf '%s' "$record" | jq -r '.version.current // .current // empty')"
  latest="$(printf '%s' "$record" | jq -r '.version.latest // .latest // empty')"
  outdated="$(printf '%s' "$record" | jq -r '
    if .version.outdated != null then
      .version.outdated
    elif .status != null then
      .status == "outdated"
    else
      false
    end
  ')"

  if [[ -z "$current" || -z "$latest" ]]; then
    echo "livecheck JSON 缺少版本字段"
    failed=$((failed + 1))
    echo "::endgroup::"
    continue
  fi

  if [[ "$outdated" != "true" ]]; then
    echo "状态=最新 (current=$current latest=$latest),跳过"
    echo "::endgroup::"
    continue
  fi

  echo "发现新版本: $current -> $latest"

  # ruby 脚本:提取 url、下载、算 sha256、改写文件;输出新 sha256
  err_log="$(mktemp)"
  if ! new_sha="$(ruby "$TAP_DIR/.github/scripts/cask_bump.rb" "$cask_file" "$latest" 2>"$err_log")"; then
    echo "下载/改写失败:"
    cat "$err_log"
    rm -f "$err_log"
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

# 同步 README 的 cask 列表表格:
# 此时各 cask 的 commit 已在上方循环内完成,git log 能读到最新日期,
# 故本次被升级的 cask 在表格中会显示今天的日期。
ruby "$TAP_DIR/.github/scripts/update_readme.rb"
readme_updated=0
if ! git diff --quiet -- README.md; then
  git add README.md
  git commit -m "docs: 同步 README cask 列表" >/dev/null
  readme_updated=1
fi

if [[ "$bumped" -gt 0 || "$readme_updated" -eq 1 ]]; then
  git push
  [[ "$bumped" -gt 0 ]] && echo "✅ 已推送 $bumped 个 cask 更新到 main"
  [[ "$readme_updated" -eq 1 ]] && echo "📝 已更新 README 表格"
else
  echo "ℹ️ 无过期 cask 需更新"
fi

if [[ "$failed" -gt 0 ]]; then
  echo "⚠️ $failed 个 cask 更新失败,详见上方日志"
  exit 1
fi
