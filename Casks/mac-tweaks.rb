cask "mac-tweaks" do
  version "1.0.1"
  sha256 "a1e1db43a6876ff5b3871732190769ec80afabf89ada04930c249262dd27648f"

  url "https://github.com/NoahCLR/MacTweaks/releases/download/v#{version}/MacTweaks-#{version}.zip"
  name "Mac Tweaks"
  desc "Menu bar utility with opt-in Finder and keyboard tweaks"
  homepage "https://github.com/NoahCLR/MacTweaks"

  depends_on macos: :sonoma

  app "Mac Tweaks.app"

  uninstall quit: "com.noah.MacTweaks"

  zap trash: [
    "~/Library/Application Support/Mac Tweaks/Settings.plist",
    "~/Library/Preferences/com.noah.MacTweaks.plist",
    "~/Library/Preferences/com.noah.MacTweaks.shared.plist",
  ]

  caveats <<~EOS
    Mac Tweaks is signed with a development certificate and is not notarized,
    so Gatekeeper blocks the first launch. Either clear the quarantine flag:
      xattr -dr com.apple.quarantine "/Applications/Mac Tweaks.app"
    or launch once, then approve it under
    System Settings > Privacy & Security > Open Anyway.
    The same applies after every brew upgrade.

    After launching, enable the tweaks you want and grant the permissions
    each one needs (the app's Settings window links to the right panes):
      - Finder extension: System Settings > General > Login Items & Extensions
      - Accessibility + Input Monitoring: System Settings > Privacy & Security
  EOS
end
