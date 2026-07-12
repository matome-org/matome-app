defmodule MatomeApiWeb.SpaceKeyWrapControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  alias MatomeApi.Content.SpaceMember
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  defp auth_conn(conn, email) do
    register = post(conn, ~p"/api/auth/register", %{email: email, password: @password})
    %{"access_token" => token, "user" => user} = json_response(register, 201)

    %{
      conn: build_conn() |> put_req_header("authorization", "Bearer #{token}"),
      user: Repo.get!(MatomeApi.Auth.User, user["id"])
    }
  end

  test "key-wrap upsert + fetch; stranger forbidden", %{conn: conn} do
    %{conn: owner_conn} =
      auth_conn(conn, "kw-owner-#{System.unique_integer([:positive])}@example.com")

    %{conn: member_conn, user: member} =
      auth_conn(build_conn(), "kw-mem-#{System.unique_integer([:positive])}@example.com")

    %{conn: stranger_conn} =
      auth_conn(build_conn(), "kw-str-#{System.unique_integer([:positive])}@example.com")

    workspace =
      post(owner_conn, ~p"/api/spaces", %{name: "WrapSpace"})
      |> json_response(201)
      |> Map.fetch!("workspace")

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SpaceMember{}
    |> SpaceMember.changeset(%{
      workspace_id: workspace["id"],
      user_id: member.id,
      role: "member",
      granted_at: now
    })
    |> Repo.insert!()

    assert stranger_conn
           |> put(~p"/api/spaces/#{workspace["id"]}/key-wraps/#{member.id}", %{
             wrapper_blob: "YmxvYg==",
             ephemeral_pubkey: "cHVi"
           })
           |> json_response(403)

    assert owner_conn
           |> put(~p"/api/spaces/#{workspace["id"]}/key-wraps/#{member.id}", %{
             wrapper_blob: "YmxvYg==",
             ephemeral_pubkey: "cHVi"
           })
           |> json_response(200)

    me =
      member_conn
      |> get(~p"/api/spaces/#{workspace["id"]}/key-wraps/me")
      |> json_response(200)

    assert me["key_wrap"]["wrapper_blob"] == "YmxvYg=="
    assert me["key_wrap"]["alg_id"] == 1

    pending =
      owner_conn
      |> get(~p"/api/spaces/#{workspace["id"]}/key-wraps/pending")
      |> json_response(200)

    assert pending["pending"] == []
  end
end
