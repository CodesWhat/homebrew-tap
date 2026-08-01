<div align="center">

<a href="https://github.com/CodesWhat">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/CodesWhat/.github/main/profile/dark_mode.svg">
    <img src="https://raw.githubusercontent.com/CodesWhat/.github/main/profile/light_mode.svg" alt="CodesWhat?" width="640">
  </picture>
</a>

<h1>Homebrew Tap</h1>

**Official Homebrew distribution for CodesWhat command-line tools.**

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

Install a tool directly from the tap. Homebrew adds the tap automatically, so a
separate `brew tap` command is not required. Using the fully qualified cask name
also trusts only that cask rather than every current and future item in the tap.

```bash
# Portwing
brew install --cask codeswhat/tap/portwing

# Sockguard
brew install --cask codeswhat/tap/sockguard
```

> [!NOTE]
> The Sockguard cask will become available with the first stable Sockguard
> release that includes Homebrew publishing. Until then, its install command
> returns `Cask 'sockguard' is unavailable`.

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

| Tool | What it does | Documentation | Availability |
| --- | --- | --- | --- |
| [Portwing](https://github.com/CodesWhat/portwing) | Security-first remote Docker agent for Drydock and standalone API clients | [Installation guide](https://github.com/CodesWhat/portwing/blob/main/docs/content/docs/installation.mdx) | Available now |
| [Sockguard](https://github.com/CodesWhat/sockguard) | Default-deny Docker socket proxy with granular request filtering and audit logging | [Getting started](https://getsockguard.com/docs/getting-started) | Next stable release |

This repository distributes official prebuilt release archives. Project source,
configuration, documentation, changelogs, and issue tracking remain in each
tool's own repository.

<hr>

<h2 align="center" id="upgrade-and-uninstall">🔄 Upgrade and Uninstall</h2>

Refresh Homebrew metadata and upgrade an installed tool:

```bash
brew update
brew upgrade --cask portwing
brew upgrade --cask sockguard
```

See what is currently installed:

```bash
brew list --cask
brew info --cask codeswhat/tap/portwing
```

Uninstall a tool:

```bash
brew uninstall --cask portwing
brew uninstall --cask sockguard
```

Remove the tap after uninstalling its tools:

```bash
brew untap codeswhat/tap
```

Homebrew manages the executable, but it does not remove configuration, policy,
credential, log, or service files that you created outside Homebrew's prefix.
Consult the product's uninstall documentation before removing operational data.

<hr>

<h2 align="center" id="brewfile-usage">🧾 Brewfile Usage</h2>

Use a `Brewfile` to make CodesWhat tool installation reproducible:

```ruby
tap "codeswhat/tap"

cask "codeswhat/tap/portwing", trusted: true
cask "codeswhat/tap/sockguard", trusted: true
```

Apply it with:

```bash
brew bundle install
```

Omit the Sockguard line until its Homebrew-enabled stable release is published.

<hr>

<h2 align="center" id="platform-support">🖥️ Platform Support</h2>

The generated casks select the matching official release archive for the host:

| Operating system | Architectures |
| --- | --- |
| macOS | Apple silicon (`arm64`) and Intel (`amd64`) |
| Linux | `arm64` and `amd64` |

Homebrew itself must be installed and available on `PATH`. See the official
[Homebrew installation guide](https://docs.brew.sh/Installation) and
[Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) for supported host
requirements.

<hr>

<h2 align="center" id="release-integrity">🔐 Release Integrity</h2>

Each cask:

- downloads archives only from the corresponding official CodesWhat GitHub
  Releases page;
- pins a SHA-256 digest for every operating-system and architecture pair;
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

- [Portwing release verification](https://github.com/CodesWhat/portwing/blob/main/docs/content/docs/verification.mdx)
- [Sockguard documentation](https://getsockguard.com/docs)

> [!IMPORTANT]
> Installing a tool does not configure access to Docker, create authentication
> credentials, or grant the runtime permissions it needs. Follow the relevant
> product guide before starting it.

<hr>

<h2 align="center" id="how-releases-reach-this-tap">⚙️ How Releases Reach This Tap</h2>

The casks under [`Casks/`](Casks/) are generated by GoReleaser from the source
project's release configuration. On each stable release, the source project:

1. builds archives for the supported platforms and architectures;
2. publishes those artifacts and their checksums to GitHub Releases;
3. renders the cask with the exact version, download URLs, and SHA-256 digests;
4. commits the generated cask to this repository; and
5. smoke-tests installation from `codeswhat/tap` on a clean runner.

Snapshots and prereleases do not update the tap. The cask header identifies
generated files:

```ruby
# This file was generated by GoReleaser. DO NOT EDIT.
```

Do not edit a generated cask by hand. Fix its GoReleaser configuration in the
source project so the next release preserves the change.

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
brew install --cask codeswhat/tap/portwing
```

If the mismatch remains, open a tap issue and include the cask name, requested
version, operating system, architecture, and complete Homebrew error. Never
include credentials or private configuration.

### macOS blocks an executable

Install through this tap rather than running an archive copied from another
machine. Then consult the product's installation guide for its current signing
and notarization status. Do not disable Gatekeeper globally.

<hr>

<h2 align="center" id="contributing-and-support">🤝 Contributing and Support</h2>

Use the issue tracker that owns the problem:

| Problem | Report it here |
| --- | --- |
| Tap discovery, download, checksum, or Homebrew installation | [CodesWhat/homebrew-tap issues](https://github.com/CodesWhat/homebrew-tap/issues) |
| Portwing behavior or configuration | [CodesWhat/portwing issues](https://github.com/CodesWhat/portwing/issues) |
| Sockguard behavior or policy configuration | [CodesWhat/sockguard issues](https://github.com/CodesWhat/sockguard/issues) |
| Private security vulnerability | The security-reporting process in the affected project's `SECURITY.md` |

README improvements are welcome here. Changes to generated casks should be made
in the owning source repository, where they can be validated by the complete
release pipeline.

<p align="center">
  Built and maintained by <a href="https://github.com/CodesWhat">CodesWhat?</a>
</p>
