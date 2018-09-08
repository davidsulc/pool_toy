defmodule PoolToy.PoolsSup do
  use DynamicSupervisor

  @name __MODULE__

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: @name)
  end

  def start_pool(args) do
    case DynamicSupervisor.start_child(@name, {PoolToy.PoolSup, args}) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  def stop_pool(pool_name) when is_atom(pool_name) do
    [{_, pool_sup}] = Registry.lookup(PoolToy.Registry, pool_name)
    DynamicSupervisor.terminate_child(@name, pool_sup)
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
