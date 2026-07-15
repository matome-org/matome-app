defmodule MatomeApi.Storage.UploadPolicyTest do
  use ExUnit.Case, async: true

  alias MatomeApi.Storage.UploadPolicy

  test "large audio uses multipart without losing media and provider bounds" do
    assert UploadPolicy.mode_for("audio", 25 * 1024 * 1024) == :single
    assert UploadPolicy.mode_for("audio", 25 * 1024 * 1024 + 1) == :multipart
    assert :ok = UploadPolicy.validate_size("audio", 30 * 1024 * 1024)

    assert {:error, :media_too_large} =
             UploadPolicy.validate_size("image", 50 * 1024 * 1024 + 1)

    assert {:error, :provider_limit_exceeded} =
             UploadPolicy.validate_size("audio", UploadPolicy.provider_max_bytes() + 1)
  end

  test "multipart geometry stays within S3 part bounds" do
    size = 30 * 1024 * 1024

    assert UploadPolicy.multipart_part_bytes() == 16 * 1024 * 1024
    assert UploadPolicy.part_count(size) == 2
    assert UploadPolicy.part_byte_size(size, 1) == 16 * 1024 * 1024
    assert UploadPolicy.part_byte_size(size, 2) == 14 * 1024 * 1024
    assert {:error, :invalid_part_number} = UploadPolicy.part_byte_size(size, 3)
  end
end
