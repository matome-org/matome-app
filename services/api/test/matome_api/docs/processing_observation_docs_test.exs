defmodule MatomeApi.Docs.ProcessingObservationDocsTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../../..", __DIR__)

  test "processing docs describe current-run REST polling, not a status channel" do
    api_readme = File.read!(Path.join(@repo_root, "services/api/README.md"))
    requirements = File.read!(Path.join(@repo_root, ".docs/internal/requirements.md"))

    refute api_readme =~ "Recording Status Channel"
    refute api_readme =~ "recording:status"
    refute requirements =~ "socket + poll for the terminal result"

    assert api_readme =~ "GET /api/items/:id"
    assert requirements =~ "current run"
    assert requirements =~ "bounded"
  end
end
