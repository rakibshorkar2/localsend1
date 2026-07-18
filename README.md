# LocalSend

> **Share files. No strings attached. No cloud. No internet. Just pure, peer-to-peer speed.**

[![CI status][ci-badge]][ci-workflow]
[![Translations][translate-badge]][translate-link]
[![Packaging status][packaging-badge]][packaging-link]

[ci-badge]: https://github.com/localsend/localsend/actions/workflows/ci.yml/badge.svg
[ci-workflow]: https://github.com/localsend/localsend/actions/workflows/ci.yml
[translate-badge]: https://hosted.weblate.org/widget/localsend/app/svg-badge.svg
[translate-link]: https://hosted.weblate.org/engage/localsend/
[packaging-badge]: https://repology.org/badge/tiny-repos/localsend.svg
[packaging-link]: https://repology.org/project/localsend/versions

[Homepage][homepage] • [Discord][discord] • [GitHub][github] • [Codeberg][codeberg]

[English (Default)](README.md) • [Español](/support/readme/README_ES.md) • [فارسی](/support/readme/README_FA.md) • [Filipino](/support/readme/README_PH.md) • [Français](/support/readme/README_FR.md) • [Indonesia](/support/readme/README_ID.md) • [Italiano](/support/readme/README_IT.md) • [日本語](/support/readme/README_JA.md) • [ភាសាខ្មែរ](/support/readme/README_KM.md) • [한국어](/support/readme/README_KO.md) • [Polski](/support/readme/README_PL.md) • [Português Brasil](/support/readme/README_PT_BR.md) • [Русский](/support/readme/README_RU.md) • [ภาษาไทย](/support/readme/README_TH.md) • [Türkçe](/support/readme/README_TR.md) • [Українська](/support/readme/README_UK.md) • [Tiếng Việt](/support/readme/README_VI.md) • [中文](/support/readme/README_ZH.md)

[homepage]: https://localsend.org
[discord]: https://discord.gg/GSRWmQNP87
[github]: https://github.com/localsend/localsend
[codeberg]: https://codeberg.org/localsend/localsend

---

## ✦ About

**LocalSend** is a free, open-source, cross-platform app that lets you securely shoot files and messages to nearby devices over your local network — no internet, no servers, no cloud middlemen. Just your devices talking directly via encrypted HTTPS.

```
You → 📱 → 🌐 (local network) → 💻 → Them
```

## ✦ What Makes It Different

| Other Apps | LocalSend |
|------------|-----------|
| Require internet & cloud servers | Works fully offline on LAN |
| Data passes through third parties | End-to-end encrypted, direct P2P |
| Slow for large files | Blazing fast local network speeds |
| Limited platform support | Android • iOS • macOS • Windows • Linux |

## ✦ What's New

- **Live Activity & Dynamic Island** — iOS users stay in the loop with real-time transfer progress right on the Lock Screen and Dynamic Island. No need to open the app.
- **Background Keepalive** — Transfers keep running even when the app is in the background. Silent audio + location services ensure your files always arrive.
- **Background Transfer Service** — Robust native background upload/download engine for iOS.

## ✦ Sponsors

Browser testing via

<a href="https://www.testmuai.com/?utm_medium=sponsor&utm_source=localsend" target="_blank">
    <img src="https://localsend.org/img/sponsors/tesmu.svg" style="vertical-align: middle;" width="250" height="45" />
</a>

## ✦ Screenshots

<img src="https://localsend.org/img/screenshot-iphone.webp" alt="iPhone screenshot" height="300"/> <img src="https://localsend.org/img/screenshot-pc.webp" alt="PC screenshot" height="300"/>

## ✦ Download

