defmodule PoolToy.Application do
  use Application

  def start(_type, _args) do
    children = [
      {PoolToy.PoolSup, [size: 3]}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
