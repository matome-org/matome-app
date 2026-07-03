defmodule MatomeApi.AIEngine do
  @moduledoc """
  Core-side client for the external AI Engine contract.

  The real engine lives outside this monorepo; this module only dispatches jobs
  and authenticates the local callback contract used by the stub and production
  service.
  """

  def token do
    config() |> Keyword.get(:token, "")
  end

  def endpoint do
    config() |> Keyword.fetch!(:endpoint)
  end

  def callback_base_url do
    config() |> Keyword.fetch!(:callback_base_url)
  end

  def dispatch_adapter do
    config() |> Keyword.get(:dispatch_adapter, MatomeApi.AIEngine.HTTPDispatchAdapter)
  end

  def dispatch(payload) do
    case dispatch_adapter() do
      {module, arg} -> module.dispatch(endpoint(), token(), payload, arg)
      module -> module.dispatch(endpoint(), token(), payload)
    end
  end

  defp config, do: Application.fetch_env!(:matome_api, __MODULE__)
end
