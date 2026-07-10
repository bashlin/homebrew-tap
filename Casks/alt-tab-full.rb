cask "alt-tab-full" do
  version "11.4.3"
  sha256 "3f615ab7ab9d2a966af583b225f5ab503db6c3212f5a17efbc18a0c4ccab422d"

  url "https://github.com/Korel/alt-tab-macos/releases/download/fork-v#{version}/AltTab-#{version}-unsigned.dmg",
      verified: "github.com/Korel/alt-tab-macos/"
  name "AltTab"
  desc "Enable Windows-like alt-tab (unsigned)"
  homepage "https://github.com/Korel/alt-tab-macos"

  livecheck do
    url :url
    strategy :github_releases
    regex(/^fork-v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on :macos

  app "AltTab.app"

  uninstall quit: "com.lwouis.alt-tab-macos"

  zap trash: [
    "~/Library/Application Support/com.lwouis.alt-tab-macos",
    "~/Library/Caches/com.lwouis.alt-tab-macos",
    "~/Library/Caches/com.plausiblelabs.crashreporter.data/com.lwouis.alt-tab-macos",
    "~/Library/Cookies/com.lwouis.alt-tab-macos.binarycookies",
    "~/Library/HTTPStorages/com.lwouis.alt-tab-macos",
    "~/Library/HTTPStorages/com.lwouis.alt-tab-macos.binarycookies",
    "~/Library/LaunchAgents/com.lwouis.alt-tab-macos.plist",
    "~/Library/Preferences/com.lwouis.alt-tab-macos.license.plist",
    "~/Library/Preferences/com.lwouis.alt-tab-macos.plist",
    "~/Library/Preferences/com.lwouis.alt-tab-macos.usage.plist",
  ]
end
