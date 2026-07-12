defmodule MatomeApi.Docs.ContainerDataPlaneMiseTest do
  @moduledoc """
  Characterization: the daily-DX data plane runs in Docker, not on the host.

  Every runtime dependency — Postgres, MinIO, the AI stub, and the Core API —
  is a docker-compose service. The mise lifecycle tasks (`up`, `backend`,
  `down`, `nuke`) drive `docker compose`; the previous native helper
  (`script/native-data-plane.sh`) is gone. Supersedes the native-data-plane
  characterization removed alongside this change.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../../..", __DIR__)
  @mise_path Path.join(@repo_root, "mise.toml")
  @compose_path Path.join(@repo_root, "docker-compose.yml")
  @native_script Path.join(@repo_root, "script/native-data-plane.sh")

  # Tasks that form the daily backend lifecycle.
  @lifecycle_tasks ~w(up backend down nuke)

  test "the native data plane helper is removed" do
    refute File.exists?(@native_script),
           "expected #{@native_script} deleted — the data plane is containerized (docker-compose)"
  end

  test "docker-compose.yml defines Postgres, MinIO, and Core as separate services" do
    assert File.exists?(@compose_path), "expected #{@compose_path}"
    body = File.read!(@compose_path)

    assert body =~ ~r/^\s{2}db:/m, "compose must define a `db` (Postgres) service"
    assert body =~ "postgres:", "db service must use a postgres image"
    assert body =~ ~r/^\s{2}minio:/m, "compose must define a `minio` service"
    assert body =~ "minio/minio", "minio service must use the MinIO image"
    assert body =~ ~r/^\s{2}core:/m, "compose must define a `core` (Core API) service"
  end

  test "mise up/backend/down/nuke drive docker compose, not native or Supabase" do
    assert File.exists?(@mise_path), "expected #{@mise_path}"
    body = File.read!(@mise_path)

    for task <- @lifecycle_tasks do
      block = extract_task_run!(body, task)

      assert block =~ "docker compose",
             "tasks.#{task} must drive the containerized stack via `docker compose`"

      refute block =~ ~r/\bsupabase\s+(start|status|stop|init)\b/,
             "tasks.#{task} must not call the Supabase CLI"

      refute block =~ "native-data-plane",
             "tasks.#{task} must not source the removed native data plane helper"

      refute block =~ "start_data_plane",
             "tasks.#{task} must not call the removed native start_data_plane"
    end

    # `up` runs the FULL stack (web container); `backend` excludes web.
    up = extract_task_run!(body, "up")
    backend = extract_task_run!(body, "backend")

    assert up =~ "docker compose up --build -d\n" or up =~ ~r/docker compose up --build -d\s*$/m,
           "up must bring up the full compose stack"

    assert backend =~ ~r/docker compose up --build -d db minio/,
           "backend must bring up the data plane + core WITHOUT the web service"

    refute backend =~ ~r/docker compose up --build -d\s+web/,
           "backend must not start the web container"

    # `nuke` drops the persistent data volumes; `down` keeps them.
    nuke = extract_task_run!(body, "nuke")
    down = extract_task_run!(body, "down")

    assert nuke =~ "docker compose down --volumes",
           "nuke must drop the Postgres + MinIO volumes"

    refute down =~ "--volumes",
           "down must keep data volumes (only nuke drops them)"
  end

  defp extract_task_run!(body, task) do
    pattern =
      ~r/\[tasks\.#{Regex.escape(task)}\]\n.*?^run\s*=\s*"""\n(.*?)^"""/ms

    case Regex.run(pattern, body, capture: :all_but_first) do
      [run] -> run
      nil -> flunk("could not find [tasks.#{task}] run block in mise.toml")
    end
  end
end
