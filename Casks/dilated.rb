cask "dilated" do
  version "1.0.0-beta.2"
  sha256 "7b668d6097806ce181122a86411d6000669e337d4d9f9450823ef23b037c6c99"

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
