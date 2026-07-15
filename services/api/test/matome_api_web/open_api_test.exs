defmodule MatomeApiWeb.OpenApiTest do
  use MatomeApiWeb.ConnCase, async: true

  test "GET /openapi serves a valid minimal spec", %{conn: conn} do
    conn = get(conn, ~p"/openapi")
    body = json_response(conn, 200)

    assert body["openapi"] =~ "3."
    assert body["info"]["title"] == "Matome Core API"
    assert Map.has_key?(body["paths"], "/health")
    assert Map.has_key?(body["paths"], "/api/auth/register")
    assert Map.has_key?(body["paths"], "/api/auth/login")
    assert Map.has_key?(body["paths"], "/api/auth/refresh")
    assert Map.has_key?(body["paths"], "/api/auth/logout")
    assert Map.has_key?(body["paths"], "/api/auth/me")
    assert Map.has_key?(body["paths"], "/api/spaces")
    assert Map.has_key?(body["paths"], "/api/spaces/search")
    assert Map.has_key?(body["paths"], "/api/spaces/{id}")
    assert Map.has_key?(body["paths"], "/api/matomes/{matome_id}/items")
    assert Map.has_key?(body["paths"], "/api/items/{id}")
    assert Map.has_key?(body["paths"], "/api/items/{id}/presign")
    assert Map.has_key?(body["paths"], "/api/items/{id}/process")
    assert Map.has_key?(body["paths"], "/api/v1/items/{item_id}/uploads")
    assert Map.has_key?(body["paths"], "/api/v1/uploads/{upload_id}")

    assert Map.has_key?(
             body["paths"],
             "/api/v1/uploads/{upload_id}/parts/{part_number}/presign"
           )

    assert Map.has_key?(body["paths"], "/api/v1/uploads/{upload_id}/complete")
    assert Map.has_key?(body["paths"], "/api/v1/uploads/{upload_id}/abort")
    assert Map.has_key?(body["paths"], "/internal/v1/jobs/{id}/result")

    callback = body["paths"]["/internal/v1/jobs/{id}/result"]["post"]
    callback_schema = get_in(callback, ["requestBody", "content", "application/json", "schema"])
    assert callback_schema["additionalProperties"] == false
    assert callback_schema["properties"]["contract_version"]["enum"] == ["1"]
    assert callback_schema["properties"]["status"]["enum"] == ["done", "failed"]

    item_schema =
      body
      |> get_in([
        "paths",
        "/api/matomes/{matome_id}/items",
        "post",
        "requestBody",
        "content",
        "application/json",
        "schema"
      ])

    assert item_schema["discriminator"] == %{"propertyName" => "item_type"}
    assert item_schema["properties"]["item_type"]["enum"] == ["file", "text"]
    assert item_schema["properties"]["client_id"]["type"] == "string"

    item_create = body["paths"]["/api/matomes/{matome_id}/items"]["post"]
    assert item_create["responses"]["409"]["description"] == "Client id conflict"

    create_schema =
      get_in(item_create, ["responses", "201", "content", "application/json", "schema"])

    assert create_schema["required"] == ["contract_version", "item"]

    assert create_schema["properties"]["upload"]["properties"]["request"]["required"] ==
             ["method", "url", "headers"]

    assert create_schema["properties"]["upload"]["properties"]["mode"]["enum"] ==
             ["single", "multipart"]

    refute Map.has_key?(body["paths"], "/api/recordings")
    refute Map.has_key?(body["paths"], "/api/recordings/search")
    refute Map.has_key?(body["paths"], "/api/recordings/{id}")
  end
end
