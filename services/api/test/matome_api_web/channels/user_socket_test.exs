defmodule MatomeApiWeb.UserSocketTest do
  use ExUnit.Case, async: true

  import Phoenix.ChannelTest

  alias MatomeApi.Auth
  alias MatomeApiWeb.UserSocket

  @endpoint MatomeApiWeb.Endpoint
  @password "correct horse battery staple"

  setup tags do
    MatomeApi.DataCase.setup_sandbox(tags)
    :ok
  end

  test "socket connect accepts valid JWTs and assigns the socket id" do
    %{access_token: access_token, user: user} = register_user()

    assert {:ok, socket} = connect(UserSocket, %{"token" => access_token})
    assert socket.assigns.current_user.id == user.id
    assert UserSocket.id(socket) == "user_socket:#{user.id}"
  end

  test "socket connect rejects missing or invalid JWT" do
    assert :error = connect(UserSocket, %{})
    assert :error = connect(UserSocket, %{"token" => "invalid"})
  end

  defp register_user do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    {:ok, result} = Auth.register_user(%{email: email, password: @password})
    %{access_token: result.access_token, user: result.user}
  end
end
