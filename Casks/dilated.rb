cask "dilated" do
  version "1.0.0-beta.1"
  sha256 "390f7605ac9fc26dba779cf4f84c9ec246a836a3a70ca35a13f063b7494134e0"

  url "https://github.com/CodesWhat/dilated/releases/download/v#{version}/Dilated-#{version}-macos-arm64.dmg"
  name "Dilated"
  desc "Keep your Mac awake, with reasons"
  homepage "https://dilated.codeswhat.com/"

  livecheck do
    skip "Public beta; versions are tracked by scripts/check-cask-drift.sh."
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Dilated.app"
  binary "#{appdir}/Dilated.app/Contents/MacOS/dilated"

  uninstall_preflight_steps do
    run "Dilated.app/Contents/MacOS/dilated", base: :appdir, args: ["package-check"]
  end

  caveats <<~EOS
    Beta release. Closed-lid mode is experimental.
    Not yet verified on hardware: macOS27ClosedLid, helperCrashRecovery, appCrashRecovery, guardTransitions, rebootRecovery, approvalDenied, helperUpgrade, sparkleUpgrade, cleanInstallSecondMac, uninstallNormalSleep, nativeUI.

    Before upgrading, run dilated prepare-update, then brew upgrade --cask dilated.
    Reopen Dilated after the upgrade. Timers keep their original deadlines.
    Before removing, run dilated prepare-uninstall, then brew uninstall --cask dilated.
    Preparation expires after ten minutes. Normal uninstall preserves preferences.
  EOS
end
