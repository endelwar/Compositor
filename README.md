# Compositor for macOS 15

Unofficial builds of [Compositor](https://github.com/robbietilton/Compositor) for macOS 15 (Sequoia) or later, on Intel and Apple silicon.

Upstream targets macOS 26.5 and has declined to support older systems (see robbietilton/Compositor#8 and #72), so these builds are kept here instead. Do not report their problems upstream.

## How it works

This branch holds no Compositor source, only:

- `patches/macos15.patch`: puts the few macOS 26-only APIs behind `#available`. On macOS 15 the pop-up menus keep their standard border and the toolbar has no spacers; nothing else changes. It also moves the tool rail's scroll container out of its generic view, because Swift 6.2.4 (Xcode 26.3) crashes optimizing that class's deinit for a macOS 15 target.
- `scripts/build.sh <upstream checkout> <output dir>`: applies the patch, archives a universal Release with `MACOSX_DEPLOYMENT_TARGET=15.0` passed to `xcodebuild` (not patched into `project.pbxproj`, whose nearby lines change every release), signs it ad hoc and zips it.
- `.github/workflows/build-macos15.yml`: every six hours looks up the latest upstream release; if this fork has no `<tag>-macos15` release yet, it builds on `macos-26`, launches the app on `macos-15-intel`, and publishes the zip. Run it by hand from the Actions tab to build a given tag or rebuild one.

## When a build fails

A new upstream release can use another macOS 26 API. Reproduce locally and extend the patch:

```sh
git clone --depth 1 --branch <tag> https://github.com/robbietilton/Compositor upstream
scripts/build.sh upstream dist
# fix the compile errors in upstream/ with `if #available(macOS 26.0, *)`, then:
git -C upstream add -N . && git -C upstream diff > patches/macos15.patch
```

## Installing

The app is signed ad hoc, not notarized. On first launch macOS blocks it: allow it in System Settings > Privacy & Security > Open Anyway, or run `xattr -dr com.apple.quarantine Compositor.app`.

Its built-in updater stays on but never offers official releases, because they require macOS 26.5. New builds come from this fork's releases.
