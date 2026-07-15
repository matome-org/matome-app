defmodule MatomeApi.Storage.MinioMultipartIntegrationTest do
  use ExUnit.Case, async: false

  alias MatomeApi.Storage.ObjectStore

  @moduletag skip: System.get_env("MINIO_INTEGRATION") != "1"

  setup do
    previous = Application.get_env(:matome_api, ObjectStore)
    Application.delete_env(:matome_api, ObjectStore)
    {:ok, cleanup} = Agent.start(fn -> [] end)

    on_exit(fn ->
      cleanup
      |> Agent.get(& &1)
      |> Enum.each(fn {storage_key, upload_id} ->
        ObjectStore.abort_multipart(storage_key, upload_id)
        ObjectStore.delete_object(storage_key)
      end)

      Agent.stop(cleanup)

      if previous do
        Application.put_env(:matome_api, ObjectStore, previous)
      else
        Application.delete_env(:matome_api, ObjectStore)
      end
    end)

    {:ok, cleanup: cleanup}
  end

  test "uploads more than 25 MiB byte-identically and aborts without residue", %{
    cleanup: cleanup
  } do
    byte_size = 26 * 1024 * 1024
    seed = "matome-minio-multipart\n"
    data = :binary.copy(seed, div(byte_size, byte_size(seed)) + 1) |> binary_part(0, byte_size)
    checksum = sha256(data)
    storage_key = "owners/999999/integration/#{Ecto.UUID.generate()}"

    on_exit(fn -> ObjectStore.delete_object(storage_key) end)

    assert {:ok, %{upload_id: upload_id}} =
             ObjectStore.initiate_multipart(storage_key,
               byte_size: byte_size,
               checksum_sha256: checksum,
               content_type: "audio/wav"
             )

    Agent.update(cleanup, &[{storage_key, upload_id} | &1])

    part_size = 16 * 1024 * 1024

    for {part, part_number} <-
          [
            {binary_part(data, 0, part_size), 1},
            {binary_part(data, part_size, byte_size - part_size), 2}
          ] do
      part_checksum = sha256(part)

      assert {:ok, request} =
               ObjectStore.presign_part(storage_key, upload_id, part_number,
                 content_length: byte_size(part),
                 checksum_sha256: part_checksum
               )

      assert {:ok, {{_, status, _}, _headers, _body}} =
               :httpc.request(
                 :put,
                 {
                   String.to_charlist(request.url),
                   Enum.map(request.headers, fn {key, value} ->
                     {String.to_charlist(key), String.to_charlist(value)}
                   end),
                   ~c"application/octet-stream",
                   part
                 },
                 [],
                 []
               )

      assert status in 200..299
    end

    assert {:ok, parts} = ObjectStore.list_parts(storage_key, upload_id)
    assert Enum.map(parts, & &1.part_number) == [1, 2]
    assert Enum.sum(Enum.map(parts, & &1.byte_size)) == byte_size
    assert Enum.all?(parts, &Regex.match?(~r/^[0-9a-f]{64}$/, &1.checksum_sha256))

    assert :ok = ObjectStore.complete_multipart(storage_key, upload_id, parts)
    assert {:ok, head} = ObjectStore.head_object(storage_key)
    assert head.byte_size == byte_size
    assert head.checksum_sha256 == checksum
    assert {:ok, ^data} = ObjectStore.get_object(storage_key)

    abort_key = "owners/999999/integration/#{Ecto.UUID.generate()}"

    assert {:ok, %{upload_id: abort_id}} =
             ObjectStore.initiate_multipart(abort_key,
               byte_size: byte_size,
               checksum_sha256: checksum
             )

    Agent.update(cleanup, &[{abort_key, abort_id} | &1])

    assert :ok = ObjectStore.abort_multipart(abort_key, abort_id)
    assert {:error, :no_such_upload} = ObjectStore.list_parts(abort_key, abort_id)
    assert {:error, :not_found} = ObjectStore.head_object(abort_key)
  end

  defp sha256(value),
    do: value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end
