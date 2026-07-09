defmodule MatomeApiWeb.AdminSessionHTML do
  @moduledoc """
  Server-rendered forms for the /admin login flow (W3 #1871): sign-in,
  TOTP enrollment, and TOTP verification / re-auth. Deliberately minimal —
  styled against the same foundations tokens as the admin shell.
  """
  use MatomeApiWeb, :html

  def new(assigns) do
    ~H"""
    <section class="admin-empty">
      <p class="admin-empty__eyebrow">matome · back-office</p>
      <h1 class="admin-empty__title">Sign in</h1>
      <form action="/admin/login" method="post" class="admin-form">
        <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
        <label>
          Email
          <input type="email" name="email" autocomplete="username" required />
        </label>
        <label>
          Password
          <input type="password" name="password" autocomplete="current-password" required />
        </label>
        <button type="submit">Continue</button>
      </form>
    </section>
    """
  end

  def mfa(assigns) do
    ~H"""
    <section class="admin-empty">
      <p class="admin-empty__eyebrow">matome · back-office</p>
      <h1 class="admin-empty__title">Two-factor authentication</h1>

      <div :if={@enrollment} class="admin-mfa-enrollment">
        <p class="admin-empty__body">
          Admin access requires an authenticator app. Add this secret to your
          authenticator, then confirm with a code to finish enrollment.
        </p>
        <p><code>{@enrollment.secret_base32}</code></p>
        <p><code>{@enrollment.otpauth_uri}</code></p>
      </div>

      <p :if={!@enrollment} class="admin-empty__body">
        Enter the 6-digit code from your authenticator app.
      </p>

      <form action="/admin/mfa" method="post" class="admin-form">
        <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
        <input type="hidden" name="return_to" value={@return_to} />
        <label>
          Code
          <input
            type="text"
            name="code"
            inputmode="numeric"
            pattern="[0-9]*"
            autocomplete="one-time-code"
            required
          />
        </label>
        <button type="submit">Verify</button>
      </form>
    </section>
    """
  end
end
