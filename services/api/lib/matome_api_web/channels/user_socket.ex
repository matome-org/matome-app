defmodule MatomeApiWeb.UserSocket do
  use Phoenix.Socket

  alias MatomeApi.Auth

  channel "user:*", MatomeApiWeb.RecordingStatusChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Auth.verify_access_token(token) do
      {:ok, user, _claims} -> {:ok, assign(socket, :current_user, user)}
      {:error, :unauthorized} -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
