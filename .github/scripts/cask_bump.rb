#!/usr/bin/env ruby
# cask_bump.rb <cask_file> <new_version>
#
# 作用:从 cask 脚本中提取 url 模板,用新版本插值得到真实下载地址,
# 下载该包并计算 sha256,随后改写 cask 文件里的 version 与 sha256 行。
# 成功时将新 sha256 打印到 stdout(供 bash 侧记录);失败时非 0 退出。
#
# 注意:下载在临时目录完成、写回文件在下载成功之后,故下载失败不会破坏原文件。
require "open-uri"
require "tmpdir"
require "digest"

file, new_ver = ARGV
abort "用法: cask_bump.rb <cask_file> <new_version>" unless file && new_ver

content = File.read(file)

# 提取 url "..." 模板(行首缩进 + url 关键字 + 双引号字符串,支持转义)
tmpl = content[/^\s*url\s+"((?:[^"\\]|\\.)*)"/m, 1] \
  or abort "无法从 #{file} 解析 url 模板"

# 兼容 CSV version 及常见的 version 派生方法。
csv_parts = new_ver.split(",", -1)
primary_version = csv_parts.first
major, minor, patch = primary_version.split(".")
url = tmpl
%w[first second third fourth fifth].each_with_index do |name, index|
  url.gsub!("\#{version.csv.#{name}}", csv_parts[index].to_s)
end
url = url
  .gsub('#{version.major}',      major.to_s)
  .gsub('#{version.minor}',      minor.to_s)
  .gsub('#{version.patch}',      patch.to_s)
  .gsub('#{version.major_minor}', "#{major}.#{minor}")
  .gsub('#{version}',            new_ver)

puts "下载: #{url}"
Dir.mktmpdir do |dir|
  tmp = File.join(dir, "pkg")
  # User-Agent 部分服务器要求;此处统一带上
  IO.copy_stream(URI.open(url, "r", "User-Agent" => "brew-bump/1.0"), tmp)

  sha = Digest::SHA256.file(tmp).hexdigest
  puts "sha256: #{sha}"

  # 改写 version 与 sha256 两行;保留原有缩进
  unless content.sub!(/^(\s*version\s+)"[^"]*"/, "\\1\"#{new_ver}\"")
    abort "未匹配到 version 行"
  end
  unless content.sub!(/^(\s*sha256\s+)"[^"]*"/, "\\1\"#{sha}\"")
    abort "未匹配到 sha256 行"
  end

  File.write(file, content)
  puts sha # 供 bash 侧捕获
end
