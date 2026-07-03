defmodule MatomeApiWeb.InternalJobControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  @token "dev-ai-token"

  test "rejects callbacks without the internal service token", %{conn: conn} do
    conn = post(conn, "/internal/jobs/recording:1:attempt:1/result", %{})
    assert json_response(conn, 401) == %{"error" => "unauthorized"}
  end

  test "recording callbacks no longer match a supported Core payload", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/recording:1:attempt:1/result", %{
        job_id: "recording:1:attempt:1",
        recording_id: 1,
        status: "done"
      })

    assert json_response(conn, 404) == %{"error" => "not_found"}
  end

  test "item callbacks for unknown files return not found", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/item:999:file_blob:888/result", %{
        item_id: 999,
        file_blob_id: 888,
        transcript: "missing"
      })

    assert json_response(conn, 404) == %{"error" => "not_found"}
  end
end
