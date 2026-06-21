defmodule MatomeApiWeb.ApiSpec do
  @moduledoc """
  Minimal OpenAPI document for the core API scaffold.
  """

  alias OpenApiSpex.{Info, OpenApi, Operation, PathItem, Server}

  @behaviour OpenApiSpex.OpenApi

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      servers: [%Server{url: "/"}],
      info: %Info{
        title: "Matome Core API",
        version: Application.spec(:matome_api, :vsn) |> to_string()
      },
      paths: paths()
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp paths do
    %{
      "/health" => %PathItem{
        get: %Operation{
          operationId: "HealthController.show",
          tags: ["health"],
          summary: "Health check",
          responses: %{200 => Operation.response("OK", "application/json", nil)}
        }
      },
      "/api/auth/register" => %PathItem{
        post: %Operation{
          operationId: "AuthController.register",
          tags: ["auth"],
          summary: "Register with email and password",
          requestBody: auth_request_body(),
          responses: auth_responses(201)
        }
      },
      "/api/auth/login" => %PathItem{
        post: %Operation{
          operationId: "AuthController.login",
          tags: ["auth"],
          summary: "Login with email and password",
          requestBody: auth_request_body(),
          responses: auth_responses(200)
        }
      },
      "/api/auth/refresh" => %PathItem{
        post: %Operation{
          operationId: "AuthController.refresh",
          tags: ["auth"],
          summary: "Rotate a refresh token and issue new tokens",
          requestBody: refresh_request_body(),
          responses: auth_responses(200)
        }
      },
      "/api/auth/logout" => %PathItem{
        post: %Operation{
          operationId: "AuthController.logout",
          tags: ["auth"],
          summary: "Revoke a refresh token",
          requestBody: refresh_request_body(),
          responses: %{204 => Operation.response("Logged out", "application/json", nil)}
        }
      },
      "/api/auth/me" => %PathItem{
        get: %Operation{
          operationId: "AuthController.me",
          tags: ["auth"],
          summary: "Return the authenticated user",
          responses: %{
            200 => Operation.response("Current user", "application/json", nil),
            401 => Operation.response("Unauthorized", "application/json", nil)
          }
        }
      },
      "/api/spaces" => %PathItem{
        get: %Operation{
          operationId: "WorkspaceController.index",
          tags: ["spaces"],
          summary: "List authenticated user's spaces",
          responses: resource_responses("Spaces")
        },
        post: %Operation{
          operationId: "WorkspaceController.create",
          tags: ["spaces"],
          summary: "Create a space for the authenticated user",
          requestBody: space_request_body(),
          responses: resource_responses("Space", 201)
        }
      },
      "/api/spaces/search" => %PathItem{
        get: %Operation{
          operationId: "WorkspaceController.search",
          tags: ["spaces"],
          summary: "Search authenticated user's spaces by name",
          parameters: [query_parameter()],
          responses: resource_responses("Spaces")
        }
      },
      "/api/spaces/{id}" => %PathItem{
        get: %Operation{
          operationId: "WorkspaceController.show",
          tags: ["spaces"],
          summary: "Get one authenticated-user-owned space",
          parameters: [id_parameter()],
          responses: resource_responses("Space")
        },
        put: %Operation{
          operationId: "WorkspaceController.update",
          tags: ["spaces"],
          summary: "Update one authenticated-user-owned space",
          parameters: [id_parameter()],
          requestBody: space_request_body(),
          responses: resource_responses("Space")
        },
        patch: %Operation{
          operationId: "WorkspaceController.updatePatch",
          tags: ["spaces"],
          summary: "Partially update one authenticated-user-owned space",
          parameters: [id_parameter()],
          requestBody: space_request_body(),
          responses: resource_responses("Space")
        },
        delete: %Operation{
          operationId: "WorkspaceController.delete",
          tags: ["spaces"],
          summary: "Delete one authenticated-user-owned space",
          parameters: [id_parameter()],
          responses: %{
            204 => Operation.response("Deleted", "application/json", nil),
            404 => Operation.response("Not found", "application/json", nil)
          }
        }
      },
      "/api/recordings" => %PathItem{
        get: %Operation{
          operationId: "RecordingController.index",
          tags: ["recordings"],
          summary: "List authenticated user's recordings",
          responses: resource_responses("Recordings")
        },
        post: %Operation{
          operationId: "RecordingController.create",
          tags: ["recordings"],
          summary: "Create a recording for the authenticated user",
          requestBody: recording_request_body(),
          responses: resource_responses("Recording", 201)
        }
      },
      "/api/recordings/search" => %PathItem{
        get: %Operation{
          operationId: "RecordingController.search",
          tags: ["recordings"],
          summary: "Search authenticated user's recordings by title, summary, or transcript",
          parameters: [query_parameter()],
          responses: resource_responses("Recordings")
        }
      },
      "/api/recordings/{id}" => %PathItem{
        get: %Operation{
          operationId: "RecordingController.show",
          tags: ["recordings"],
          summary: "Get one authenticated-user-owned recording",
          parameters: [id_parameter()],
          responses: resource_responses("Recording")
        },
        put: %Operation{
          operationId: "RecordingController.update",
          tags: ["recordings"],
          summary: "Update one authenticated-user-owned recording",
          parameters: [id_parameter()],
          requestBody: recording_request_body(),
          responses: resource_responses("Recording")
        },
        patch: %Operation{
          operationId: "RecordingController.updatePatch",
          tags: ["recordings"],
          summary: "Partially update one authenticated-user-owned recording",
          parameters: [id_parameter()],
          requestBody: recording_request_body(),
          responses: resource_responses("Recording")
        },
        delete: %Operation{
          operationId: "RecordingController.delete",
          tags: ["recordings"],
          summary: "Delete one authenticated-user-owned recording",
          parameters: [id_parameter()],
          responses: %{
            204 => Operation.response("Deleted", "application/json", nil),
            404 => Operation.response("Not found", "application/json", nil)
          }
        }
      },
      "/api/recordings/{id}/download-url" => %PathItem{
        get: %Operation{
          operationId: "RecordingController.downloadUrl",
          tags: ["recordings"],
          summary: "Issue a short-lived presigned GET URL for one owned recording's media",
          parameters: [id_parameter()],
          responses: resource_responses("Presigned download URL")
        }
      },
      "/api/recordings/{id}/process" => %PathItem{
        post: %Operation{
          operationId: "RecordingController.process",
          tags: ["recordings"],
          summary: "Queue internal AI processing after media upload completes",
          parameters: [id_parameter()],
          responses: resource_responses("Recording processing queued", 202)
        }
      },
      "/api/matomes/{id}/archive" => %PathItem{
        post: %Operation{
          operationId: "MatomeController.archive",
          tags: ["matomes"],
          summary:
            "Archive (soft-delete) one authenticated-user-owned matome; it leaves the default lists but its data is retained and recoverable",
          parameters: [id_parameter()],
          responses: resource_responses("Matome")
        }
      },
      "/api/matomes/{id}/restore" => %PathItem{
        post: %Operation{
          operationId: "MatomeController.restore",
          tags: ["matomes"],
          summary: "Restore (un-archive) one authenticated-user-owned matome",
          parameters: [id_parameter()],
          responses: resource_responses("Matome")
        }
      }
    }
  end

  defp auth_request_body do
    Operation.request_body("Credentials", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:email, :password],
      properties: %{
        email: %OpenApiSpex.Schema{type: :string},
        password: %OpenApiSpex.Schema{type: :string}
      }
    })
  end

  defp refresh_request_body do
    Operation.request_body("Refresh token", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:refresh_token],
      properties: %{refresh_token: %OpenApiSpex.Schema{type: :string}}
    })
  end

  defp auth_responses(success_status) do
    %{
      success_status => Operation.response("Auth tokens", "application/json", nil),
      401 => Operation.response("Unauthorized", "application/json", nil),
      422 => Operation.response("Validation error", "application/json", nil)
    }
  end

  defp space_request_body do
    Operation.request_body("Space", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:name],
      properties: %{
        name: %OpenApiSpex.Schema{type: :string},
        description: %OpenApiSpex.Schema{type: :string}
      }
    })
  end

  defp recording_request_body do
    Operation.request_body("Recording", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:title],
      properties: %{
        title: %OpenApiSpex.Schema{type: :string},
        summary: %OpenApiSpex.Schema{type: :string},
        transcript: %OpenApiSpex.Schema{type: :string},
        media_type: %OpenApiSpex.Schema{type: :string},
        status: %OpenApiSpex.Schema{
          type: :string,
          enum: ["pending", "processing", "done", "failed"]
        },
        error_reason: %OpenApiSpex.Schema{type: :string},
        duration: %OpenApiSpex.Schema{type: :integer},
        badge: %OpenApiSpex.Schema{type: :string},
        workspace_id: %OpenApiSpex.Schema{type: :integer}
      }
    })
  end

  defp resource_responses(description, success_status \\ 200) do
    %{
      success_status => Operation.response(description, "application/json", nil),
      401 => Operation.response("Unauthorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil),
      422 => Operation.response("Validation error", "application/json", nil)
    }
  end

  defp id_parameter do
    Operation.parameter(:id, :path, %OpenApiSpex.Schema{type: :integer}, "Resource id",
      required: true
    )
  end

  defp query_parameter do
    Operation.parameter(:q, :query, %OpenApiSpex.Schema{type: :string}, "Search query")
  end
end
