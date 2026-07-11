cask "bambucam" do
  version "1.0.1"
  sha256 "f351ce6fb9924b3334fb9bbd0637efacddc8c492e74ef426d982f14be4709691"

  url "https://github.com/NoahCLR/BambuCam/releases/download/v#{version}/BambuCam-#{version}.zip"
  name "BambuCam"
  desc "Local-only Bambu Lab printer camera and status client"
  homepage "https://github.com/NoahCLR/BambuCam"

  depends_on macos: :sequoia

  app "BambuCam.app"

  uninstall quit: "com.ncleroy.BambuCam"

  # List specific files only — never the whole Application Support directory
  # (on the dev machine it also contains the local signing key).
  zap trash: [
    "~/.bambucam",
    "~/Library/Application Support/BambuCam/config.json",
    "~/Library/Preferences/com.ncleroy.BambuCam.plist",
    "~/Library/Saved Application State/com.ncleroy.BambuCam.savedState",
  ]

  caveats <<~EOS
    BambuCam is signed with a development certificate and is not notarized,
    so Gatekeeper blocks the first launch. Either clear the quarantine flag:
      xattr -dr com.apple.quarantine "/Applications/BambuCam.app"
    or launch once, then approve it under
    System Settings > Privacy & Security > Open Anyway.
    The same applies after every brew upgrade.

    Printer access codes and certificate pins live in the macOS Keychain and
    are not removed by uninstall or zap. To remove them:
      security delete-generic-password -s com.ncleroy.BambuCam.printer-secrets
    (repeat until it reports no matching item).
  EOS
end