[![Packaging status](https://repology.org/badge/tiny-repos/localsend.svg)](https://repology.org/project/localsend/versions)

| Windows                 | macOS                   | Linux              | Android        | iOS           | Fire OS    |
|-------------------------|-------------------------|--------------------|----------------|---------------|------------|
| [Winget][]              | [App Store][]           | [Flathub][]        | [Play Store][] | [App Store][] | [Amazon][] |
| [Scoop][]               | [Homebrew][]            | [Nixpkgs][]        | [F-Droid][]    |               |            |
| [Chocolatey][]          | [DMG Installer][latest] | [Snap][]           | [APK][latest]  |               |            |
| [EXE Installer][latest] |                         | [AUR][]            |                |               |            |
| [Portable ZIP][latest]  |                         | [TAR][latest]      |                |               |            |
|                         |                         | [DEB][latest]      |                |               |            |
|                         |                         | [AppImage][latest] |                |               |            |

[windows store]: https://www.microsoft.com/store/apps/9NCB4Z0TZ6RR
[app store]: https://apps.apple.com/us/app/localsend/id1661733229
[play store]: https://play.google.com/store/apps/details?id=org.localsend.localsend_app
[f-droid]: https://f-droid.org/packages/org.localsend.localsend_app
[amazon]: https://www.amazon.com/dp/B0BW6MP732
[winget]: https://github.com/microsoft/winget-pkgs/tree/master/manifests/l/LocalSend/LocalSend
[scoop]: https://scoop.sh/#/apps?s=0&d=1&o=true&q=localsend&id=fb88113be361ca32c0dcac423cb4afdeda0b0c66
[chocolatey]: https://community.chocolatey.org/packages/localsend
[homebrew]: https://formulae.brew.sh/cask/localsend
[flathub]: https://flathub.org/apps/details/org.localsend.localsend_app
[nixpkgs]: https://search.nixos.org/packages?show=localsend
[snap]: https://snapcraft.io/localsend
[aur]: https://aur.archlinux.org/packages/localsend-bin
[latest]: https://github.com/localsend/localsend/releases/latest

**Compatibility**

| Platform | Minimum Version | Note |
|----------|-----------------|------|
| Android  | 5.0             | —    |
| iOS      | 16.1            | Live Activity & Dynamic Island require iOS 16.1+ |
| macOS    | 11 Big Sur      | Use OpenCore Legacy Patcher 2.0.2 |
| Windows  | 10              | Last version to support Windows 7 is v1.15.4 |
| Linux    | N.A.            | Gnome: `xdg-desktop-portal` + `xdg-desktop-portal-gtk`, KDE: `xdg-desktop-portal` + `xdg-desktop-portal-kde` |

## ✦ Setup

Firewall rules:

| Traffic Type | Protocol | Port  | Action |
|--------------|----------|-------|--------|
| Incoming     | TCP, UDP | 53317 | Allow  |
| Outgoing     | TCP, UDP | Any   | Allow  |

Disable **AP Isolation** on your router (usually off by default, but check guest networks).

### Portable Mode

Create an empty `settings.json` next to the executable. Settings live there instead of the default path.

### Start Hidden

```bash
localsend_app --hidden
```

App starts in system tray, no window.

## ✦ How It Works

Devices discover each other via multicast DNS and communicate over a lightweight REST API. Every connection is secured with **on-the-fly TLS/SSL certificates** — encrypted, authenticated, and zero trust required.

```
[Device A] ←→ HTTPS (TLS 1.3) ←→ [Device B]
     ↑             ↑                    ↑
  mDNS discovery   |            mDNS discovery
                   |
            No internet needed
```

Protocol docs → [localsend/protocol](https://github.com/localsend/protocol)

## ✦ Build from Source

```bash
# 1. Install Flutter + Rust
# 2. Clone this repo
cd app
fvm flutter pub get
fvm flutter run
```

> [!NOTE]
> Uses [fvm](https://fvm.app) for pinned Flutter version (see [.fvmrc](.fvmrc)).

## ✦ Contribute

### Translate

Help us speak your language → [Weblate](https://hosted.weblate.org/projects/localsend/app)

<a href="https://hosted.weblate.org/engage/localsend/">
<img src="https://hosted.weblate.org/widget/localsend/app/multi-auto.svg" alt="Translation status" />
</a>

### Code

- **Bug fix?** Open a PR with a clear description.
- **New feature?** Open an issue first to discuss.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## ✦ Troubleshooting

| Issue | Sender | Receiver | Fix |
|-------|--------|----------|-----|
| Device not visible | Any | Any | Disable AP Isolation on router |
| Device not visible | Any | Windows | Set network to "Private" |
| Device not visible | macOS/iOS | Any | Toggle "Local Network" permission in Privacy settings |
| Slow transfer | Any | Any | Use 5 GHz; disable encryption |
| Slow transfer | Any | Android | [Known issue](https://github.com/flutter-cavalry/saf_stream/issues/4) |

## ✦ Building (Maintainers)

Run from `app/` directory.

### Android

```bash
flutter build apk           # Traditional APK
flutter build appbundle     # Google Play
```

### iOS

```bash
flutter build ipa
```

### macOS

```bash
flutter build macos
```

### Windows

```bash
flutter build windows                              # Traditional
flutter pub run msix:create                       # Local MSIX
flutter pub run msix:create --store               # Store-ready
```

### Linux

```bash
flutter build linux                               # Traditional
appimage-builder --recipe AppImageBuilder.yml     # AppImage
```

Snap → [localsend/snap](https://github.com/localsend/snap)

## ✦ Contributors

<a href="https://github.com/localsend/localsend/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=localsend/localsend" alt="Contributors"/>
</a>

---

<p align="center"><strong>LocalSend</strong> — your files, your network, your rules.</p>
