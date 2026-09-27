# Releasing matome-app

Commits use Conventional Commits. Release Please runs locally and opens a
release PR that updates `version.txt` and `CHANGELOG.md`. The local check runs
on a developer machine. GitHub Actions builds release packages only.

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
GitHub Release. Publishing the release starts the GitHub package workflow:

```bash
git pull --ff-only
mise run release:finalize
```

To rebuild packages for a release tagged after the package workflow was added,
dispatch the same workflow:

```bash
mise run release:publish -- vX.Y.Z
```

The workflow checks out the release tag and attaches a web tarball, a macOS
DMG, a Windows installer EXE, a Linux AppImage, a signed Android arm64 APK,
and `SHA256SUMS`. It needs the `MATOME_ANDROID_KEYSTORE_B64` and
`MATOME_ANDROID_KEYSTORE_PASSWORD` repository secrets. The first contains the
Base64 encoding of the PKCS12 keystore; the second is its store and key
password. The key alias is `matome-upload`. Keep an offline backup of both:
future Android versions must use the same signing key. The macOS and Windows
packages are currently unsigned. Add Developer ID notarization and Windows
code signing after MATOME obtains those credentials. The Windows runner uses
Qt 6.10.3 because the current `aqtinstall` cannot resolve Qt 6.11.2's changed
Windows repository layout.
