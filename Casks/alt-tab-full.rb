cask "alt-tab-full" do
  version "11.5.0"
  sha256 "330008659381b118c581f9b468b29b1f5f00ff29564be27c7d5e06876d649b92"

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
