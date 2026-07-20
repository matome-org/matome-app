defmodule MatomeApi.Docs.AiCoreDeploymentContractTest do
  @moduledoc """
  W4 (#2128) contract for the production AI Core image, Compose stack, and
  operator documentation. The existing root Compose file remains the local
  fixture stack and continues to use ai-stub.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../../..", __DIR__)
  @local_compose Path.join(@repo_root, "docker-compose.yml")
  @prod_compose Path.join(@repo_root, "docker-compose.production.yml")
  @dockerfile Path.join(@repo_root, "services/ai-core/Dockerfile")
  @env_example Path.join(@repo_root, ".env.production.example")
  @docs Path.join(@repo_root, "services/ai-core/README.md")

  test "AI Core production image has ffmpeg, a non-root runtime, and a healthcheck" do
    body = File.read!(@dockerfile)

    assert body =~ "ffmpeg"
    assert body =~ "USER app"
    assert body =~ "HEALTHCHECK"
    assert body =~ "AI_JOB_DATA_PATH=/var/lib/matome-ai-core/jobs.sqlite3"
    assert body =~ ~r/uvicorn.*--port.*8000/s
  end

  test "production Compose wires the app stack to a private durable AI Core" do
    body = File.read!(@prod_compose)
    ai_core = service_block(body, "ai-core")

    for service <- ~w(db minio minio-init ai-core core web) do
      assert body =~ ~r/^  #{Regex.escape(service)}:/m,
             "production Compose must define #{service}"
    end

    assert body =~ "AI_ENGINE_ENDPOINT: http://ai-core:8000/v1/jobs"
    assert body =~ "AI_JOB_DATA_PATH: /var/lib/matome-ai-core/jobs.sqlite3"
    assert body =~ ~r/matome_ai_core_jobs:\/var\/lib\/matome-ai-core/
    assert ai_core =~ "healthcheck:"
    refute ai_core =~ "ports:"
    refute body =~ "ai-adapter"
    refute body =~ "matome-api-audio"
  end

  test "local Compose retains ai-stub and the development Core image" do
    body = File.read!(@local_compose)

    assert body =~ ~r/^  ai-stub:/m
    assert body =~ "Dockerfile.dev"
    assert body =~ "http://ai-stub:${AI_STUB_PORT}/v1/jobs"
  end

  test "production env scaffold and docs distinguish public and private URLs" do
    env = File.read!(@env_example)
    docs = File.read!(@docs)

    for name <- ~w(
         API_BASE_URL
         STORAGE_S3_ENDPOINT
         AI_ENGINE_DISPATCH_TOKEN
         AI_ENGINE_CALLBACK_SIGNING_SECRET
         AI_ENGINE_CALLBACK_BASE_URL
         AI_JOB_DATA_PATH
       ) do
      assert env =~ name, ".env.production.example must mention #{name}"
      assert docs =~ name, "AI Core deployment docs must mention #{name}"
    end

    assert docs =~ "http://ai-core:8000/v1/jobs"
    assert docs =~ "32"
    assert docs =~ "private"
    assert docs =~ "HTTPS"
    assert docs =~ "ai-stub"
    refute env =~ ~r/^(?!#).*=(dev-|postgres$|password$)/m
  end

  defp service_block(compose, name) do
    [block | _] =
      Regex.run(~r/^  #{Regex.escape(name)}:\n(.*?)(?=^  [a-z0-9][a-z0-9-]*:|\z)/ms, compose,
        capture: :all_but_first
      )

    block
  end
end
