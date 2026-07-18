defmodule MatomeApi.Content.DocumentOpenPolicyTest do
  use ExUnit.Case, async: true

  alias MatomeApi.Content.DocumentOpenPolicy

  test "sanitizes path and header injection while preserving a bounded original name" do
    assert DocumentOpenPolicy.metadata("../private/Q3\r\nreport.PDF", "application/pdf") ==
             {:ok,
              %{
                filename: "Q3__report.PDF",
                original_extension: "pdf",
                content_type: "application/pdf",
                open_policy: "external"
              }}
  end

  test "classifies approved external, system-app, active, and unknown documents" do
    assert {:ok, %{open_policy: "external"}} =
             DocumentOpenPolicy.metadata("notes.txt", "text/plain; charset=utf-8")

    assert {:ok, %{open_policy: "system_app"}} =
             DocumentOpenPolicy.metadata(
               "budget.xlsx",
               "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
             )

    assert {:ok, %{open_policy: "attachment_only"}} =
             DocumentOpenPolicy.metadata("diagram.svg", "image/svg+xml")

    assert {:ok, %{open_policy: "download_only"}} =
             DocumentOpenPolicy.metadata("archive.xyz", "application/octet-stream")
  end

  test "MIME mismatch can only reduce trust" do
    assert {:ok, %{open_policy: "download_only"}} =
             DocumentOpenPolicy.metadata("report.pdf", "text/plain")

    assert {:ok, %{open_policy: "attachment_only"}} =
             DocumentOpenPolicy.metadata("report.pdf", "text/html")

    assert {:ok, %{content_type: "application/octet-stream", open_policy: "download_only"}} =
             DocumentOpenPolicy.metadata("report.pdf", "application/pdf\r\nx-injected: yes")
  end

  test "rejects executable and script extensions or MIME types" do
    assert {:error, :unsafe_file_type} =
             DocumentOpenPolicy.metadata("meeting-notes.sh", "text/plain")

    assert {:error, :unsafe_file_type} =
             DocumentOpenPolicy.metadata("meeting-notes.txt", "application/x-sh")

    assert {:error, :unsafe_file_type} =
             DocumentOpenPolicy.metadata("invoice.pdf.desktop. ", "application/pdf")

    assert {:error, :unsafe_file_type} =
             DocumentOpenPolicy.metadata(".command", "text/plain")

    assert {:error, :unsafe_file_type} =
             DocumentOpenPolicy.metadata("module.txt", "application/wasm")
  end

  test "normalizes absent and parameterized document metadata deterministically" do
    assert DocumentOpenPolicy.metadata(nil, nil) ==
             {:ok,
              %{
                filename: "download",
                original_extension: nil,
                content_type: "application/octet-stream",
                open_policy: "download_only"
              }}

    assert {:ok, metadata} =
             DocumentOpenPolicy.metadata(" report.PDF. ", " Application/PDF ; charset=binary ")

    assert metadata.filename == "report.PDF"
    assert metadata.original_extension == "pdf"
    assert metadata.content_type == "application/pdf"
  end

  test "verifies only bounded launch-capable content signatures" do
    cfb = <<0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1>>

    for {filename, content_type, prefix} <- [
          {"report.pdf", "application/pdf", "%PDF-1.7\n"},
          {"notes.txt", "text/plain", "plain UTF-8 text\n"},
          {"memo.rtf", "application/rtf", "{\\rtf1\\ansi memo"},
          {"legacy.doc", "application/msword", cfb},
          {"modern.docx",
           "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
           "PK\x03\x04"},
          {"sheet.ods", "application/vnd.oasis.opendocument.spreadsheet", "PK\x05\x06"}
        ] do
      assert {:ok, metadata} = DocumentOpenPolicy.metadata(filename, content_type)
      assert DocumentOpenPolicy.verify_signature(metadata, prefix) == metadata.open_policy

      assert DocumentOpenPolicy.verify_signature(metadata, "not the claimed format\x00") ==
               "download_only"
    end

    assert {:ok, active} = DocumentOpenPolicy.metadata("page.html", "text/html")
    assert DocumentOpenPolicy.verify_signature(active, "harmless text") == "attachment_only"

    assert {:ok, text} = DocumentOpenPolicy.metadata("page.txt", "text/plain")

    assert DocumentOpenPolicy.verify_signature(text, "<html><script>run()</script>") ==
             "attachment_only"
  end

  test "builds safe signed response overrides without reflecting raw input" do
    metadata = %{
      filename: "Q3__report.PDF",
      original_extension: "pdf",
      content_type: "application/pdf",
      open_policy: "external"
    }

    assert {:ok, descriptor} = DocumentOpenPolicy.download_descriptor(metadata)
    assert descriptor.action == "open"
    assert descriptor.content_type == "application/pdf"
    assert descriptor.content_disposition =~ ~s(inline; filename="Q3__report.PDF")
    assert descriptor.cache_control == "private, no-store, max-age=0"
    refute descriptor.content_disposition =~ "\r"
    refute descriptor.content_disposition =~ "\n"
  end
end
