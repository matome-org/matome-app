defmodule MatomeApiWeb.ChangesetErrorsTest do
  @moduledoc """
  okt-audit AUDIT-CORE (task #1865): `errors_on/1` used to be duplicated,
  byte-identical, as a private function in both `AuthController` and
  `KeyBundleController`. This module is the hoisted single copy both now
  call.
  """
  use ExUnit.Case, async: true

  alias MatomeApi.Auth.User
  alias MatomeApiWeb.ChangesetErrors

  test "flattens changeset errors into a map of interpolated messages" do
    changeset =
      User.registration_changeset(%User{}, %{"email" => "not-an-email", "password" => "short"})

    errors = ChangesetErrors.errors_on(changeset)

    assert errors.email == ["has invalid format"]
    assert errors.password == ["should be at least 8 character(s)"]
  end

  test "an empty map for a valid changeset" do
    changeset =
      User.registration_changeset(%User{}, %{
        "email" => "valid@example.com",
        "password" => "a long enough password"
      })

    assert ChangesetErrors.errors_on(changeset) == %{}
  end
end
