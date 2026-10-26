# Frozen at CareerRat 0.19.2, the last Mac app release. CareerRat now ships
# through npm only, so this cask is maintained by hand here and deprecated.
cask "careerrat" do
  version "0.19.2"
  sha256 "78683fc652c3b28c708089a776f697a2e731b5ffdbb958c48134ab3f2127b573"

  url "https://github.com/CodesWhat/careerrat/releases/download/v#{version}/CareerRat-#{version}-arm64.dmg"
  name "CareerRat"
  desc "Local, offline-first job-search workspace"
  homepage "https://careerrat.com/"

  deprecate! date: "2026-10-26", because: "is now distributed through npm; install it with `npm install -g careerrat`"

  livecheck do
    skip "No further Mac releases; CareerRat moved to npm."
  end

  depends_on arch: :arm64
  # Matches LSMinimumSystemVersion in the shipped app (13.0 since Electron 44;
  # the tap's artifact audit rejects a lower declared minimum).
  depends_on macos: :ventura

  app "CareerRat.app"

  uninstall quit: "com.codeswhat.careerrat"

  # The packaged app sets CAREERRAT_HOME to <userData>/data, so the whole job
  # search (tracker, candidate profile, artifacts) lives under the first path
  # here. Only `brew uninstall --zap` touches it; a plain uninstall leaves it.
  zap trash: [
    "~/Library/Application Support/CareerRat",
    "~/Library/Preferences/com.codeswhat.careerrat.plist",
  ]

  caveats <<~EOS
    CareerRat 0.19.2 is the last Mac app release. New versions ship on npm:
      npm install -g careerrat
  EOS
end
