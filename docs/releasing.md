# Releasing matome-app

Commits use Conventional Commits. A push to `master` runs Release Please on
GitHub and opens or updates the release PR with `version.txt` and
`CHANGELOG.md`. Merging that PR creates the tag and GitHub Release, then
dispatches the package workflow. The local check still runs on a developer
machine.

Install the versioned pre-push hook once per checkout:

```bash
mise run hooks:install
```

It runs the same gate as `mise run verify` on the exact commit being pushed
and posts the `local-check` commit status. For a Release Please PR, check out
its branch and run `mise run local-check` before merging it.

The public repository requires the `local-check` status on `master`. Run the
versioned pre-push hook for every commit, including release PR branches.

Release Please uses the repository's GitHub Actions token. In Settings →
Actions → General, enable **Allow GitHub Actions to create and approve pull
requests**. The workflow grants write access only to the GitHub permissions
needed to open release PRs, create releases, and dispatch package builds.
The release PR must pass `local-check` before it can be merged.

The workflow can also be started manually from the Actions tab to catch up
after installation or an interrupted run.

To rebuild packages for an existing release, dispatch the same workflow:

```bash
mise run release:publish -- vX.Y.Z
```

The workflow checks out the release tag and attaches a web tarball, a macOS
DMG, a Windows installer EXE, a Linux AppImage, a signed Android arm64 APK,
and `SHA256SUMS`. Each package is uploaded with its versioned name and an
unversioned name for stable `/releases/latest/download/` links in the README.
The Android job compiles and bundles pinned OpenSSL libraries for HTTPS.
The checksums file includes both names. It needs the
`MATOME_ANDROID_KEYSTORE_B64` and `MATOME_ANDROID_KEYSTORE_PASSWORD` repository
secrets. The first contains the Base64 encoding of the PKCS12 keystore; the
second is its store and key password. The key alias is `matome-upload`. Keep an
offline backup of both:
future Android versions must use the same signing key. The macOS and Windows
packages are currently unsigned. Add Developer ID notarization and Windows
code signing after MATOME obtains those credentials. The Windows runner uses
Qt 6.10.3 because the current `aqtinstall` cannot resolve Qt 6.11.2's changed
Windows repository layout.
