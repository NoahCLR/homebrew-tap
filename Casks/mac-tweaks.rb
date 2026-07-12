cask "mac-tweaks" do
  version "1.2.0"
  sha256 "9c843376ea266de324b34c9eba22dd36ba99c5665c759e2a3bb08c862c9b5a54"

  url "https://github.com/NoahCLR/MacTweaks/releases/download/v#{version}/MacTweaks-#{version}.zip"
  name "Mac Tweaks"
  desc "Menu bar utility with opt-in Finder and keyboard tweaks"
  homepage "https://github.com/NoahCLR/MacTweaks"

  depends_on macos: :sonoma

  app "Mac Tweaks.app"

  postflight do
    system_command "/usr/bin/pluginkit",
                   args: ["-a", "#{appdir}/Mac Tweaks.app/Contents/PlugIns/MacTweaksFinderExtension.appex"]
  end

  # com.noah.MacTweaks is the pre-rename bundle id (≤ v1.1.4): brew upgrade runs
  # this stanza against the *installed* version, so quit both, and zap cleans up
  # preferences either generation may have left behind.
  uninstall quit: [
    "com.ncleroy.MacTweaks",
    "com.noah.MacTweaks",
  ]

  zap trash: [
    "~/Library/Application Support/Mac Tweaks/Settings.plist",
    "~/Library/Preferences/com.ncleroy.MacTweaks.plist",
    "~/Library/Preferences/com.ncleroy.MacTweaks.shared.plist",
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
      - Accessibility: System Settings > Privacy & Security
      - Screen Recording (OCR only): System Settings > Privacy & Security
  EOS
end
