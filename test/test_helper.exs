ExUnit.start()

{:ok, _pid} = Ecto.Adapters.Postgres.ensure_all_started(Projectionist.Repo, :temporary)
Mix.Task.run("ecto.drop")
Mix.Task.run("ecto.create")
{:ok, _pid} = Projectionist.Repo.start_link()
