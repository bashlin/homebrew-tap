cask "alt-tab-full" do
  version "11.7.0"
  sha256 "b6e6a1c6eefff0ab1755ec545f3ae6da547ba60c7151fe4536105a55bf41aa42"

  url "https://github.com/Korel/alt-tab-macos/releases/download/fork-v#{version}/AltTab-#{version}-unsigned.dmg"
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
