defmodule MatomeApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :matome_api,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {MatomeApi.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :ssl]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      # LiveView + server-rendered HTML for the /admin back-office (plan
      # p2-core-backoffice, W0 #1868). Assets are bundled by esbuild + styled
      # by Tailwind (dev-time build tools; not started at runtime in :prod —
      # the compiled artifacts under priv/static are what ship).
      # Versions are pinned exactly (not `~>`) because this wave's build
      # environment has no Hex network; these are the newest builds present in
      # the local Hex cache. Relax to `~>` when network resolution is available.
      {:phoenix_live_view, "1.2.3"},
      {:phoenix_html, "4.3.0"},
      # Floki is present for future dead-render assertions. NOTE: the CONNECTED
      # `live/2` socket test additionally needs `{:lazy_html, ">= 0.1.0", only:
      # :test}` (a C-NIF LiveView 1.2 uses for its DOM parser). lazy_html can't
      # build in this offline wave (no Hex network / no cached elixir_make
      # 0.9), so W0 asserts /admin via a dead-render GET instead; add lazy_html
      # + a `live/2` mount test when networked.
      {:floki, "0.38.4", only: :test},
      {:phoenix_live_reload, "1.6.2", only: :dev},
      {:esbuild, "0.10.0", runtime: Mix.env() == :dev},
      {:tailwind, "0.2.4", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:oban, "~> 2.19"},
      {:open_api_spex, "~> 3.22"},
      {:guardian, "~> 2.3"},
      {:argon2_elixir, "~> 4.1"},
      {:swoosh, "~> 1.17"},
      {:dns_cluster, "~> 0.1.1"},
      {:cors_plug, "~> 3.0"},
      {:bandit, "~> 1.5"}
      # NOTE (W0 #1868 deviation): `nimble_totp` (staged for W3 admin 2FA) is
      # NOT yet listed — the build environment for this wave has no Hex network
      # reachability and the package is not in the local cache, so adding it
      # would break `mix deps.get`. It will be added in W3 when TOTP is wired.
      #
      # NOTE (W0 #1868 Livebook): Livebook is intentionally NOT a Mix dep. It
      # runs as a standalone `livebook server` against notebooks/ (dev-only) —
      # see docs/livebook-threat-model.md. Keeping it out of mix.exs is the
      # strongest possible proof it can never mount in a :prod release.
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Asset pipeline (W0 #1868). `--if-missing` skips the network install
      # when the esbuild/tailwind binaries are already present under _build.
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind matome", "esbuild matome"],
      "assets.deploy": [
        "tailwind matome --minify",
        "esbuild matome --minify",
        "phx.digest"
      ]
    ]
  end
end
