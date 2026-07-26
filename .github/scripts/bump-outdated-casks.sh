#!/usr/bin/env bash
# bump-outdated-casks.sh
#
# 遍历 Casks/*.rb,用 `brew livecheck` 检测每个 cask 是否有新版本:
#   - 有新版本 -> 下载、计算 sha256、改写脚本、用 brew fetch 校验、提交
#   - 已是最新 -> 跳过
#   - 探测失败 -> 记 warning 后跳过
# 最后若有提交,直接推送到 main。
#
# 退出码约定:
#   0 = 巡检正常结束(含"全部最新"与"部分 cask 探测失败"两种情况)
#   1 = 至少一个 cask 探测到新版本但升级失败(下载/改写/校验),需人工介入
#
# 为什么探测失败不算失败:
#   Homebrew 6 的 livecheck 一旦探测出错(网络抖动、上游 release 说明格式变化、
#   GitHub API 限流等)就会以非 0 退出,而这只说明"这次判断不出有没有新版本",
#   并不代表 tap 本身有问题。让每日巡检因此整体变红会淹没真正需要处理的失败,
#   故这类情况改为 ::warning:: 注解,在 run 摘要里可见但不影响退出码。
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

bumped=0       # 成功升级并提交
uptodate=0     # 已是最新
check_failed=0 # 探测失败(不影响退出码)
bump_failed=0  # 探测到新版本但升级失败(影响退出码)

# 探测失败:打 warning 注解,计数但不影响退出码
warn_check() {
  echo "::warning title=cask 版本探测失败::$1"
  check_failed=$((check_failed + 1))
}

shopt -s nullglob
for cask_file in "$CASKS_DIR"/*.rb; do
  cask="$(basename "$cask_file" .rb)"
  echo "::group::cask: $cask"

  # livecheck 探测出错时会以非 0 退出,但 --json 仍会给出 status=error 的记录。
  # 因此这里无条件收下 stdout/stderr,再按内容判断,便于把上游错误原因打进日志。
  lc_err_file="$(mktemp)"
  json="$(brew livecheck --cask "$cask" --json 2>"$lc_err_file" || true)"
  # stderr 里常混有 brew 自身的 bundle/update 噪音,只留末尾几行当诊断线索
  lc_err="$(tail -n 3 "$lc_err_file" | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')"
  rm -f "$lc_err_file"

  # Homebrew 6 返回数组且版本字段位于 `.version`;同时兼容旧版对象格式。
  record="$(printf '%s' "$json" | jq -c --arg c "$cask" '
    if type == "array" then
      (first(.[] | select(.cask == $c)) // {})
    elif type == "object" then
      (.[$c] // {})
    else
      {}
    end
  ' 2>/dev/null || true)"
  [[ -z "$record" ]] && record="{}"

  # livecheck 在 JSON 里自带的错误说明(status=error 时的 messages)
  lc_messages="$(printf '%s' "$record" | jq -r '(.messages // []) | join("; ")' 2>/dev/null || true)"

  current="$(printf '%s' "$record" | jq -r '.version.current // .current // empty' 2>/dev/null || true)"
  latest="$(printf '%s' "$record" | jq -r '.version.latest // .latest // empty' 2>/dev/null || true)"
  outdated="$(printf '%s' "$record" | jq -r '
    if .version.outdated != null then
      .version.outdated
    elif .status != null then
      .status == "outdated"
    else
      false
    end
  ' 2>/dev/null || true)"

  # 没拿到版本号 = 这次判断不出有没有新版本,警告后跳过,不让 workflow 失败
  if [[ -z "$current" || -z "$latest" ]]; then
    reason="${lc_messages:-}"
    [[ -z "$reason" ]] && reason="${lc_err:-livecheck 未返回版本信息}"
    echo "未探测到版本信息:$reason"
    warn_check "$cask: $reason"
    echo "::endgroup::"
    continue
  fi

  if [[ "$outdated" != "true" ]]; then
    newer="$(printf '%s' "$record" | jq -r '.version.newer_than_upstream // false' 2>/dev/null || true)"
    if [[ "$newer" == "true" ]]; then
      echo "本地版本高于上游 (current=$current latest=$latest),跳过"
    else
      echo "状态=最新 (current=$current latest=$latest),跳过"
    fi
    uptodate=$((uptodate + 1))
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
    bump_failed=$((bump_failed + 1))
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
    bump_failed=$((bump_failed + 1))
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
  if [[ "$bumped" -gt 0 ]]; then
    echo "✅ 已推送 $bumped 个 cask 更新到 main"
  fi
  if [[ "$readme_updated" -eq 1 ]]; then
    echo "📝 已更新 README 表格"
  fi
else
  echo "ℹ️ 无过期 cask 需更新"
fi

echo "巡检汇总:最新 $uptodate,升级 $bumped,升级失败 $bump_failed,探测失败 $check_failed"

# 写入 Actions run 摘要页(本地运行时该变量为空,自动跳过)
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Bump Casks 巡检结果"
    echo
    echo "| 已是最新 | 成功升级 | 升级失败 | 探测失败 |"
    echo "| --- | --- | --- | --- |"
    echo "| $uptodate | $bumped | $bump_failed | $check_failed |"
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [[ "$check_failed" -gt 0 ]]; then
  echo "⚠️ $check_failed 个 cask 本次未能探测到版本(不计为失败,详见上方日志)"
fi

# 只有"探测到新版本却升级失败"才让 workflow 失败,需要人工介入
if [[ "$bump_failed" -gt 0 ]]; then
  echo "::error title=cask 升级失败::$bump_failed 个 cask 探测到新版本但升级失败,详见日志"
  exit 1
fi

exit 0
