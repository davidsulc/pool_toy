defmodule PoolToy.PoolSup do
  use Supervisor

  @name __MODULE__

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init([]) do
    children = []

    Supervisor.init(children, strategy: :one_for_all)
  end
end
