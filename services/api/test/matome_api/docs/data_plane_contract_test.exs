defmodule MatomeApi.Docs.DataPlaneContractTest do
  @moduledoc """
  W0 (#1944) — characterization of the interchangeable Postgres + S3 env
  contract. Fails if `docs/data-plane.md` drifts from the runtime surface.
  """
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../docs/data-plane.md", __DIR__)

  @required_env_mentions ~w(
    DATABASE_URL
    DATABASE_SSL
    STORAGE_S3_ENDPOINT
    STORAGE_S3_ACCESS_KEY_ID
    STORAGE_S3_SECRET_ACCESS_KEY
    STORAGE_S3_REGION
    STORAGE_MEDIA_BUCKET
    STORAGE_UPLOAD_URL_TTL
    STORAGE_DOWNLOAD_URL_TTL
    SECRET_KEY_BASE
    GUARDIAN_SECRET_KEY
    PHX_HOST
    CORS_ORIGINS
    MAILER_ADAPTER
    ADMIN_EMAIL_ALLOWLIST
  )

  test "data-plane.md exists and pins the interchangeable env contract" do
    assert File.exists?(@doc_path),
           "expected #{@doc_path} — document the Postgres + S3-compatible contract"

    body = File.read!(@doc_path)

    for name <- @required_env_mentions do
      assert body =~ name, "data-plane.md must mention #{name}"
    end

    assert body =~ "browser-reachable" or body =~ "public",
           "must warn that STORAGE_S3_ENDPOINT is baked into client presigned URLs"

    assert body =~ "path-style" or body =~ "path style",
           "must document path-style addressing (Presigner canonical URI)"

    assert body =~ "Dockploy" or body =~ "dockploy",
           "must include a Dockploy env checklist stub"

    assert body =~ "native" or body =~ "mise run up",
           "must state daily DX is native Postgres+MinIO (compose optional)"
  end
end
