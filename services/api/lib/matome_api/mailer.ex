defmodule MatomeApi.Mailer do
  @moduledoc """
  Swoosh mailer for transactional email (password reset, etc.).

  The adapter is configured per environment under
  `config :matome_api, MatomeApi.Mailer, adapter: ...` and is intentionally
  swappable: `Swoosh.Adapters.Local` in dev (mailbox preview),
  `Swoosh.Adapters.Test` in test, and a real provider (Mailgun/SES/SMTP/...) in
  prod once configured — no call sites change.
  """
  use Swoosh.Mailer, otp_app: :matome_api
end
