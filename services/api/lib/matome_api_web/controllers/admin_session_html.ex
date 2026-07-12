defmodule MatomeApiWeb.AdminSessionHTML do
  @moduledoc """
  Server-rendered forms for /admin email-OTP login (W1 design-system atoms).
  """
  use MatomeApiWeb, :html

  import MatomeApiWeb.MatomeComponents

  def new(assigns) do
    ~H"""
    <section class="admin-empty">
      <p class="admin-empty__eyebrow">matome · back-office</p>
      <h1 class="admin-empty__title">Sign in</h1>
      <form action="/admin/login" method="post" class="admin-form">
        <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
        <.text_field
          name="email"
          label="Email"
          type="email"
          hint="you@example.com"
          autocomplete="username"
          required
        />
        <.submit_button>Continue</.submit_button>
      </form>
    </section>
    """
  end

  def otp(assigns) do
    ~H"""
    <section class="admin-empty">
      <p class="admin-empty__eyebrow">matome · back-office</p>
      <h1 class="admin-empty__title">Enter code</h1>
      <p class="admin-empty__body">
        Enter the 6-digit code sent to your email. It expires in 30 minutes
        and can be used once.
      </p>

      <form action="/admin/otp" method="post" class="admin-form">
        <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
        <input type="hidden" name="return_to" value={@return_to} />
        <.text_field
          name="code"
          label="Code"
          hint="000000"
          inputmode="numeric"
          pattern="[0-9]*"
          autocomplete="one-time-code"
          required
        />
        <.submit_button>Verify</.submit_button>
      </form>
    </section>
    """
  end
end
