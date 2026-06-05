defmodule MatomeApiWeb.RecordingStatusChannelTest do
  use ExUnit.Case, async: true

  import Phoenix.ChannelTest

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApiWeb.UserSocket

  @endpoint MatomeApiWeb.Endpoint
  @password "correct horse battery staple"

  setup tags do
    MatomeApi.DataCase.setup_sandbox(tags)
    :ok
  end

  test "authenticated socket joins only its own user topic" do
    %{access_token: access_token, user: user} = register_user()
    {:ok, socket} = connect(UserSocket, %{"token" => access_token})

    assert {:ok, _, _socket} = subscribe_and_join(socket, "user:#{user.id}", %{})

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, "user:#{user.id + 1}", %{})
  end

  test "socket connect rejects missing or invalid JWT" do
    assert :error = connect(UserSocket, %{})
    assert :error = connect(UserSocket, %{"token" => "invalid"})
  end

  test "recording status updates fan out only to the owner socket" do
    owner = register_user()
    other = register_user()

    {:ok, owner_socket} = connect(UserSocket, %{"token" => owner.access_token})
    {:ok, _, _owner_channel} = subscribe_and_join(owner_socket, "user:#{owner.user.id}", %{})

    {:ok, other_socket} = connect(UserSocket, %{"token" => other.access_token})
    {:ok, _, _other_channel} = subscribe_and_join(other_socket, "user:#{other.user.id}", %{})

    {:ok, recording} = Content.create_recording(owner.user, %{title: "Channel memo"})

    assert {:ok, processing} =
             Content.update_recording(owner.user, recording.id, %{status: "processing"})

    assert_push "recording:status", %{
      recording_id: recording_id,
      status: "processing",
      summary: nil,
      transcript: nil,
      error_reason: nil,
      duration: nil,
      badge: nil,
      updated_at: processing_updated_at
    }

    assert recording_id == processing.id
    assert processing_updated_at == processing.updated_at
    refute_push "recording:status", _payload, 50

    assert {:ok, failed} =
             Content.update_recording(owner.user, recording.id, %{
               status: "failed",
               error_reason: "transcription_timeout"
             })

    assert_push "recording:status", %{
      recording_id: recording_id,
      status: "failed",
      summary: nil,
      transcript: nil,
      error_reason: "transcription_timeout",
      duration: nil,
      badge: nil,
      updated_at: updated_at
    }

    assert recording_id == failed.id
    assert updated_at == failed.updated_at
    refute_push "recording:status", _payload, 50
  end

  defp register_user do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    {:ok, result} = Auth.register_user(%{email: email, password: @password})
    %{access_token: result.access_token, user: result.user}
  end
end
