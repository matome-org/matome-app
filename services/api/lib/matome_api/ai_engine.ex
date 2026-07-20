defmodule MatomeApi.AIEngine do
  @moduledoc """
  Core-side client for the external AI Engine contract.

  The real engine lives outside this monorepo; this module only dispatches jobs
  and authenticates the local callback contract used by the stub and production
  service.
  """

  def dispatch_token, do: config() |> Keyword.get(:dispatch_token, "")
  def callback_signing_secret, do: config() |> Keyword.get(:callback_signing_secret, "")

  def endpoint do
    config() |> Keyword.fetch!(:endpoint)
  end

  def callback_base_url do
    config() |> Keyword.fetch!(:callback_base_url)
  end

  def dispatch_adapter do
    config() |> Keyword.get(:dispatch_adapter, MatomeApi.AIEngine.HTTPDispatchAdapter)
  end

  def capabilities(timeout_seconds \\ 10) do
    case Keyword.fetch(config(), :capabilities) do
      {:ok, capabilities} ->
        MatomeApi.AIEngine.Contract.validate_capabilities(capabilities)

      :error ->
        adapter =
          Keyword.get(config(), :capabilities_adapter, MatomeApi.AIEngine.HTTPDispatchAdapter)

        result =
          case adapter do
            {module, arg} ->
              module.capabilities(endpoint(), dispatch_token(), timeout_seconds, arg)

            module ->
              module.capabilities(endpoint(), dispatch_token(), timeout_seconds)
          end

        with {:ok, capabilities} <- result,
             do: MatomeApi.AIEngine.Contract.validate_capabilities(capabilities)
    end
  end

  def dispatch(payload, timeout_seconds) do
    case dispatch_adapter() do
      {module, arg} ->
        module.dispatch(endpoint(), dispatch_token(), payload, timeout_seconds, arg)

      module ->
        module.dispatch(endpoint(), dispatch_token(), payload, timeout_seconds)
    end
  end

  def callback_identity(job_id, run_id, input_revision) do
    callback_signing_secret()
    |> then(&:crypto.mac(:hmac, :sha256, &1, "#{job_id}:#{run_id}:#{input_revision}"))
    |> Base.url_encode64(padding: false)
  end

  def valid_callback_identity?(provided, job_id, run_id, input_revision)
      when is_binary(provided) do
    expected = callback_identity(job_id, run_id, input_revision)
    byte_size(provided) == byte_size(expected) and Plug.Crypto.secure_compare(provided, expected)
  end

  def valid_callback_identity?(_provided, _job_id, _run_id, _input_revision), do: false

  defp config, do: Application.fetch_env!(:matome_api, __MODULE__)
end
