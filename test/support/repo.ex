defmodule Projectionist.Repo do
  use Ecto.Repo,
    otp_app: :projectionist,
    adapter: Ecto.Adapters.Postgres
end
