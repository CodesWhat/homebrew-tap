cask "dilated" do
  version "1.0.1"
  sha256 "7411b693a38a76f3aa819215e3632eda388f7002da67b3a4fa99e01656de778c"

  url "https://github.com/CodesWhat/dilated/releases/download/v#{version}/Dilated-#{version}-macos-arm64.dmg"
  name "Dilated"
  desc "Keep your Mac awake, with reasons"
  homepage "https://dilated.app/"
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
