defmodule MatomeApiWeb.AdminSessionController do
  @moduledoc """
  /admin login: email allowlist → one-shot email OTP → short-TTL session.

  Non-allowlisted emails get total silence (200 re-render, no flash, no mail).
  """

  use MatomeApiWeb, :html_controller

  alias MatomeApi.Admin
  alias MatomeApiWeb.AdminAuth

  def new(conn, _params) do
    render(conn, :new, page_title: "Admin sign-in")
  end

  def create(conn, params) do
    email = params["email"] || ""

    case Admin.request_login_otp(email, remote_ip: remote_ip(conn)) do
      {:ok, :sent} ->
        conn
        |> AdminAuth.put_pending_email(email)
        |> redirect(to: "/admin/otp")

      :silent ->
        # Total silence — same page, no flash, no redirect.
        conn
        |> put_status(200)
        |> render(:new, page_title: "Admin sign-in")

      {:error, _} ->
        # Allowlisted but delivery failed — still silent to the browser;
        # ops see logs/mailer errors. Do not park a pending session.
        conn
        |> put_status(200)
        |> render(:new, page_title: "Admin sign-in")
    end
  end

  def otp(conn, params) do
    cond do
      AdminAuth.pending_email(conn) ->
        render(conn, :otp,
          page_title: "Enter code",
          return_to: safe_return_to(params["return_to"])
        )

      admin_session?(conn) ->
        # Sensitive-action re-auth: send a fresh OTP for the session email.
        {:ok, admin} = AdminAuth.admin_from_session(get_session(conn))

        case Admin.request_login_otp(admin.email, remote_ip: remote_ip(conn)) do
          {:ok, :sent} ->
            conn
            |> AdminAuth.put_pending_email(admin.email)
            |> render(:otp,
              page_title: "Verify it's you",
              return_to: safe_return_to(params["return_to"])
            )

          _ ->
            redirect_to_login(conn)
        end

      true ->
        redirect_to_login(conn)
    end
  end

  def verify_otp(conn, params) do
    code = params["code"] || ""

    cond do
      email = AdminAuth.pending_email(conn) ->
        complete_otp(conn, email, code, safe_return_to(params["return_to"]))

      true ->
        redirect_to_login(conn)
    end
  end

  def delete(conn, _params) do
    with {:ok, admin} <- AdminAuth.admin_from_session(get_session(conn)) do
      Admin.audit!("admin.logout", actor: admin, remote_ip: remote_ip(conn))
    end

    conn
    |> AdminAuth.log_out_admin()
    |> redirect(to: "/admin/login")
  end

  defp complete_otp(conn, email, code, return_to) do
    reauth? = match?({:ok, _}, AdminAuth.admin_from_session(get_session(conn)))

    case Admin.verify_login_otp(email, code) do
      {:ok, ^email} ->
        if reauth? do
          Admin.audit!("admin.reauth", actor: %{email: email}, remote_ip: remote_ip(conn))

          conn
          |> AdminAuth.refresh_otp_verification()
          |> redirect(to: return_to)
        else
          Admin.audit!("admin.login", actor: %{email: email}, remote_ip: remote_ip(conn))

          conn
          |> AdminAuth.complete_admin_login(email)
          |> redirect(to: if(return_to == "/admin", do: "/admin", else: return_to))
        end

      {:error, :rate_limited} ->
        Admin.audit!("admin.login_failed",
          actor: %{email: email},
          metadata: %{"reason" => "rate_limited"},
          remote_ip: remote_ip(conn)
        )

        conn
        |> put_flash(:error, "Too many attempts. Try again later.")
        |> redirect(to: otp_path(return_to))

      {:error, _} ->
        Admin.audit!("admin.login_failed",
          actor: %{email: email},
          metadata: %{"reason" => "invalid_code"},
          remote_ip: remote_ip(conn)
        )

        conn
        |> put_flash(:error, "Invalid code.")
        |> redirect(to: otp_path(return_to))
    end
  end

  defp otp_path("/admin"), do: "/admin/otp"
  defp otp_path(return_to), do: "/admin/otp?return_to=#{URI.encode_www_form(return_to)}"

  defp admin_session?(conn) do
    match?({:ok, _}, AdminAuth.admin_from_session(get_session(conn)))
  end

  defp redirect_to_login(conn), do: conn |> redirect(to: "/admin/login") |> halt()

  defp safe_return_to("/" <> _ = path), do: path
  defp safe_return_to(_), do: "/admin"

  defp remote_ip(conn), do: to_string(:inet.ntoa(conn.remote_ip))
end
