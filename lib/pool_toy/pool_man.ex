defmodule PoolToy.PoolMan do
  use GenServer

  defmodule State do
    defstruct [:size, workers: []]
  end

  @name __MODULE__

  def start_link(size) when is_integer(size) and size > 0 do
    GenServer.start_link(__MODULE__, size, name: @name)
  end

  def init(size) do
    start_worker = fn _ ->
      {:ok, pid} = DynamicSupervisor.start_child(PoolToy.WorkerSup, Doubler)
      pid
    end

    workers = 1..size |> Enum.map(start_worker)

    {:ok, %State{size: size, workers: workers}}
  end
end
