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
      },
      "/api/matomes/{matome_id}/items" => %PathItem{
        get: %Operation{
          operationId: "ItemController.index",
          tags: ["items"],
          summary: "List items for one authenticated-user-owned matome",
          parameters: [matome_id_parameter()],
          responses: resource_responses("Items")
        },
        post: %Operation{
          operationId: "ItemController.create",
          tags: ["items"],
          summary: "Create a text or file item for one authenticated-user-owned matome",
          parameters: [matome_id_parameter()],
          requestBody: item_request_body(),
          responses: item_create_responses()
        }
      },
      "/api/items/{id}" => %PathItem{
        get: %Operation{
          operationId: "ItemController.show",
          tags: ["items"],
          summary: "Get one authenticated-user-owned item",
          parameters: [id_parameter()],
          responses: resource_responses("Item")
        },
        delete: %Operation{
          operationId: "ItemController.delete",
          tags: ["items"],
          summary: "Delete one authenticated-user-owned item and its payload",
          parameters: [id_parameter()],
          responses: %{
            204 => Operation.response("Deleted", "application/json", nil),
            401 => Operation.response("Unauthorized", "application/json", nil),
            404 => Operation.response("Not found", "application/json", nil),
            422 => Operation.response("Validation error", "application/json", nil)
          }
        }
      },
      "/api/items/{id}/presign" => %PathItem{
        post: %Operation{
          operationId: "ItemController.presign",
          tags: ["items"],
          summary: "Issue an upload presign for a file item; text items are rejected",
          parameters: [id_parameter()],
          requestBody: presign_request_body(),
          responses: resource_responses("Presign")
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

  defp item_request_body do
    Operation.request_body("Item", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:item_type],
      discriminator: %{propertyName: "item_type"},
      properties: %{
        client_id: %OpenApiSpex.Schema{
          type: :string,
          minLength: 1,
          maxLength: 255,
          description:
            "Permanent client item id. Replays are owner-scoped; conflicting reuse returns 409."
        },
        item_type: %OpenApiSpex.Schema{type: :string, enum: ["file", "text"]},
        position: %OpenApiSpex.Schema{type: :integer, minimum: 0},
        workspace_id: %OpenApiSpex.Schema{
          type: :integer,
          nullable: true,
          description: "Direct Space placement; shadowed while matome_id is set"
        },
        title: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
        notes: %OpenApiSpex.Schema{type: :string, nullable: true},
        metadata: %OpenApiSpex.Schema{type: :object},
        body: %OpenApiSpex.Schema{type: :string, description: "Required when item_type is text"},
        filename: %OpenApiSpex.Schema{type: :string, maxLength: 1024},
        content_type: %OpenApiSpex.Schema{type: :string, maxLength: 255},
        checksum_sha256: %OpenApiSpex.Schema{
          type: :string,
          pattern: "^[0-9a-f]{64}$"
        },
        byte_size: %OpenApiSpex.Schema{
          type: :integer,
          minimum: 1,
          description: "Required when item_type is file"
        },
        media_type: %OpenApiSpex.Schema{
          type: :string,
          enum: ["audio", "image", "document", "video"]
        },
        duration: %OpenApiSpex.Schema{type: :integer, minimum: 0}
      }
    })
  end

  defp presign_request_body do
    Operation.request_body("Presign", "application/json", %OpenApiSpex.Schema{
      type: :object,
      properties: %{
        byte_size: %OpenApiSpex.Schema{type: :integer, minimum: 1}
      }
    })
  end

  defp item_create_responses do
    %{
      201 =>
        Operation.response(
          "Item created or replayed",
          "application/json",
          item_create_response_schema()
        ),
      401 => Operation.response("Unauthorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil),
      409 => Operation.response("Client id conflict", "application/json", nil),
      413 => Operation.response("Quota exceeded", "application/json", nil),
      422 => Operation.response("Validation error", "application/json", nil)
    }
  end

  defp item_create_response_schema do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:contract_version, :item],
      properties: %{
        contract_version: %OpenApiSpex.Schema{type: :string, enum: ["1"]},
        item: %OpenApiSpex.Schema{type: :object},
        upload: %OpenApiSpex.Schema{
          type: :object,
          required: [
            :upload_id,
            :upload_generation,
            :mode,
            :state,
            :expires_at,
            :request
          ],
          properties: %{
            upload_id: %OpenApiSpex.Schema{type: :string},
            upload_generation: %OpenApiSpex.Schema{type: :integer, minimum: 1},
            mode: %OpenApiSpex.Schema{type: :string, enum: ["single"]},
            state: %OpenApiSpex.Schema{type: :string, enum: ["pending"]},
            expires_at: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
            request: %OpenApiSpex.Schema{
              type: :object,
              required: [:method, :url, :headers],
              properties: %{
                method: %OpenApiSpex.Schema{type: :string, enum: ["PUT"]},
                url: %OpenApiSpex.Schema{type: :string, format: :uri},
                headers: %OpenApiSpex.Schema{type: :object}
              }
            }
          }
        }
      }
    }
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

  defp matome_id_parameter do
    Operation.parameter(:matome_id, :path, %OpenApiSpex.Schema{type: :integer}, "Matome id",
      required: true
    )
  end

  defp query_parameter do
    Operation.parameter(:q, :query, %OpenApiSpex.Schema{type: :string}, "Search query")
  end
end
