defmodule MatomeApiWeb.StorybookTest do
  @moduledoc """
  Drift guard for the design-system catalog (plan p2-core-backoffice, Phase A).

  phoenix_storybook's `StoryLive` is a LiveView, so a full render test needs
  `lazy_html` (a C-NIF not in this wave's offline Hex cache — the same
  constraint that made W0 assert /admin via dead-render). Until that lands, this
  asserts the catalog's *structure* instead of its pixels:

    * every base/composite component in `MatomeComponents`/`MatomeComposites`
      has a matching `.story.exs` leaf (add a component -> this fails until you
      add its story), and
    * every story leaf targets a function that still exists (rename a component
      -> this fails), plus the fixed foundations pages are present.

  Visual parity vs the Flutter widgetbook stays a manual eyeball at /storybook.
  """
  use ExUnit.Case, async: true

  alias MatomeApiWeb.{MatomeComponents, MatomeComposites}

  # The catalog contract. Kept explicit (not only derived) so a reviewer can see
  # exactly what the storybook is expected to cover at a glance.
  @foundations ~w(colors typography spacing radius)

  # Composite helpers that are NOT standalone catalog leaves: sub-components
  # rendered *inside* their parent composite's story (via `def imports`), plus
  # `default_row_id/1` which is a plain row->id function, not a component. They
  # are exercised through their parents, so they get no top-level story.
  @composite_non_leaves ~w(table_primary_cell table_count place_chip meta_token
                           info_row default_row_id)a

  defp leaf_paths do
    MatomeApiWeb.Storybook.leaves() |> Enum.map(& &1.path) |> MapSet.new()
  end

  # Public arity-1 functions of a component module = its function components.
  # Phoenix.Component only injects arity-0 internals (e.g. `__components__/0`),
  # so filtering to arity 1 and dropping `__*` names yields exactly the catalog.
  defp component_functions(module) do
    module.__info__(:functions)
    |> Enum.filter(fn {name, arity} ->
      arity == 1 and not String.starts_with?(Atom.to_string(name), "__")
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  test "every base component has a story (completeness — add a component, add a story)" do
    paths = leaf_paths()

    for fun <- component_functions(MatomeComponents) do
      assert MapSet.member?(paths, "/components/#{fun}"),
             "MatomeComponents.#{fun}/1 has no /components/#{fun} story"
    end
  end

  test "every composite component has a story" do
    paths = leaf_paths()

    for fun <- component_functions(MatomeComposites), fun not in @composite_non_leaves do
      assert MapSet.member?(paths, "/composites/#{fun}"),
             "MatomeComposites.#{fun}/1 has no /composites/#{fun} story"
    end
  end

  test "foundations token pages are present" do
    paths = leaf_paths()

    for page <- @foundations do
      assert MapSet.member?(paths, "/foundations/#{page}"),
             "missing /foundations/#{page} token page"
    end
  end

  test "every component/composite story targets an exported function/1 (no dangling stories)" do
    # `function_exported?/3` never loads the module — on a lazily-loaded
    # test node this test only passed when an earlier (seed-ordered) test
    # happened to load the component modules first. Load them explicitly.
    Code.ensure_loaded!(MatomeComponents)
    Code.ensure_loaded!(MatomeComposites)

    for %{path: path} <- MatomeApiWeb.Storybook.leaves() do
      case String.split(path, "/", trim: true) do
        ["components", fun] ->
          assert function_exported?(MatomeComponents, String.to_atom(fun), 1),
                 "story #{path} targets missing MatomeComponents.#{fun}/1"

        ["composites", fun] ->
          assert function_exported?(MatomeComposites, String.to_atom(fun), 1),
                 "story #{path} targets missing MatomeComposites.#{fun}/1"

        ["foundations", _page] ->
          :ok

        _ ->
          flunk("unexpected story leaf outside the catalog folders: #{path}")
      end
    end
  end
end
