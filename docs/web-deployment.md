# Deploy the web app

The root `Dockerfile` downloads a published web package, verifies its
`SHA256SUMS` entry, and serves it with Nginx on port `80`. It does not compile
Qt. The default package is `v0.3.0`; the `WEB_RELEASE` build argument selects
another published version. The Nginx image is pinned by digest.

## Prepare locally

Install Docker Engine and start its daemon before using these tasks. Mise
pins the Docker CLI; it does not install or manage the daemon. Your user must
have permission to access the Docker socket.

```bash
mise install
mise run web:container:build
mise run web:container:run
```

Open `http://localhost:8080`. The container binds only to the local loopback
interface. To select a different release or local port:

```bash
mise run web:container:build --release v0.3.0
mise run web:container:run --port 8081
```

Running the start task again reuses the matching container. Stop it before
switching images or ports:

```bash
mise run web:container:stop
```

The stop task removes the container while retaining the image. Rebuilding
reuses Docker's cache. For a package republished under the same tag, use
`mise run web:container:build --no-cache` locally or clear the application's
build cache in Dokploy before rebuilding.

## Server configuration

The server default is compiled from the release tag's root `app.toml`.
The `v0.3.0` package defaults to `https://core.matome.io`. Editing the local
`app.toml` does not change a downloaded release. To change the compiled
default, publish a new package after changing `default_server` or its
`[platform.web]` override, then select that release for the container.

There are no runtime environment variables for the default server and no
deployment `.env` is required. The root `.env` remains for local tests and
is excluded from the Docker build context.

The browser connects directly to the selected server. When its origin
differs from the web app's origin, the API must permit that browser origin
through CORS. This applies to `http://localhost:8080` and to the deployed
HTTPS domain. This container serves static files and does not proxy API
requests. An HTTPS web app also needs an HTTPS API endpoint.

## Deploy with Dokploy

1. Create an Application connected to the `matome-org/matome-app` repository.
2. Select the branch containing the Dockerfile; use `master` after merging.
3. Select the **Dockerfile** build type.
4. Set **Dockerfile Path** to `Dockerfile` and **Docker Context Path** to `.`.
5. Leave **Docker Build Stage** empty to build the final runtime image.
6. Set `WEB_RELEASE=v0.3.0` in **Build Time Arguments** to pin the package.
7. Deploy the application.
8. Point the web domain's DNS record to your Dokploy server.
9. Add that domain with path `/`, container port `80`, and HTTPS enabled.
10. Permit the web domain's origin at the API before testing account flows.

Dokploy routes domain traffic to the internal container port; a public host
port mapping is unnecessary. See its [Dockerfile build
settings](https://docs.dokploy.com/docs/core/applications/build-type) and
[domain settings](https://docs.dokploy.com/docs/core/domains).

To upgrade, change `WEB_RELEASE` to a release with published packages and
redeploy. Merging source code alone does not change the downloaded package.
To roll back, restore the previous release argument and redeploy.

Nginx serves `/` as `matome-studio.html`, serves WebAssembly with its MIME
type, compresses supported assets, and requires cache revalidation so
stable asset names do not retain an older release. Missing assets return
`404`. Docker checks the root page for container health.
