defmodule MatomeApiWeb.AdminSessionController do
  @moduledoc """
  The /admin login flow (W3 #1871): password (first factor) → TOTP (second,
  MANDATORY — including forced enrollment on first login) → short-TTL
  session. Every outcome that matters is written to the append-only
  `admin_audit_events` from day one:

  - `admin.login` / `admin.login_failed`
  - `admin.totp_enrolled`
  - `admin.reauth` (sensitive-action re-verification)
  - `admin.logout`
  """

  use MatomeApiWeb, :html_controller

  alias MatomeApi.Admin
  alias MatomeApiWeb.AdminAuth

  # -- first factor -----------------------------------------------------

  def new(conn, _params) do
    render(conn, :new, page_title: "Admin sign-in")
  end

  def create(conn, params) do
    email = params["email"] || ""
    password = params["password"] || ""

    case Admin.authenticate_admin(email, password) do
      {:ok, user} ->
        conn
        |> AdminAuth.put_pending_admin(user)
        |> redirect(to: "/admin/mfa")

      {:error, :invalid_credentials} ->
        Admin.audit!("admin.login_failed",
          metadata: %{"email" => email},
          remote_ip: remote_ip(conn)
        )

        conn
        |> put_flash(:error, "Invalid credentials.")
        |> redirect(to: "/admin/login")
    end
  end

  # -- second factor / re-auth ------------------------------------------

  def mfa(conn, params) do
    cond do
      user = AdminAuth.pending_admin(conn) ->
        render_mfa(conn, user, params)

      admin_session?(conn) ->
        # Sensitive-action re-auth for an already-signed-in admin.
        render(conn, :mfa,
          page_title: "Verify it's you",
          enrollment: nil,
          return_to: safe_return_to(params["return_to"])
        )

      true ->
        redirect_to_login(conn)
    end
  end

  def verify_mfa(conn, params) do
    code = params["code"] || ""

    cond do
      user = AdminAuth.pending_admin(conn) ->
        complete_second_factor(conn, user, code)

      admin_session?(conn) ->
        reauth(conn, code, safe_return_to(params["return_to"]))

      true ->
        redirect_to_login(conn)
    end
  end

  def delete(conn, _params) do
    with {:ok, user} <- AdminAuth.admin_from_session(get_session(conn)) do
      Admin.audit!("admin.logout", actor: user, remote_ip: remote_ip(conn))
    end

    conn
    |> AdminAuth.log_out_admin()
    |> redirect(to: "/admin/login")
  end

  # -- internals ---------------------------------------------------------

  defp render_mfa(conn, user, params) do
    enrollment =
      if Admin.totp_enabled?(user) do
        nil
      else
        # Mandatory MFA: a first-time admin cannot skip enrollment — this
        # page (secret + otpauth URI + confirmation code form) is the only
        # way forward, and login completes only after the code verifies.
        {:ok, secret} = Admin.start_totp_enrollment(user)

        %{
          secret_base32: Base.encode32(secret, padding: false),
          otpauth_uri: Admin.TOTP.otpauth_uri(secret, user.email)
        }
      end

    render(conn, :mfa,
      page_title: "Two-factor authentication",
      enrollment: enrollment,
      return_to: safe_return_to(params["return_to"])
    )
  end

  defp complete_second_factor(conn, user, code) do
    result =
      if Admin.totp_enabled?(user) do
        Admin.verify_totp(user, code)
      else
        with :ok <- Admin.confirm_totp_enrollment(user, code) do
          Admin.audit!("admin.totp_enrolled", actor: user, remote_ip: remote_ip(conn))
          :ok
        end
      end

    case result do
      :ok ->
        Admin.audit!("admin.login", actor: user, remote_ip: remote_ip(conn))

        conn
        |> AdminAuth.complete_admin_login(user)
        |> redirect(to: "/admin")

      {:error, :rate_limited} ->
        Admin.audit!("admin.mfa_locked", actor: user, remote_ip: remote_ip(conn))

        conn
        |> put_flash(:error, "Too many attempts. Try again later.")
        |> redirect(to: "/admin/mfa")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid code.")
        |> redirect(to: "/admin/mfa")
    end
  end

  defp reauth(conn, code, return_to) do
    {:ok, user} = AdminAuth.admin_from_session(get_session(conn))

    case Admin.verify_totp(user, code) do
      :ok ->
        Admin.audit!("admin.reauth", actor: user, remote_ip: remote_ip(conn))

        conn
        |> AdminAuth.refresh_totp_verification()
        |> redirect(to: return_to)

      {:error, :rate_limited} ->
        conn
        |> put_flash(:error, "Too many attempts. Try again later.")
        |> redirect(to: "/admin/mfa?return_to=#{URI.encode_www_form(return_to)}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid code.")
        |> redirect(to: "/admin/mfa?return_to=#{URI.encode_www_form(return_to)}")
    end
  end

  defp admin_session?(conn) do
    match?({:ok, _}, AdminAuth.admin_from_session(get_session(conn)))
  end

  defp redirect_to_login(conn), do: conn |> redirect(to: "/admin/login") |> halt()

  # Only same-app absolute paths — never an attacker-supplied host.
  defp safe_return_to("/" <> _ = path), do: path
  defp safe_return_to(_), do: "/admin"

  defp remote_ip(conn), do: to_string(:inet.ntoa(conn.remote_ip))
end
