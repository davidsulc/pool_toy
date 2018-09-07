defmodule PoolToy.PoolsSup do
  use DynamicSupervisor

  @name __MODULE__

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: @name)
  end

  def start_pool(args) do
    DynamicSupervisor.start_child(@name, {PoolToy.PoolSup, args})
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
