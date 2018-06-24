defmodule PoolToy.WorkerSup do
  use DynamicSupervisor

  @name __MODULE__

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: @name)
  end

  defdelegate start_worker(sup, spec), to: DynamicSupervisor, as: :start_child

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
