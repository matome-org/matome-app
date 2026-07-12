defmodule MatomeApi.Admin.Notifier do
  @moduledoc """
  Transactional email for the /admin email-OTP login flow.
  """
  import Swoosh.Email

  alias MatomeApi.Mailer

  @from {"Matome Admin", "no-reply@matome.app"}

  @doc """
  Delivers a one-shot admin login code. Returns `{:ok, email}` or `{:error, reason}`.
  """
  def deliver_login_otp(email, code) when is_binary(email) and is_binary(code) do
    email_msg =
      new()
      |> to(email)
      |> from(@from)
      |> subject("Your Matome admin sign-in code")
      |> text_body("""
      Your Matome back-office sign-in code is:

      #{code}

      It expires in 30 minutes and can be used once. If you did not request
      this, you can ignore this email.
      """)

    with {:ok, _metadata} <- Mailer.deliver(email_msg) do
      {:ok, email_msg}
    end
  end
end
