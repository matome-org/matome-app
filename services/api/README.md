# MatomeApi

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:7001`](http://localhost:7001) from your browser.

## macOS Hex/Rebar Bootstrap

The project currently pins Erlang/OTP 27.2. On some macOS machines,
`mix local.hex` or `mix local.rebar` can fail TLS validation against
`builds.hex.pm` with an `unsupported_certificate` / `key_usage_mismatch` error.
Do not disable TLS verification. Install Hex from GitHub and use Homebrew's
Rebar instead:

```bash
mix archive.install github hexpm/hex branch latest
brew install rebar3
```

After that, normal dependency and test commands should work:

```bash
mix deps.get
mix test
```

## Processing Observation

Authenticated clients request processing with `POST /api/items/:id/process`.
Core returns the explicit current run id, attempt, requested output kinds, and
state. Flutter observes only that run through bounded owner-scoped
`GET /api/items/:id` polling with one request in flight. A client observation
timeout stops polling but does not fail the Core run; Core's watchdog owns the
authoritative timeout transition.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
