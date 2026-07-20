defmodule MatomeApiWeb.SpaceQuotaControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Content
  alias MatomeApi.Content.Workspace
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  test "file create over quota returns 413", %{conn: conn} do
    email = "q413-#{System.unique_integer([:positive])}@example.com"
    register = post(conn, ~p"/api/auth/register", %{email: email, password: @password})
    %{"access_token" => token, "user" => user} = json_response(register, 201)
    owner_conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")

    owner = Repo.get!(MatomeApi.Auth.User, user["id"])
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Tight"})

    workspace
    |> Workspace.admin_changeset(%{quota_bytes: 100})
    |> Repo.update!()

    matome =
      post(owner_conn, ~p"/api/matomes", %{title: "M", workspace_id: workspace.id})
      |> json_response(201)
      |> Map.fetch!("matome")

    resp =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        media_type: "audio",
        content_length: 200
      })

    assert json_response(resp, 413) == %{"error" => "quota_exceeded"}
  end
end
