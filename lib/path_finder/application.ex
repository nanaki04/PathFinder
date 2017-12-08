defmodule PathFinder.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Application.get_env(:path_finder, :is_destination)
    |> setup_destination
  end

  defp setup_destination(false), do: :ok
  defp setup_destination(_) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: PathFinder.Worker.start_link(arg1, arg2, arg3)
      # worker(PathFinder.Worker, [arg1, arg2, arg3]),
      supervisor(Task.Supervisor, [[name: PathFinder.Destination]], restart: :permanent)
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PathFinder.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
