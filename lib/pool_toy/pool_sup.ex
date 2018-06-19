defmodule PoolToy.PoolSup do
  use Supervisor

  @name __MODULE__

  def start_link(args) when is_list(args) do
    Supervisor.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    pool_size = args |> Keyword.fetch!(:size)

    children = [
      PoolToy.WorkerSup,
      {PoolToy.PoolMan, pool_size}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
