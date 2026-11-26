cask "dilated" do
  version "1.0.0"
  sha256 "e5a796d63ec9b4a2da427a8f97d396766ea1f5842961a7a0cf6813463e09beaa"

  url "https://github.com/CodesWhat/dilated/releases/download/v#{version}/Dilated-#{version}-macos-arm64.dmg"
  name "Dilated"
  desc "Keep your Mac awake, with reasons"
  homepage "https://dilated.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Dilated.app"
  binary "#{appdir}/Dilated.app/Contents/MacOS/dilated"

  uninstall_preflight_steps do
    run "Dilated.app/Contents/MacOS/dilated", base: :appdir, args: ["package-check"]
  end

  zap delete: "/private/etc/sudoers.d/dilated"

  caveats <<~EOS
    Closed-lid mode is experimental.
    Not yet verified on hardware: macOS26ClosedLid, macOS27ClosedLid, sudoRuleRevoked, appCrashRecovery, heartbeatExpiry, stopResume, guardTransitions, rebootRecovery, adminPromptCancelled, helperMigration, sudoRuleIntegrity, sparkleUpgrade, uninstallNormalSleep, nativeUI.

    Before upgrading, run dilated prepare-update, then brew upgrade --cask dilated.
    Reopen Dilated after the upgrade. Timers keep their original deadlines.
    Before removing, run dilated prepare-uninstall, then brew uninstall --cask dilated.
    Preparation expires after ten minutes. Normal uninstall preserves preferences.
  EOS
end
