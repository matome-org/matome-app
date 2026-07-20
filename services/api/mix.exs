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
      deps: deps(),
      releases: [
        matome_api: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
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
      # Pinned to 1.1.x (cached): phoenix_storybook 0.9.x — the only line that
      # tracks Phoenix 1.7 — ships a HEEx layout the LiveView 1.2 tokenizer
      # rejects, so the design-system catalog needs LV 1.1. Our LiveView surface
      # (the empty /admin shell + dead-render tests) is 1.1/1.2-agnostic. Bump
      # back to 1.2.x only alongside Phoenix 1.8 + phoenix_storybook 1.2.
      {:phoenix_live_view, "1.1.32"},
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
      {:bandit, "~> 1.5"},
      # Design-system catalog (plan p2-core-backoffice, Phase A). The Elixir
      # equivalent of the Flutter Widgetbook: renders the real HEEx base +
      # composite components (`MatomeComponents`, `MatomeComposites`) as a
      # browsable, drift-guard gallery. Pinned to 0.9.x — the only line that
      # tracks Phoenix 1.7 (1.2.x requires Phoenix 1.8). The `/storybook` mount
      # is compile-gated on `:dev_routes` (router.ex) so it can NEVER reach a
      # :prod release — the same "provably absent from prod" guarantee the
      # earlier standalone-notebook approach targeted, but as a first-class,
      # component-rendering catalog tool instead of an arbitrary-code notebook.
      {:phoenix_storybook, "~> 0.9"},
      # Offline pin: this wave's Hex cache has makeup 1.2.1 but not the newer
      # 1.2.2 the resolver would otherwise pick (see mix.exs offline note).
      {:makeup, "1.2.1", override: true},
      # RFC-6238 TOTP for the /admin mandatory MFA gate (W3 #1871). Hex
      # network reachability was verified in this session, resolving the W0
      # deviation note that had deferred this dep.
      {:nimble_totp, "~> 1.0"}
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
