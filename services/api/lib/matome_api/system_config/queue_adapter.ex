defmodule MatomeApi.SystemConfig.QueueAdapter do
  @moduledoc false

  @callback apply(map()) :: :ok | {:error, term()}
  @callback status() :: {:ok, map()} | {:error, term()}

  def apply({module, arg}, policy), do: module.apply(policy, arg)
  def apply(module, policy), do: module.apply(policy)

  def status({module, arg}), do: module.status(arg)
  def status(module), do: module.status()
end
