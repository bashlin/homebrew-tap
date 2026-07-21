cask "x1a0he-wechat-plugin" do
  version "2.6.4,4.1.12.22,42530"
  sha256 "f675514fe2ac7d6e6401899cf7013a5081b192d2cd9597e5a479e6f7c0131a9e"

  url "https://github.com/X1a0He/X1a0HeWeChatPlugin/releases/download/#{version.csv.first}/X1a0HeWeChatPlugin.pkg"
  name "X1a0He WeChat Plugin"
  desc "WeChat plugin with anti-recall, multi-instance, and update-blocking features"
  homepage "https://github.com/X1a0He/X1a0HeWeChatPlugin"

  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest do |json, regex|
      plugin_version = json["tag_name"]&.[](regex, 1)
      wechat_versions = json["body"]&.scan(/\u652f\u6301\s+v?(\d+(?:\.\d+)+)\s*\((\d+)\)/i)
      latest_wechat = wechat_versions&.last
      next if plugin_version.blank? || latest_wechat.blank?

      "#{plugin_version},#{latest_wechat[0]},#{latest_wechat[1]}"
    end
  end

  depends_on :macos
  depends_on arch: :arm64

  wechat_paths = [
    "/Applications/WeChat.app",
    "/Applications/\u5fae\u4fe1.app",
  ].freeze

  pkg "X1a0HeWeChatPlugin.pkg"

  preflight do
    wechat_path = wechat_paths.find { |path| File.directory?(path) }
    unless wechat_path
      raise Cask::CaskError,
            "#{token}: WeChat #{version.csv.second} (#{version.csv.third}) must be installed in /Applications"
    end

    if File.exist?("#{wechat_path}/Contents/_MASReceipt/receipt")
      raise Cask::CaskError, "#{token}: the Mac App Store version of WeChat is not supported"
    end

    info_plist = "#{wechat_path}/Contents/Info.plist"
    installed_version = system_command("/usr/libexec/PlistBuddy",
                                       args:         ["-c", "Print :CFBundleShortVersionString", info_plist],
                                       print_stderr: false).stdout.strip
    installed_build = system_command("/usr/libexec/PlistBuddy",
                                     args:         ["-c", "Print :CFBundleVersion", info_plist],
                                     print_stderr: false).stdout.strip
    if installed_version != version.csv.second || installed_build != version.csv.third
      raise Cask::CaskError,
            "#{token}: requires WeChat #{version.csv.second} (#{version.csv.third}); " \
            "found #{installed_version} (#{installed_build})"
    end

    wechat_running = system_command("/usr/bin/pgrep",
                                    args:         ["-x", "WeChat"],
                                    must_succeed: false,
                                    print_stderr: false).success?
    raise Cask::CaskError, "#{token}: quit WeChat before installing the plugin" if wechat_running
  end

  uninstall_postflight do
    wechat_path = wechat_paths.find { |path| File.directory?(path) }
    next unless wechat_path

    executable_paths = [
      "#{wechat_path}/Contents/Resources/wechat.dylib",
      "#{wechat_path}/Contents/Frameworks/wechat.dylib",
    ]
    executable_path = executable_paths.find { |path| File.file?("#{path}.original") }

    unless executable_path
      puts "Original WeChat library backup was not found; reinstall WeChat to complete removal."
      next
    end

    plugin_path = "#{wechat_path}/Contents/Frameworks/X1a0HeWeChatPlugin.dylib"
    system_command "/bin/cp", args: ["#{executable_path}.original", executable_path], sudo: true
    system_command "/bin/rm", args: ["-f", "#{executable_path}.original", plugin_path], sudo: true
    system_command "/usr/bin/codesign",
                   args: ["-f", "-s", "-", "--preserve-metadata=entitlements", wechat_path],
                   sudo: true
  end

  uninstall quit:    "com.tencent.xinWeChat",
            pkgutil: "com.x1a0he.wechatplugin"

  # No zap stanza: plugin preferences share WeChat's preferences domain.

  caveats <<~EOS
    This plugin only supports the non-MAS Apple Silicon build of WeChat
    #{version.csv.second} (#{version.csv.third}). Download it from:
      https://dldir1v6.qq.com/weixin/Universal/Mac/xWeChatMac_universal_#{version.csv.second}_#{version.csv.third}.dmg

    The upstream package is unsigned and modifies WeChat.app. Uninstalling this
    cask restores the backed-up library and ad-hoc signs WeChat.app; reinstall
    the official WeChat package to restore Tencent's original code signature.
  EOS
end
