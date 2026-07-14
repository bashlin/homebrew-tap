#!/usr/bin/env ruby
# update_readme.rb
#
# 扫描 Casks/*.rb,解析每个 cask 的 name / homepage / version,
# 并用 git log 读取该 cask 文件最近一次提交日期作为"更新日期",
# 重写 README.md 中 <!-- BEGIN CASK TABLE --> ... <!-- END CASK TABLE -->
# 之间的表格,README 其余内容保持不变。
#
# 设计要点:
#   - 仅替换带标记的表格区块,手写的说明文字不会被覆盖
#   - 字段全部从 cask 脚本与 git 历史解析,无需额外配置
#   - 新增 cask 后无需手改 README,下次巡检自动补齐
require "pathname"

# 强制 UTF-8,避免在 LANG 未设置的环境下把中文当成非法字节序列
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

tap_dir   = Pathname.new(File.expand_path("../..", __dir__))
casks_dir = tap_dir / "Casks"
readme    = tap_dir / "README.md"

# 收集并排序所有 cask 脚本,保证表格行顺序稳定
cask_files = casks_dir.children.select { |p| p.extname == ".rb" }.sort

rows = cask_files.map do |file|
  content   = file.read
  name      = content[/^\s*name\s+"([^"]*)"/,      1]
  homepage  = content[/^\s*homepage\s+"([^"]*)"/,  1]
  version   = content[/^\s*version\s+"([^"]*)"/,   1]
  unless name && homepage && version
    warn "⚠️  跳过 #{file.basename}: 解析 name/homepage/version 失败"
    next
  end

  rel   = file.relative_path_from(tap_dir).to_s
  # 最近一次"version 行变更"的提交日期,严格反映版本变更:
  # -G 只匹配 diff 中增删了 version 行的提交,故改 desc/zap 等非版本行
  # 的提交不会改动此日期。未提交过的新文件回退为 "-"。
  date  = `git -C "#{tap_dir}" log -1 --format=%cd --date=short -G '^[[:space:]]*version[[:space:]]' -- "#{rel}" 2>/dev/null`.strip
  date  = "-" if date.empty?

  # 主页链接文本去掉协议前缀,与原 README 风格一致
  host_label = homepage.sub(%r{^https?://}, "")
  "| #{name} | [#{host_label}](#{homepage}) | [#{rel}](#{rel}) | #{version} | #{date} |"
end.compact

table = <<~TABLE
  | 名称 | 主页 | 对应脚本 | 版本号 | 更新日期 |
  | --- | --- | --- | --- | --- |
  #{rows.join("\n")}
TABLE

new_block = "<!-- BEGIN CASK TABLE -->\n#{table}<!-- END CASK TABLE -->"

content = readme.read
if content.sub!(/<!-- BEGIN CASK TABLE -->.*<!-- END CASK TABLE -->/m, new_block)
  readme.write(content)
  puts "📝 README 表格已更新,共 #{rows.size} 个 cask"
else
  # README 缺少标记锚点时,把表格追加到文件末尾
  readme.write(content.rstrip + "\n\n" + new_block + "\n")
  puts "📝 README 末尾新增表格(未找到标记锚点),共 #{rows.size} 个 cask"
end
