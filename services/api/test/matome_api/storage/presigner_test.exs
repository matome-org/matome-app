defmodule MatomeApi.Storage.PresignerTest do
  use ExUnit.Case, async: true

  alias MatomeApi.Storage.Presigner

  @owner_key "owners/42/recordings/7/media"

  describe "owner-prefix guard" do
    test "presign_upload accepts a server-derived owners/ key" do
      assert {:ok, upload} = Presigner.presign_upload(@owner_key, content_length: 1_000)
      assert upload.method == "PUT"
      assert upload.storage_key == @owner_key
      assert upload.url =~ "/media/owners/42/recordings/7/media?"
      assert upload.url =~ "X-Amz-Signature="
    end

    test "presign_upload rejects a key outside the owners/ prefix" do
      assert {:error, :invalid_storage_key} =
               Presigner.presign_upload("etc/passwd", content_length: 1_000)
    end

    test "presign_download rejects a key outside the owners/ prefix" do
      assert {:error, :invalid_storage_key} = Presigner.presign_download("../../secret")
    end

    test "presign_delete signs a DELETE URL for owner-scoped garbage collection" do
      assert {:ok, delete} = Presigner.presign_delete(@owner_key)

      assert delete.method == "DELETE"
      assert delete.storage_key == @owner_key
      assert delete.url =~ "/media/owners/42/recordings/7/media?"
    end
  end

  describe "provider upload bounds and integrity headers" do
    test "max_upload_bytes is the S3-compatible object bound, not the single PUT threshold" do
      assert Presigner.max_upload_bytes() == 5 * 1024 * 1024 * 1024 * 1024
    end

    test "an upload at the ceiling is allowed" do
      assert {:ok, upload} =
               Presigner.presign_upload(@owner_key, content_length: Presigner.max_upload_bytes())

      assert upload.max_bytes == Presigner.max_upload_bytes()
    end

    test "an oversized upload is rejected server-side before a URL is issued" do
      oversized = Presigner.max_upload_bytes() + 1

      assert {:error, :too_large} =
               Presigner.presign_upload(@owner_key, content_length: oversized)
    end

    test "the declared content length is signed into the PUT URL" do
      {:ok, upload} = Presigner.presign_upload(@owner_key, content_length: 1_234)

      # content-length is part of the signed headers, so the object store will
      # reject a request whose body length differs from what was presigned.
      assert upload.url =~ "X-Amz-SignedHeaders=content-length%3Bhost"
      assert upload.content_length == 1_234
    end

    test "single PUT checksum metadata and provider verification headers are signed" do
      checksum = String.duplicate("a", 64)

      {:ok, upload} =
        Presigner.presign_upload(@owner_key, content_length: 1_234, checksum_sha256: checksum)

      assert upload.headers["x-amz-meta-sha256"] == checksum
      assert upload.headers["x-amz-checksum-sha256"]
      assert upload.url =~ "x-amz-checksum-sha256"
      assert upload.url =~ "x-amz-meta-sha256"
    end

    test "multipart part presigns bind upload id, part number, size, and checksum" do
      checksum = String.duplicate("b", 64)

      assert {:ok, part} =
               Presigner.presign_upload_part(@owner_key, "provider-upload", 2,
                 content_length: 5 * 1024 * 1024,
                 checksum_sha256: checksum
               )

      assert part.url =~ "partNumber=2"
      assert part.url =~ "uploadId=provider-upload"
      assert part.headers["content-length"] == to_string(5 * 1024 * 1024)
      assert part.headers["x-amz-checksum-sha256"]
      refute Map.has_key?(part.headers, "x-amz-meta-sha256")
    end

    test "a negative or zero content length is rejected" do
      assert {:error, :invalid_content_length} =
               Presigner.presign_upload(@owner_key, content_length: 0)

      assert {:error, :invalid_content_length} =
               Presigner.presign_upload(@owner_key, content_length: -5)
    end
  end
end
