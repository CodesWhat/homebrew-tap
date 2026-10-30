cask "dilated" do
  version "1.0.0-beta.5"
  sha256 "fcb19813722477c468b85736cd19e2056b623c0c49f7d9d26933aa40b8fbfba3"

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
