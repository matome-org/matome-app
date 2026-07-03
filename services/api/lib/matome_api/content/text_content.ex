defmodule MatomeApi.Content.TextContent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "text_contents" do
    field :body, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(text_content, attrs) do
    text_content
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
