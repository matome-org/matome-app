defmodule MatomeApi.Auth.UserNotifier do
  @moduledoc """
  Builds and delivers auth-related transactional emails via `MatomeApi.Mailer`.
  """
  import Swoosh.Email

  alias MatomeApi.Mailer

  @from {"Matome", "no-reply@matome.app"}

  @doc """
  Sends the password-reset email carrying the short-lived reset `token`.

  The token is delivered as a paste-able code (the mobile client asks the user
  to paste it). Returns `{:ok, email}` or `{:error, reason}` from the adapter.
  """
  def deliver_reset_password(user, token) do
    email =
      new()
      |> to(user.email)
      |> from(@from)
      |> subject("Reset your Matome password")
      |> text_body("""
      Hi,

      We received a request to reset your Matome password. Use this code to set a
      new one:

      #{token}

      The code expires in 30 minutes. If you did not request a reset, you can
      safely ignore this email — your password will not change.
      """)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
