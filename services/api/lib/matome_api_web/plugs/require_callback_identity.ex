defmodule MatomeApiWeb.Plugs.RequireCallbackIdentity do
  import Phoenix.Controller
  import Plug.Conn

  alias MatomeApi.AIEngine

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> identity] <- get_req_header(conn, "authorization"),
         job_id when is_binary(job_id) <- conn.path_params["id"],
         run_id when is_binary(run_id) <- conn.params["run_id"],
         input_revision when is_integer(input_revision) <- conn.params["input_revision"],
         true <- AIEngine.valid_callback_identity?(identity, job_id, run_id, input_revision) do
      conn
    else
      _invalid ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
