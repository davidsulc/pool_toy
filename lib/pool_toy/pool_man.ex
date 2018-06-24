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
    send(self(), :start_workers)
    {:ok, %State{size: size}}
  end

  def handle_info(:start_workers, %State{size: size} = state) do
    workers =
      for _ <- 1..size do
        {:ok, pid} = PoolToy.WorkerSup.start_worker(PoolToy.WorkerSup, Doubler)
        pid
      end

    {:noreply, %{state | workers: workers}}
  end

  def handle_info(msg, state) do
    IO.puts("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
