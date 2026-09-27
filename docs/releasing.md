# Releasing matome-app

Commits use Conventional Commits. Release Please reads commits on `master` and
opens a release PR that updates `version.txt` and `CHANGELOG.md`. The process
runs locally; GitHub Actions does not build or test releases.

Install the versioned pre-push hook once per checkout:

```bash
mise run hooks:install
```

It runs the same gate as `mise run verify` on the exact commit being pushed
and posts the `local-check` commit status. For a Release Please PR, check out
its branch and run `mise run local-check` before merging it.

The public repository requires the `local-check` status on `master`. Run the
versioned pre-push hook for every commit, including release PR branches.

Create or update the release PR from a clean, current `master`:

```bash
mise run release:pr
```

After checking and merging that PR, update `master` and create the tag and
GitHub Release:

```bash
git pull --ff-only
mise run release:finalize
```

Build and upload the web, Linux desktop, and Android emulator assets from the
release tag:

```bash
git fetch --all --tags
git switch --detach vX.Y.Z
mise run release:publish -- vX.Y.Z
git switch master
```

The upload attaches `matome-web-vX.Y.Z.tar.gz`,
`matome-desktop-linux-x86_64-vX.Y.Z.tar.gz`,
`matome-android-emulator-x86_64-vX.Y.Z.apk`, and `SHA256SUMS` to the GitHub
Release. The web archive contains `build-wasm/bin` for a static web server.
The Linux archive contains a dynamically linked Qt executable and needs Qt
6.11.2 on the host. The APK is a debug build for an x86_64 emulator; it is
not a signed production APK. No container image is included.
