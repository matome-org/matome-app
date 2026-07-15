defmodule MatomeApi.Storage.PresignerServerEndpointTest do
  use ExUnit.Case, async: false

  alias MatomeApi.Storage.Presigner

  @storage_key "owners/42/items/server-endpoint"

  setup do
    previous = Application.fetch_env!(:matome_api, Presigner)

    Application.put_env(
      :matome_api,
      Presigner,
      Keyword.put(previous, :server_endpoint, "http://storage.internal:9000")
    )

    on_exit(fn -> Application.put_env(:matome_api, Presigner, previous) end)
  end

  test "server operations use the internal endpoint while client part PUTs remain public" do
    checksum = String.duplicate("a", 64)

    assert {:ok, create} =
             Presigner.presign_multipart_create(@storage_key, checksum_sha256: checksum)

    assert URI.parse(create.url).host == "storage.internal"

    assert {:ok, part} =
             Presigner.presign_upload_part(@storage_key, "provider-upload", 1,
               content_length: 5 * 1024 * 1024,
               checksum_sha256: checksum
             )

    assert URI.parse(part.url).host in ["127.0.0.1", "localhost"]
  end
end
