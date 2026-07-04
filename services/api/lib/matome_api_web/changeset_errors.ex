defmodule MatomeApiWeb.ChangesetErrors do
  @moduledoc """
  Shared changeset-error formatter for controllers that render a 422 as
  `%{errors: ...}`.

  Hoisted out of `MatomeApiWeb.AuthController` and
  `MatomeApiWeb.KeyBundleController` (okt-audit AUDIT-CORE, task #1865),
  which each carried a byte-identical private `errors_on/1`.
  """

  @doc "Flattens an `Ecto.Changeset`'s errors into a map of interpolated messages."
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
