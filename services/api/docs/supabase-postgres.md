# Supabase Postgres Connection

The Core API uses Ecto against the existing Supabase-managed Postgres database.
It does not use Supabase Auth or row-level security for backend authorization.

## Environment

Set `DATABASE_URL` to the Supabase Postgres connection string before running the
API, migrations, or Oban workers:

```sh
DATABASE_URL="postgres://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres"
DATABASE_SSL=true
GUARDIAN_SECRET_KEY="<long random JWT signing secret>"
POOL_SIZE=5
```

Use Supabase's transaction-pooling pgbouncer endpoint for application traffic.
Keep `POOL_SIZE` conservative because each Phoenix node and Oban queue consumes
database connections from the same Supabase pool. For one-off migrations, use the
direct Supabase Postgres URL if Supabase's pooler rejects migration DDL.

## Commands

Run from `services/api`:

```sh
mix ecto.migrate
mix phx.server
```

`mix ecto.migrate` installs the Oban jobs table. Oban uses the same `MatomeApi.Repo`
and Supabase Postgres connection as the API.

Auth is owned by Phoenix, not Supabase Auth. Email/password users are stored in
the `users` table with argon2 password hashes, and refresh JWT rotation is backed
by the `refresh_tokens` table.
