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
      "/api/matomes" => %PathItem{
        get: %Operation{
          operationId: "MatomeController.index",
          tags: ["matomes"],
          summary: "List authenticated user's matomes",
          responses: resource_responses("Matomes")
        },
        post: %Operation{
          operationId: "MatomeController.create",
          tags: ["matomes"],
          summary: "Create or exactly replay a matome",
          requestBody: matome_create_request_body(),
          responses: matome_create_responses()
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
      "/api/items/text" => %PathItem{
        post: %Operation{
          operationId: "ItemController.create_text",
          tags: ["items"],
          summary: "Create or replay an optionally placed text item",
          requestBody: text_create_request_body(),
          responses: text_create_responses()
        }
      },
      "/api/items/{id}/text" => %PathItem{
        patch: %Operation{
          operationId: "ItemController.update_text",
          tags: ["items"],
          summary: "Version-guard and replace a text item's source body",
          parameters: [id_parameter()],
          requestBody: text_update_request_body(),
          responses: text_mutation_responses("Updated text item")
        },
        delete: %Operation{
          operationId: "ItemController.delete_text",
          tags: ["items"],
          summary: "Version-guard and delete a text item with its payload",
          parameters: [id_parameter()],
          requestBody: text_delete_request_body(),
          responses: text_mutation_responses("Deleted text item", 204)
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
      },
      "/api/items/{id}/download-url" => %PathItem{
        get: %Operation{
          operationId: "ItemController.download_url",
          tags: ["items"],
          summary: "Issue a fresh owner-scoped short-lived external-open descriptor",
          parameters: [id_parameter()],
          responses: download_responses()
        }
      },
      "/api/items/{id}/process" => %PathItem{
        post: %Operation{
          operationId: "ItemController.process",
          tags: ["items", "processing"],
          summary: "Create or replay the authenticated owner's current processing run",
          description:
            "Active transport retries return the same run; a terminal user retry creates a new run and logical attempt.",
          parameters: [id_parameter()],
          responses: %{
            202 => Operation.response("Current processing state", "application/json", nil),
            401 => Operation.response("Unauthorized", "application/json", nil),
            404 => Operation.response("Not found", "application/json", nil),
            422 =>
              Operation.response("Upload, capability, or policy error", "application/json", nil),
            503 =>
              Operation.response("Processor capabilities unavailable", "application/json", nil)
          }
        }
      },
      "/api/v1/items/{item_id}/uploads" => %PathItem{
        post: %Operation{
          operationId: "UploadController.request",
          tags: ["uploads"],
          summary: "Create or resume the authenticated owner's active upload generation",
          parameters: [item_id_parameter()],
          requestBody: upload_request_body(),
          responses: upload_responses("Upload descriptor")
        }
      },
      "/api/v1/uploads/{upload_id}" => %PathItem{
        get: %Operation{
          operationId: "UploadController.inspect",
          tags: ["uploads"],
          summary: "Inspect accepted and missing parts for an owner-scoped upload",
          parameters: [upload_id_parameter()],
          responses: upload_responses("Upload state")
        }
      },
      "/api/v1/uploads/{upload_id}/parts/{part_number}/presign" => %PathItem{
        post: %Operation{
          operationId: "UploadController.presign_part",
          tags: ["uploads"],
          summary: "Presign one checksum-bound multipart part PUT",
          parameters: [upload_id_parameter(), part_number_parameter()],
          requestBody: checksum_request_body("Multipart part"),
          responses: upload_responses("Multipart part request")
        }
      },
      "/api/v1/uploads/{upload_id}/complete" => %PathItem{
        post: %Operation{
          operationId: "UploadController.complete",
          tags: ["uploads"],
          summary: "Verify provider size/checksum/ETags and complete an upload",
          parameters: [upload_id_parameter()],
          requestBody: upload_complete_request_body(),
          responses: upload_responses("Verified upload")
        }
      },
      "/api/v1/uploads/{upload_id}/abort" => %PathItem{
        post: %Operation{
          operationId: "UploadController.abort",
          tags: ["uploads"],
          summary: "Idempotently abort and clean the active upload generation",
          parameters: [upload_id_parameter()],
          requestBody: upload_abort_request_body(),
          responses: upload_responses("Aborted upload")
        }
      },
      "/internal/v1/jobs/{id}/result" => %PathItem{
        post: %Operation{
          operationId: "InternalJobController.result",
          tags: ["processing-internal"],
          summary: "Conditionally apply one signed terminal processor callback",
          description:
            "Requires the per-run HMAC bearer identity. Exact duplicates and stale/conflicting current-run observations are acknowledged without overwrite.",
          parameters: [job_id_parameter()],
          requestBody: processing_callback_request_body(),
          responses: %{
            204 => Operation.response("Applied, duplicate, or stale", "application/json", nil),
            401 => Operation.response("Invalid callback identity", "application/json", nil),
            404 => Operation.response("Unknown persisted dispatch", "application/json", nil),
            422 => Operation.response("Invalid versioned callback", "application/json", nil)
          }
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

  defp matome_create_request_body do
    Operation.request_body("Matome", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:title],
      properties: %{
        client_id: %OpenApiSpex.Schema{
          type: :string,
          minLength: 1,
          maxLength: 255,
          description: "Permanent owner-scoped client identity; immutable when supplied"
        },
        workspace_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
        title: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
        happened_at: %OpenApiSpex.Schema{type: :string, format: :"date-time", nullable: true},
        description: %OpenApiSpex.Schema{type: :string, nullable: true},
        aggregated_summary: %OpenApiSpex.Schema{type: :string, nullable: true}
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

  defp text_create_request_body do
    Operation.request_body("Text item", "application/json", %OpenApiSpex.Schema{
      type: :object,
      additionalProperties: false,
      required: [:client_id, :body],
      properties: %{
        client_id: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
        body: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 200_000},
        matome_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
        workspace_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
        title: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
        metadata: %OpenApiSpex.Schema{type: :object}
      }
    })
  end

  defp text_update_request_body do
    Operation.request_body("Text body revision", "application/json", %OpenApiSpex.Schema{
      type: :object,
      additionalProperties: false,
      required: [:body, :expected_source_revision],
      properties: %{
        body: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 200_000},
        expected_source_revision: source_revision_schema()
      }
    })
  end

  defp text_delete_request_body do
    Operation.request_body("Expected text body revision", "application/json", %OpenApiSpex.Schema{
      type: :object,
      additionalProperties: false,
      required: [:expected_source_revision],
      properties: %{expected_source_revision: source_revision_schema()}
    })
  end

  defp source_revision_schema,
    do: %OpenApiSpex.Schema{type: :integer, minimum: 1, description: "Optimistic body version"}

  defp presign_request_body do
    Operation.request_body("Presign", "application/json", %OpenApiSpex.Schema{
      type: :object,
      properties: %{
        byte_size: %OpenApiSpex.Schema{type: :integer, minimum: 1}
      }
    })
  end

  defp processing_callback_request_body do
    Operation.request_body("AI processing callback v1", "application/json", %OpenApiSpex.Schema{
      type: :object,
      additionalProperties: false,
      required: [:contract_version, :job_id, :run_id, :item_id, :input_revision, :status],
      properties: %{
        contract_version: %OpenApiSpex.Schema{type: :string, enum: ["1"]},
        job_id: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
        run_id: %OpenApiSpex.Schema{type: :string, format: :uuid},
        item_id: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        input_revision: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        status: %OpenApiSpex.Schema{type: :string, enum: ["done", "failed"]},
        outputs: %OpenApiSpex.Schema{
          type: :array,
          minItems: 1,
          maxItems: 10,
          items: %OpenApiSpex.Schema{type: :object}
        },
        error: %OpenApiSpex.Schema{
          type: :object,
          additionalProperties: false,
          required: [:code, :message, :retryable],
          properties: %{
            code: %OpenApiSpex.Schema{
              type: :string,
              pattern: "^[a-z][a-z0-9_]*$",
              maxLength: 100
            },
            message: %OpenApiSpex.Schema{type: :string, maxLength: 1024},
            retryable: %OpenApiSpex.Schema{type: :boolean}
          }
        }
      }
    })
  end

  defp upload_request_body do
    Operation.request_body("Upload request", "application/json", %OpenApiSpex.Schema{
      type: :object,
      properties: %{
        contract_version: %OpenApiSpex.Schema{type: :string, enum: ["1"]},
        mode: %OpenApiSpex.Schema{type: :string, enum: ["auto", "single", "multipart"]},
        content_type: %OpenApiSpex.Schema{type: :string, maxLength: 255},
        checksum_sha256: checksum_schema()
      }
    })
  end

  defp checksum_request_body(description) do
    Operation.request_body(description, "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:checksum_sha256],
      properties: %{checksum_sha256: checksum_schema()}
    })
  end

  defp upload_complete_request_body do
    Operation.request_body("Upload completion", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:upload_generation, :checksum_sha256],
      properties: %{
        contract_version: %OpenApiSpex.Schema{type: :string, enum: ["1"]},
        upload_generation: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        checksum_sha256: checksum_schema(),
        etag: %OpenApiSpex.Schema{type: :string},
        parts: %OpenApiSpex.Schema{
          type: :array,
          items: %OpenApiSpex.Schema{
            type: :object,
            required: [:part_number, :etag, :checksum_sha256],
            properties: %{
              part_number: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 10_000},
              etag: %OpenApiSpex.Schema{type: :string},
              checksum_sha256: checksum_schema()
            }
          }
        }
      }
    })
  end

  defp upload_abort_request_body do
    Operation.request_body("Upload abort", "application/json", %OpenApiSpex.Schema{
      type: :object,
      required: [:upload_generation],
      properties: %{
        contract_version: %OpenApiSpex.Schema{type: :string, enum: ["1"]},
        upload_generation: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        reason: %OpenApiSpex.Schema{type: :string, maxLength: 255}
      }
    })
  end

  defp checksum_schema do
    %OpenApiSpex.Schema{type: :string, pattern: "^[0-9a-f]{64}$"}
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

  defp text_create_responses do
    %{
      201 =>
        Operation.response(
          "Text item created or replayed",
          "application/json",
          text_create_response_schema()
        ),
      401 => Operation.response("Unauthorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil),
      409 =>
        Operation.response(
          "Client id conflict",
          "application/json",
          item_conflict_schema("client_id_conflict")
        ),
      422 => Operation.response("Validation error", "application/json", nil)
    }
  end

  defp matome_create_responses do
    %{
      201 =>
        Operation.response(
          "Matome created or replayed",
          "application/json",
          matome_response_schema()
        ),
      401 => Operation.response("Unauthorized", "application/json", nil),
      409 =>
        Operation.response(
          "Client id conflict",
          "application/json",
          error_schema("client_id_conflict")
        ),
      422 => Operation.response("Validation error", "application/json", nil)
    }
  end

  defp text_mutation_responses(description, success_status \\ 200) do
    success_schema = if success_status == 204, do: nil, else: text_item_response_schema()

    %{
      success_status => Operation.response(description, "application/json", success_schema),
      401 => Operation.response("Unauthorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil),
      409 =>
        Operation.response(
          "Source revision conflict with current item snapshot",
          "application/json",
          item_conflict_schema("version_conflict")
        ),
      422 => Operation.response("Validation or item type error", "application/json", nil)
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
            :expires_at
          ],
          properties: %{
            upload_id: %OpenApiSpex.Schema{type: :string},
            upload_generation: %OpenApiSpex.Schema{type: :integer, minimum: 1},
            mode: %OpenApiSpex.Schema{type: :string, enum: ["single", "multipart"]},
            state: %OpenApiSpex.Schema{type: :string, enum: ["pending", "uploading"]},
            expires_at: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
            part_size: %OpenApiSpex.Schema{type: :integer, minimum: 5_242_880},
            accepted_parts: %OpenApiSpex.Schema{type: :array},
            missing_parts: %OpenApiSpex.Schema{
              type: :array,
              items: %OpenApiSpex.Schema{type: :integer, minimum: 1}
            },
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

  defp text_create_response_schema do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:contract_version, :item],
      properties: %{
        contract_version: %OpenApiSpex.Schema{type: :string, enum: ["1"]},
        item: item_snapshot_schema()
      }
    }
  end

  defp text_item_response_schema do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:item],
      properties: %{item: item_snapshot_schema()}
    }
  end

  defp item_conflict_schema(error) do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:error, :item],
      properties: %{
        error: %OpenApiSpex.Schema{type: :string, enum: [error]},
        item: item_snapshot_schema()
      }
    }
  end

  defp item_snapshot_schema do
    %OpenApiSpex.Schema{
      type: :object,
      required: [
        :id,
        :client_id,
        :item_type,
        :source_revision,
        :processing_state,
        :processing_outputs,
        :text
      ],
      properties: %{
        id: %OpenApiSpex.Schema{type: :integer},
        owner_id: %OpenApiSpex.Schema{type: :integer},
        client_id: %OpenApiSpex.Schema{type: :string},
        workspace_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
        matome_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
        position: %OpenApiSpex.Schema{type: :integer, nullable: true},
        item_type: %OpenApiSpex.Schema{type: :string, enum: ["text"]},
        title: %OpenApiSpex.Schema{type: :string},
        notes: %OpenApiSpex.Schema{type: :string, nullable: true},
        metadata: %OpenApiSpex.Schema{type: :object},
        processing_state: %OpenApiSpex.Schema{type: :string},
        processing_run_id: %OpenApiSpex.Schema{type: :string, format: :uuid, nullable: true},
        processing_attempt: %OpenApiSpex.Schema{type: :integer},
        source_revision: source_revision_schema(),
        processing_config_revision: %OpenApiSpex.Schema{type: :integer, nullable: true},
        processing_capabilities: %OpenApiSpex.Schema{type: :object, nullable: true},
        processing_requested_outputs: %OpenApiSpex.Schema{
          type: :array,
          items: %OpenApiSpex.Schema{type: :string}
        },
        processing_requested_at: %OpenApiSpex.Schema{
          type: :string,
          format: :"date-time",
          nullable: true
        },
        processing_deadline_at: %OpenApiSpex.Schema{
          type: :string,
          format: :"date-time",
          nullable: true
        },
        processing_outputs: %OpenApiSpex.Schema{type: :object},
        processing_error: %OpenApiSpex.Schema{type: :object, nullable: true},
        file: %OpenApiSpex.Schema{type: :object, nullable: true},
        text: %OpenApiSpex.Schema{
          type: :object,
          required: [:id, :body],
          properties: %{
            id: %OpenApiSpex.Schema{type: :integer},
            body: %OpenApiSpex.Schema{type: :string}
          }
        },
        inserted_at: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
        updated_at: %OpenApiSpex.Schema{type: :string, format: :"date-time"}
      }
    }
  end

  defp matome_response_schema do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:matome],
      properties: %{matome: matome_schema()}
    }
  end

  defp matome_schema do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:id, :owner_id, :title, :contacts, :inserted_at, :updated_at],
      properties: %{
        id: %OpenApiSpex.Schema{type: :integer},
        owner_id: %OpenApiSpex.Schema{type: :integer},
        client_id: %OpenApiSpex.Schema{type: :string, nullable: true},
        workspace_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
        title: %OpenApiSpex.Schema{type: :string},
        happened_at: %OpenApiSpex.Schema{type: :string, format: :"date-time", nullable: true},
        description: %OpenApiSpex.Schema{type: :string, nullable: true},
        aggregated_summary: %OpenApiSpex.Schema{type: :string, nullable: true},
        archived_at: %OpenApiSpex.Schema{type: :string, format: :"date-time", nullable: true},
        contacts: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}},
        inserted_at: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
        updated_at: %OpenApiSpex.Schema{type: :string, format: :"date-time"}
      }
    }
  end

  defp error_schema(error) do
    %OpenApiSpex.Schema{
      type: :object,
      required: [:error],
      properties: %{error: %OpenApiSpex.Schema{type: :string, enum: [error]}}
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

  defp download_responses do
    schema = %OpenApiSpex.Schema{
      type: :object,
      required: [:download],
      properties: %{
        download: %OpenApiSpex.Schema{
          type: :object,
          required: [
            :method,
            :url,
            :expires_in,
            :expires_at,
            :filename,
            :content_type,
            :byte_size,
            :open_policy,
            :action
          ],
          properties: %{
            method: %OpenApiSpex.Schema{type: :string, enum: ["GET"]},
            url: %OpenApiSpex.Schema{type: :string, format: :uri},
            expires_in: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 300},
            expires_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
            filename: %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
            original_extension: %OpenApiSpex.Schema{type: :string, nullable: true},
            content_type: %OpenApiSpex.Schema{type: :string},
            byte_size: %OpenApiSpex.Schema{type: :integer, minimum: 1},
            open_policy: %OpenApiSpex.Schema{
              type: :string,
              enum: ["external", "system_app", "attachment_only", "download_only"]
            },
            action: %OpenApiSpex.Schema{type: :string, enum: ["open", "open_in_app", "download"]},
            warning: %OpenApiSpex.Schema{type: :string, nullable: true}
          }
        }
      }
    }

    %{
      200 => Operation.response("Download descriptor", "application/json", schema),
      401 => Operation.response("Unauthorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil),
      422 => Operation.response("Unsafe or unavailable document", "application/json", nil)
    }
  end

  defp upload_responses(description) do
    %{
      200 => Operation.response(description, "application/json", nil),
      401 => Operation.response("Unauthorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil),
      409 => Operation.response("Stale upload generation", "application/json", nil),
      410 => Operation.response("Upload expired", "application/json", nil),
      422 =>
        Operation.response("Upload validation or verification error", "application/json", nil)
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

  defp item_id_parameter do
    Operation.parameter(
      :item_id,
      :path,
      %OpenApiSpex.Schema{type: :integer},
      "Owner-scoped item id",
      required: true
    )
  end

  defp job_id_parameter do
    Operation.parameter(
      :id,
      :path,
      %OpenApiSpex.Schema{type: :string, minLength: 1, maxLength: 255},
      "Opaque processing job id",
      required: true
    )
  end

  defp upload_id_parameter do
    Operation.parameter(
      :upload_id,
      :path,
      %OpenApiSpex.Schema{type: :string},
      "Logical active upload handle",
      required: true
    )
  end

  defp part_number_parameter do
    Operation.parameter(
      :part_number,
      :path,
      %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 10_000},
      "One-based multipart part number",
      required: true
    )
  end

  defp query_parameter do
    Operation.parameter(:q, :query, %OpenApiSpex.Schema{type: :string}, "Search query")
  end
end
