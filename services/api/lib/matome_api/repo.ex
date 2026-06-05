defmodule MatomeApi.Repo do
  use Ecto.Repo,
    otp_app: :matome_api,
    adapter: Ecto.Adapters.Postgres
end
