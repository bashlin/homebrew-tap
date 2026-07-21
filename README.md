# Bashlin Tap

个人 Homebrew Tap,用于分发一些 macOS cask 应用。

对应 GitHub 仓库 [bashlin/homebrew-tap](https://github.com/bashlin/homebrew-tap);按 Homebrew 命名约定,tap 名为 `bashlin/tap`(自动去掉 `homebrew-` 前缀)。

## 如何添加该 Tap

> **关于 Tap-Trust**:自 [Homebrew 6.0](https://brew.sh/2026/06/11/homebrew-6.0.0/) 起,非官方 tap 需显式信任才能安装,否则 `brew install` 会失败。用**全限定名**安装会自动信任该包,故方式一最简单。用 `brew trust` 列出已信任项,`brew untrust bashlin/tap` 撤销信任。详见 [Tap-Trust 文档](https://docs.brew.sh/Tap-Trust)。

### 方式一:全限定名直接安装(推荐)

未 tap 时会自动添加 tap,且全限定名安装会自动信任该 cask,一条命令即可:

```bash
brew install --cask bashlin/tap/alt-tab-full
```

### 方式二:先添加 Tap 再用短名安装

添加 tap 后需信任该 cask(或整个 tap),再用短名安装:

```bash
brew tap bashlin/tap
brew trust --cask bashlin/tap/alt-tab-full   # 信任该 cask;或信任整个 tap:brew trust bashlin/tap
brew install --cask alt-tab-full
```

### 在 Brewfile 中使用

```ruby
cask "bashlin/tap/alt-tab-full", trusted: true
```

或显式添加 tap 并仅信任其中的 cask:

```ruby
tap "bashlin/tap", trusted: { casks: ["alt-tab-full"] }
cask "alt-tab-full"
```

### 移除 Tap

```bash
brew untap bashlin/tap
```

## Cask 列表

> 以下表格由 [update_readme.rb](.github/scripts/update_readme.rb) 在每日巡检时自动生成,请勿手动编辑。

<!-- BEGIN CASK TABLE -->
| 名称 | 主页 | 对应脚本 | 版本号 | 更新日期 |
| --- | --- | --- | --- | --- |
| AltTab | [github.com/Korel/alt-tab-macos](https://github.com/Korel/alt-tab-macos) | [Casks/alt-tab-full.rb](Casks/alt-tab-full.rb) | 11.4.3 | 2026-07-21 |
| X1a0He WeChat Plugin | [github.com/X1a0He/X1a0HeWeChatPlugin](https://github.com/X1a0He/X1a0HeWeChatPlugin) | [Casks/x1a0he-wechat-plugin.rb](Casks/x1a0he-wechat-plugin.rb) | 2.6.4,4.1.12.22,42530 | 2026-07-21 |
<!-- END CASK TABLE -->

## 文档

`brew help`、`man brew` 或查看 [Homebrew 文档](https://docs.brew.sh)。
