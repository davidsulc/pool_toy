defmodule PoolToy.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, [keys: :unique, name: PoolToy.Registry]},
      PoolToy.PoolsSup
    ]

    opts = [strategy: :rest_for_one]
    Supervisor.start_link(children, opts)
  end
end
