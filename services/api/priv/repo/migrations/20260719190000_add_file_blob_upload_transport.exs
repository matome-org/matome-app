defmodule MatomeApi.Repo.Migrations.AddFileBlobUploadTransport do
  use Ecto.Migration

  def change do
    alter table(:file_blobs) do
      add :upload_transport, :string, null: false, default: "direct_signed_length"
    end

    create constraint(:file_blobs, :file_blobs_upload_transport_check,
             check: "upload_transport IN ('direct_signed_length', 'browser_stream')"
           )
  end
end
