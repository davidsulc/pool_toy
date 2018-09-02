defmodule PoolToy.PoolSup do
  use Supervisor

  def start_link(args) when is_list(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(args) do
    children = [
      {PoolToy.PoolMan, [{:pool_sup, self()} | args]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
