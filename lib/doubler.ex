defmodule Doubler do
  use GenServer

  def start_link([] = args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  defdelegate stop(pid), to: GenServer

  def compute(pid, n) when is_pid(pid) and is_integer(n) do
    GenServer.call(pid, {:compute, n})
  end

  def init([]) do
    {:ok, nil}
  end

  def handle_call({:compute, n}, _from, state) do
    IO.puts("Doubling #{n}")
    :timer.sleep(500)
    {:reply, 2 * n, state}
  end
end
