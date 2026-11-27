cask "dilated" do
  version "1.1.0"
  sha256 "463726f2267dd66f8753ff8a69817e8db3430b5b4ecd711c2564bd6f98a570a0"

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
