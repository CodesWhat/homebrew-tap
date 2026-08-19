# Hand-written. CareerRat has no release automation that generates this
# cask yet (unlike idlescreen's scripts/generate-homebrew-cask.sh). Update
# this file in place until that generator exists.
cask "careerrat" do
  version "0.10.0"
  sha256 "e12448f6b29e7a5685c475b67311dcfcbd93d5c56010e6049e51780e44872e2e"

  url "https://github.com/CodesWhat/careerrat/releases/download/v#{version}/CareerRat-#{version}-arm64.dmg"
  name "CareerRat"
  desc "Local, offline-first job-search workspace"
  homepage "https://careerrat.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  # Matches LSMinimumSystemVersion baked into the app by electron-builder.
  depends_on macos: :monterey

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
    CareerRat is arm64-only today. There is no Intel build.
    This cask installs the desktop app only. The npm CLI is a separate install.
  EOS
end
