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
    assert Map.has_key?(body["paths"], "/api/matomes")
    assert Map.has_key?(body["paths"], "/api/matomes/{matome_id}/items")
    assert Map.has_key?(body["paths"], "/api/items/text")
    assert Map.has_key?(body["paths"], "/api/items/{id}/text")
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

    text_create = body["paths"]["/api/items/text"]["post"]

    text_create_schema =
      get_in(text_create, ["requestBody", "content", "application/json", "schema"])

    assert text_create_schema["additionalProperties"] == false
    assert text_create_schema["required"] == ["client_id", "body"]
    refute Map.has_key?(text_create_schema["properties"], "notes")

    text_create_success =
      get_in(text_create, ["responses", "201", "content", "application/json", "schema"])

    assert text_create_success["required"] == ["contract_version", "item"]

    assert text_create_success["properties"]["item"]["properties"]["source_revision"]["minimum"] ==
             1

    text_create_conflict =
      get_in(text_create, ["responses", "409", "content", "application/json", "schema"])

    assert text_create_conflict["required"] == ["error", "item"]
    assert text_create_conflict["properties"]["error"]["enum"] == ["client_id_conflict"]

    text_update = body["paths"]["/api/items/{id}/text"]["patch"]

    text_update_schema =
      get_in(text_update, ["requestBody", "content", "application/json", "schema"])

    assert text_update_schema["required"] == ["body", "expected_source_revision"]

    assert text_update_schema["properties"]["expected_source_revision"]["description"] ==
             "Optimistic body version"

    assert text_update["responses"]["409"]["description"] =~ "current item snapshot"

    update_success =
      get_in(text_update, ["responses", "200", "content", "application/json", "schema"])

    assert update_success["required"] == ["item"]

    update_conflict =
      get_in(text_update, ["responses", "409", "content", "application/json", "schema"])

    assert update_conflict["required"] == ["error", "item"]

    text_delete = body["paths"]["/api/items/{id}/text"]["delete"]
    delete_schema = get_in(text_delete, ["requestBody", "content", "application/json", "schema"])
    assert delete_schema["required"] == ["expected_source_revision"]

    matome_create = body["paths"]["/api/matomes"]["post"]

    matome_request =
      get_in(matome_create, ["requestBody", "content", "application/json", "schema"])

    assert matome_request["properties"]["client_id"]["description"] =~ "Permanent"

    matome_success =
      get_in(matome_create, ["responses", "201", "content", "application/json", "schema"])

    assert matome_success["required"] == ["matome"]
    assert Map.has_key?(matome_success["properties"]["matome"]["properties"], "client_id")

    matome_conflict =
      get_in(matome_create, ["responses", "409", "content", "application/json", "schema"])

    assert matome_conflict["properties"]["error"]["enum"] == ["client_id_conflict"]

    create_schema =
      get_in(item_create, ["responses", "201", "content", "application/json", "schema"])

    assert create_schema["required"] == ["contract_version", "item"]

    assert create_schema["properties"]["upload"]["properties"]["request"]["required"] ==
             ["method", "url", "headers"]

    assert create_schema["properties"]["upload"]["properties"]["mode"]["enum"] ==
             ["single", "multipart"]

    upload_request_schema =
      get_in(body, [
        "paths",
        "/api/v1/items/{item_id}/uploads",
        "post",
        "requestBody",
        "content",
        "application/json",
        "schema"
      ])

    assert upload_request_schema["properties"]["content_type"] == %{
             "type" => "string",
             "maxLength" => 255
           }

    descriptor =
      get_in(body, [
        "paths",
        "/api/items/{id}/download-url",
        "get",
        "responses",
        "200",
        "content",
        "application/json",
        "schema",
        "properties",
        "download"
      ])

    assert "open_policy" in descriptor["required"]
    assert descriptor["properties"]["expires_in"]["maximum"] == 300
    refute "blocked" in descriptor["properties"]["open_policy"]["enum"]

    refute Map.has_key?(body["paths"], "/api/recordings")
    refute Map.has_key?(body["paths"], "/api/recordings/search")
    refute Map.has_key?(body["paths"], "/api/recordings/{id}")
  end
end
