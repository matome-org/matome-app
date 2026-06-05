# MatomeApi

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Recording Status Channel

Authenticated clients connect to `/socket/websocket` with their access token in
the socket params:

```js
const socket = new Socket("/socket", { params: { token: accessToken } });
socket.connect();

const channel = socket.channel(`user:${userId}`);
channel.join();

channel.on("recording:status", (message) => {
  // message shape below
});
```

Only the authenticated user may join `user:<userId>`. Recording status updates
emit only to the recording owner's topic with this payload:

```json
{
  "recording_id": 123,
  "status": "processing",
  "summary": null,
  "transcript": null,
  "error_reason": null,
  "duration": null,
  "badge": null,
  "updated_at": "2026-06-04T12:00:00Z"
}
```

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
