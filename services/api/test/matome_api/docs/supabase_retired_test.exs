defmodule MatomeApi.Docs.SupabaseRetiredTest do
  @moduledoc """
  W2 (#1946) — characterization: Supabase scaffolding must be gone from the
  repo. Daily DX is containerized Postgres + MinIO + Core (docker-compose).
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../../..", __DIR__)
  @supabase_dir Path.join(@repo_root, "supabase")
  @mise_path Path.join(@repo_root, "mise.toml")
  @readme_path Path.join(@repo_root, "README.md")
  @agents_path Path.join(@repo_root, "AGENTS.md")
  @arch_path Path.join(@repo_root, ".docs/internal/architecture.md")
  @contributing_path Path.join(@repo_root, "CONTRIBUTING.md")

  test "supabase/ directory is removed" do
    refute File.exists?(@supabase_dir),
           "expected supabase/ deleted — local DX is native Postgres+MinIO"
  end

  test "mise no longer pins or exposes the Supabase CLI" do
    body = File.read!(@mise_path)

    refute body =~ "aqua:supabase/cli",
           "remove aqua:supabase/cli from [tools]"

    refute body =~ ~r/\[tasks\.supabase\]/,
           "remove deprecated [tasks.supabase] stub"

    for task <- ~w(up backend down nuke) do
      block = extract_task_run!(body, task)

      refute block =~ ~r/\bsupabase\s+(start|status|stop|init)\b/,
             "tasks.#{task} must not shell the Supabase CLI"
    end
  end

  test "README, AGENTS, architecture, CONTRIBUTING do not claim Supabase is the local stack" do
    for {path, label} <- [
          {@readme_path, "README.md"},
          {@agents_path, "AGENTS.md"},
          {@arch_path, "architecture.md"},
          {@contributing_path, "CONTRIBUTING.md"}
        ] do
      assert File.exists?(path), "missing #{label}"
      body = File.read!(path)

      refute body =~ ~r/(?i)mise run up.*[Ss]upabase/,
             "#{label} must not describe mise run up as starting Supabase"

      refute body =~ ~r/(?i)\| `supabase` \|/,
             "#{label} must not list supabase/ as a project path"

      refute body =~ ~r/(?i)Backend:\s*Supabase/,
             "#{label} must not say Backend: Supabase"
    end

    readme = File.read!(@readme_path)
    agents = File.read!(@agents_path)

    assert readme =~ "Postgres" or readme =~ "MinIO" or readme =~ "data-plane",
           "README should point at native Postgres/MinIO / data-plane"

    assert agents =~ "Postgres" or agents =~ "MinIO" or agents =~ "native",
           "AGENTS.md should describe native Postgres+MinIO backend"
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
