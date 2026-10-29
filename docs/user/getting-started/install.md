---
title: Install LightZ
description: Download LightZ for Windows 11, macOS or Linux, install it, and open your photo library.
order: 10
verified: 0.7.1
---

Download the file for your system from the [latest release](https://github.com/danish0440/lightz/releases/latest) and install it. In the file names, `<version>` stands for the version number, for example `0.7.1`. The [LightZ page on GitHub](https://github.com/danish0440/lightz) also links the download.

## Windows 11

1. Open the [latest release](https://github.com/danish0440/lightz/releases/latest).
2. Download `lightz-<version>-windows-x64.msi`. It fits most PCs (Intel and AMD, 64-bit).
3. Run the file. The first page asks who to install LightZ for. **Only for me** is the default: it needs no administrator permission and installs to `%LOCALAPPDATA%\Programs\ArtCraft\LightZ`. **Everyone on this computer** asks for an administrator and installs to `C:\Program Files\ArtCraft\LightZ` (`Program Files (x86)` for the 32-bit build). Upgrades stay in the folder you chose.
4. At the end, choose the option to start LightZ.

For a Snapdragon or other Arm PC, download `lightz-<version>-windows-arm64.msi` instead. For a 32-bit Windows, download `lightz-<version>-windows-x86.msi`.

Upgrading from an installer older than 0.6.0 also keeps LightZ in the folder it was installed in. An upgrade uses the folder that the earlier install recorded and does not check that it still exists, so if you deleted that folder, the upgrade creates it again.

To run it without installing, download `lightz-<version>-windows-x64-portable.zip`. Portable builds for `arm64` and `x86` are on the release page too.

## macOS

1. Download `lightz-<version>-macos-universal.dmg`. It works on Apple silicon and Intel Macs, and is signed and notarized.
2. Open the file and install LightZ.

## Linux

The release has these files for `x86_64` and `aarch64` (Arm). Replace `x86_64` with `aarch64` on Arm.

| File                                         | Notes                                                    |
|----------------------------------------------|----------------------------------------------------------|
| `lightz-<version>-linux-x86_64.AppImage` | Runs anywhere.                                           |
| `lightz-<version>-linux-x86_64.flatpak`  | Sandboxed. Install with `flatpak install --user <file>`. |
| `lightz-<version>-linux-x86_64.deb`      | For Debian and Ubuntu.                                   |
| `lightz-<version>-linux-x86_64.rpm`      | For Fedora, RHEL and openSUSE.                           |
| `lightz-<version>-linux-x86_64.tar.gz`   | Unpack anywhere.                                         |

RISC-V and FreeBSD builds are on the release page too. On a Wayland desktop, LightZ runs through XWayland when it is available, because only X11 gives it file drag-and-drop.

## Install with AppZ

[AppZ](https://github.com/danish0440/lightz) lists LightZ and can install and update it for you. On Windows it installs the release `.msi`.

## In a web browser

The release also has `lightz-web-<version>.zip`, a static site that runs LightZ in a modern browser. Host it on any static web server.

## First run

1. Start LightZ. It opens your library at `~/Pictures/LightZ Library`. A new library starts with demo photos.
2. To bring in your own photos, see [Import photos](../guides/import-photos.md).

## Still stuck?

Ask in [Discord](https://github.com/danish0440/lightz/issues) or open an issue in the [issue tracker](https://github.com/danish0440/lightz/issues).
