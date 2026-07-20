defmodule MatomeApi.Docs.ProdImageContractTest do
  @moduledoc """
  W3 (#1947) — characterization: Dockploy ships a MIX_ENV=prod release image,
  not the compose MIX_ENV=dev container. Migrate-on-deploy is owned by
  `MatomeApi.Release` / the prod entrypoint.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../../..", __DIR__)
  @dockerfile Path.join(@repo_root, "services/api/Dockerfile")
  @dockerfile_dev Path.join(@repo_root, "services/api/Dockerfile.dev")
  @release_mod Path.join(@repo_root, "services/api/lib/matome_api/release.ex")
  @entrypoint_prod Path.join(@repo_root, "services/api/docker-entrypoint.prod.sh")
  @data_plane Path.join(@repo_root, "services/api/docs/data-plane.md")
  @compose Path.join(@repo_root, "docker-compose.yml")

  test "prod Dockerfile is MIX_ENV=prod release (not mix phx.server / MIX_ENV=dev)" do
    assert File.exists?(@dockerfile), "expected services/api/Dockerfile for Dockploy"

    body = File.read!(@dockerfile)

    assert body =~ ~r/MIX_ENV=prod/, "Dockploy Dockerfile must set MIX_ENV=prod"

    assert body =~ "mix release" or body =~ "RELEASE",
           "must build an OTP release"

    refute body =~ ~r/MIX_ENV=dev/, "prod Dockerfile must not set MIX_ENV=dev"

    refute body =~ "mix phx.server",
           "prod image must not boot via mix phx.server"
  end

  test "compose keeps a separate Dockerfile.dev for local MIX_ENV=dev" do
    assert File.exists?(@dockerfile_dev),
           "expected Dockerfile.dev so compose stays on mix phx.server"

    compose = File.read!(@compose)

    assert compose =~ "Dockerfile.dev",
           "docker-compose.yml must build from Dockerfile.dev (not prod)"
  end

  test "MatomeApi.Release.migrate exists for migrate-on-deploy" do
    assert File.exists?(@release_mod), "expected lib/matome_api/release.ex"

    body = File.read!(@release_mod)
    assert body =~ "def migrate"
    assert body =~ "Ecto.Migrator"
  end

  test "prod entrypoint migrates then starts the release with PHX_SERVER" do
    assert File.exists?(@entrypoint_prod),
           "expected docker-entrypoint.prod.sh"

    body = File.read!(@entrypoint_prod)
    assert body =~ "migrate" or body =~ "Release.migrate"
    assert body =~ "PHX_SERVER" or body =~ "start"
  end

  test "data-plane.md documents Dockploy env matrix + public STORAGE_S3_ENDPOINT" do
    body = File.read!(@data_plane)

    for name <- ~w(
           SECRET_KEY_BASE
           GUARDIAN_SECRET_KEY
           PHX_HOST
           CORS_ORIGINS
           MAILER_ADAPTER
           ADMIN_PANEL_ENABLED
           ADMIN_EMAIL_ALLOWLIST
           ADMIN_OTP_PEPPER
           API_BASE_URL
           STORAGE_S3_ENDPOINT
           DATABASE_URL
         ) do
      assert body =~ name, "data-plane.md Dockploy section must mention #{name}"
    end

    assert body =~ "public" or body =~ "browser-reachable",
           "must stress STORAGE_S3_ENDPOINT is the public client URL"

    assert body =~ "Dockerfile" or body =~ "release" or body =~ "MIX_ENV=prod",
           "must point operators at the prod image / release"
  end
end
