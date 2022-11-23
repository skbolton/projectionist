import Config

config :projectionist, Projectionist.Repo,
  database: "projectionist_testing",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :projectionist, ecto_repos: [Projectionist.Repo]
