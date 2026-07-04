defmodule MatomeApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MatomeApiWeb.Telemetry,
      MatomeApi.Repo,
      {Oban, Application.fetch_env!(:matome_api, Oban)},
      {DNSCluster, query: Application.get_env(:matome_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MatomeApi.PubSub},
      # TableHeir + RateLimiter are wrapped in their own `:rest_for_one`
      # supervisor (okt-audit PASS-2 FINDING-3, task #1867) rather than
      # sitting directly here as two `:one_for_one` siblings: a TableHeir
      # crash must cascade-restart RateLimiter too, or the ETS table's
      # `heir:` field goes stale (pointing at the dead pre-crash TableHeir)
      # until RateLimiter happens to restart for an unrelated reason — see
      # MatomeApi.RateLimiter.Supervisor's moduledoc for the full failure
      # mode this closes.
      MatomeApi.RateLimiter.Supervisor,
      # Start a worker by calling: MatomeApi.Worker.start_link(arg)
      # {MatomeApi.Worker, arg},
      # Start to serve requests, typically the last entry
      MatomeApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MatomeApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MatomeApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
