cask "dilated" do
  version "1.0.0-beta.6"
  sha256 "36b1e89b5ba97f71a2778568a21aeeed10d8e097d87b2f08842b9e89a064124e"

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
    Not yet verified on hardware: macOS27ClosedLid, helperCrashRecovery, appCrashRecovery, guardTransitions, rebootRecovery, approvalDenied, helperUpgrade, uninstallNormalSleep, nativeUI.

    Before upgrading, run dilated prepare-update, then brew upgrade --cask dilated.
    Reopen Dilated after the upgrade. Timers keep their original deadlines.
    Before removing, run dilated prepare-uninstall, then brew uninstall --cask dilated.
    Preparation expires after ten minutes. Normal uninstall preserves preferences.
  EOS
end
