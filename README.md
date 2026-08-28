<div align="center">

<a href="https://github.com/CodesWhat">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/CodesWhat/.github/main/profile/dark_mode.svg">
    <img src="https://raw.githubusercontent.com/CodesWhat/.github/main/profile/light_mode.svg" alt="CodesWhat?" width="640">
  </picture>
</a>

<h1>Homebrew Tap</h1>

**Official Homebrew distribution for CodesWhat software.**

</div>

<p align="center">
  <a href="https://brew.sh/"><img src="https://img.shields.io/badge/Homebrew-tap-FBB040?logo=homebrew&logoColor=000000" alt="Homebrew tap"></a>
  <img src="https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-informational?logo=linux&logoColor=white" alt="macOS and Linux">
  <a href="https://github.com/CodesWhat/homebrew-tap/commits/main"><img src="https://img.shields.io/github/last-commit/CodesWhat/homebrew-tap?style=flat" alt="Last commit"></a>
  <a href="https://github.com/CodesWhat/homebrew-tap/issues"><img src="https://img.shields.io/github/issues/CodesWhat/homebrew-tap?style=flat" alt="Issues"></a>
</p>

<hr>

<h2 align="center">📑 Contents</h2>

- [🚀 Quick Start](#quick-start)
- [📦 Available Casks](#available-casks)
- [🔄 Upgrade and Uninstall](#upgrade-and-uninstall)
- [🧾 Brewfile Usage](#brewfile-usage)
- [🖥️ Platform Support](#platform-support)
- [🔐 Release Integrity](#release-integrity)
- [⚙️ How Releases Reach This Tap](#how-releases-reach-this-tap)
- [🩺 Troubleshooting](#troubleshooting)
- [🤝 Contributing and Support](#contributing-and-support)

<hr>

<h2 align="center" id="quick-start">🚀 Quick Start</h2>

Install a product directly from the tap. Homebrew adds the tap automatically, so a
separate `brew tap` command is not required. Using the fully qualified cask name
also trusts only that cask rather than every current and future item in the tap.

```bash
# CareerRat
brew install --cask codeswhat/tap/careerrat

# idlescreen
brew install --cask codeswhat/tap/idlescreen

# Portwing
brew install --cask codeswhat/tap/portwing

# Sockguard
brew install --cask codeswhat/tap/sockguard
```

If you prefer a review-first flow, add the tap, inspect the cask as plain text,
then trust only the cask you intend to install:

```bash
brew tap codeswhat/tap
less "$(brew --repository codeswhat/tap)/Casks/portwing.rb"
brew trust --cask codeswhat/tap/portwing
brew install --cask codeswhat/tap/portwing
```

You can also review every published definition directly in
[`Casks/`](Casks/) before granting trust.

<hr>

<h2 align="center" id="available-casks">📦 Available Casks</h2>

| Product | What it does | Documentation | Availability |
| --- | --- | --- | --- |
| [CareerRat](https://github.com/CodesWhat/careerrat) | Local, offline-first job-search workspace | [Documentation](https://careerrat.com/docs) | Available now |
| [idlescreen](https://github.com/CodesWhat/idlescreen) | Metal-rendered ASCII art screen saver and companion Studio for macOS | [README](https://github.com/CodesWhat/idlescreen#readme) | Available now |
| [Portwing](https://github.com/CodesWhat/portwing) | Security-first remote Docker agent for Drydock and standalone API clients | [Installation guide](https://github.com/CodesWhat/portwing/blob/main/docs/content/docs/installation.mdx) | Available now |
| [Sockguard](https://github.com/CodesWhat/sockguard) | Default-deny Docker socket proxy with granular request filtering and audit logging | [Getting started](https://getsockguard.com/docs/getting-started) | Available now |

This repository distributes official prebuilt release archives. Project source,
configuration, documentation, changelogs, and issue tracking remain in each
product's own repository.

<hr>

<h2 align="center" id="upgrade-and-uninstall">🔄 Upgrade and Uninstall</h2>

Refresh Homebrew metadata and upgrade an installed product:

```bash
brew update
brew upgrade --cask careerrat
brew upgrade --cask idlescreen
brew upgrade --cask portwing
brew upgrade --cask sockguard
```

See what is currently installed:

```bash
brew list --cask
brew info --cask codeswhat/tap/careerrat
brew info --cask codeswhat/tap/idlescreen
brew info --cask codeswhat/tap/portwing
```

Uninstall a product:

```bash
brew uninstall --cask careerrat
brew uninstall --cask idlescreen
brew uninstall --cask portwing
brew uninstall --cask sockguard
```

Remove the tap after uninstalling its casks:

```bash
brew untap codeswhat/tap
```

Homebrew manages the executable, but it does not remove configuration, policy,
credential, log, or service files that you created outside Homebrew's prefix.
Consult the product's uninstall documentation before removing operational data.

<hr>

<h2 align="center" id="brewfile-usage">🧾 Brewfile Usage</h2>

Use a `Brewfile` to make CodesWhat software installation reproducible:

```ruby
tap "codeswhat/tap"

cask "codeswhat/tap/careerrat", trusted: true
cask "codeswhat/tap/idlescreen", trusted: true
cask "codeswhat/tap/portwing", trusted: true
cask "codeswhat/tap/sockguard", trusted: true
```

Apply it with:

```bash
brew bundle install
```

<hr>

<h2 align="center" id="platform-support">🖥️ Platform Support</h2>

The generated command-line casks select the matching official release archive
for the host:

| Operating system | Architectures |
| --- | --- |
| macOS | Apple silicon (`arm64`) and Intel (`amd64`) |
| Linux | `arm64` and `amd64` |

Homebrew itself must be installed and available on `PATH`. See the official
[Homebrew installation guide](https://docs.brew.sh/Installation) and
[Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) for supported host
requirements.

idlescreen is a universal macOS application for Apple silicon and Intel. It
requires macOS 26 Tahoe or later and is not available on Linux.

CareerRat is a macOS application for Apple silicon only. There is no Intel
build. It requires macOS 12 Monterey or later and is not available on Linux.

<hr>

<h2 align="center" id="release-integrity">🔐 Release Integrity</h2>

Each cask:

- downloads archives only from the corresponding official CodesWhat GitHub
  Releases page;
- pins a SHA-256 digest for every release artifact;
- lets Homebrew verify that digest before installing the executable; and
- exposes the upstream project homepage and product-specific operational
  caveats through `brew info`.

Homebrew 6 and later requires explicit trust for non-official taps because cask
definitions are executable Ruby. A fully qualified install such as
`brew install --cask codeswhat/tap/portwing` trusts only that named cask. This
README intentionally does not recommend trusting the entire tap; use
`brew trust --cask` when you want an explicit review-and-trust step.

Treat a checksum mismatch as a failed verification. Do not bypass it. Run
`brew update`, confirm the upstream release exists, and report the mismatch if
it persists.

Project-specific signing, provenance, SBOM, and runtime-security documentation
lives with the project:

- [CareerRat release process](https://github.com/CodesWhat/careerrat/blob/main/docs/RELEASE.md)
- [Portwing release verification](https://github.com/CodesWhat/portwing/blob/main/docs/content/docs/verification.mdx)
- [Sockguard documentation](https://getsockguard.com/docs)
- [idlescreen building and release verification](https://github.com/CodesWhat/idlescreen/blob/main/docs/BUILDING.md)

> [!IMPORTANT]
> Installing Portwing or Sockguard does not configure Docker access, create
> authentication credentials, or grant runtime permissions. Follow the relevant
> product guide before starting either service.

<hr>

<h2 align="center" id="how-releases-reach-this-tap">⚙️ How Releases Reach This Tap</h2>

The casks under [`Casks/`](Casks/) are generated by the owning source project's
release tooling. On each stable release, the source project:

1. builds archives for the supported platforms and architectures;
2. publishes those artifacts and their checksums to GitHub Releases;
3. renders the cask with the exact version, download URLs, and SHA-256 digests;
4. commits the generated cask to this repository; and
5. smoke-tests installation from `codeswhat/tap` on a clean runner.

Snapshots and prereleases do not update the tap. Each cask header identifies
the generator that owns it. Do not edit a generated cask by hand. Fix the
generator in the source project so the next release preserves the change.

```ruby
# This file was generated by idlescreen. DO NOT EDIT.
```

> [!NOTE]
> The careerrat cask is generated the same way, by
> `scripts/generate-homebrew-cask.sh` in the CareerRat project, but it reaches
> this tap by being pulled rather than pushed. A scheduled workflow here,
> [`update-careerrat-cask.yml`](.github/workflows/update-careerrat-cask.yml),
> watches for a new published CareerRat release, runs that generator against
> it, and commits the result. The "do not edit a generated cask by hand"
> guidance applies to it exactly as it does to the rest.

Two checks in this repository verify the result, because a cask that is pushed
here by another project's tooling is otherwise unexamined until a user hits it:

- [`cask-ci.yml`](.github/workflows/cask-ci.yml) audits every cask on each pull
  request and each push to `main`, so a malformed cask is caught in seconds
  rather than in a bug report.
- [`cask-drift-sentinel.yml`](.github/workflows/cask-drift-sentinel.yml) runs
  daily and fails if any cask has fallen behind the latest release of the
  project that owns it, or if any download URL has stopped resolving.

Both are plain scripts under [`scripts/`](scripts/) and can be run locally:

```bash
bash scripts/check-cask-drift.sh
bash scripts/audit-casks.sh --online
```

<hr>

<h2 align="center" id="troubleshooting">🩺 Troubleshooting</h2>

### Homebrew cannot find a cask

Refresh metadata and inspect the tap:

```bash
brew update
brew tap codeswhat/tap
brew tap-info codeswhat/tap
ls "$(brew --repository codeswhat/tap)/Casks"
```

If a stable release was published moments ago, wait for its release workflow to
finish before retrying.

### The command is not on `PATH`

Follow the shell setup printed by the Homebrew installer, then open a new shell.
You can inspect the active prefix with:

```bash
brew --prefix
brew doctor
```

### A checksum does not match

Do not force the installation. Refresh the tap and retry once:

```bash
brew update
brew install --cask codeswhat/tap/idlescreen
```

If the mismatch remains, open a tap issue and include the cask name, requested
version, operating system, architecture, and complete Homebrew error. Never
include credentials or private configuration.

### macOS blocks an app or executable

Install through this tap rather than running an archive copied from another
machine. Then consult the product's installation guide for its current signing
and notarization status. Do not disable Gatekeeper globally.

<hr>

<h2 align="center" id="contributing-and-support">🤝 Contributing and Support</h2>

Use the issue tracker that owns the problem:

| Problem | Report it here |
| --- | --- |
| Tap discovery, download, checksum, or Homebrew installation | [CodesWhat/homebrew-tap issues](https://github.com/CodesWhat/homebrew-tap/issues) |
| CareerRat behavior or configuration | [CodesWhat/careerrat issues](https://github.com/CodesWhat/careerrat/issues) |
| idlescreen behavior or configuration | [CodesWhat/idlescreen issues](https://github.com/CodesWhat/idlescreen/issues) |
| Portwing behavior or configuration | [CodesWhat/portwing issues](https://github.com/CodesWhat/portwing/issues) |
| Sockguard behavior or policy configuration | [CodesWhat/sockguard issues](https://github.com/CodesWhat/sockguard/issues) |
| Private security vulnerability | The security-reporting process in the affected project's `SECURITY.md` |

README improvements are welcome here. Changes to generated casks should be made
in the owning source repository, where they can be validated by the complete
release pipeline.

<p align="center">
  Built and maintained by <a href="https://github.com/CodesWhat">CodesWhat?</a>
</p>
