defmodule PoolToy.PoolMan do
  use GenServer

  defmodule State do
    defstruct [
      :size, :monitors,
      worker_sup: PoolToy.WorkerSup, worker_spec: Doubler, workers: []
    ]
  end

  @name __MODULE__

  def start_link(size) when is_integer(size) and size > 0 do
    GenServer.start_link(__MODULE__, size, name: @name)
  end

  def checkout() do
    GenServer.call(@name, :checkout)
  end

  def checkin(worker) do
    GenServer.cast(@name, {:checkin, worker})
  end

  def init(size) do
    Process.flag(:trap_exit, true)
    send(self(), :start_workers)
    monitors = :ets.new(:monitors, [:protected, :named_table])
    {:ok, %State{size: size, monitors: monitors}}
  end

  def handle_call(:checkout, _from, %State{workers: []} = state) do
    {:reply, :full, state}
  end

  def handle_call(:checkout, {from, _}, %State{workers: [worker | rest]} = state) do
    %State{monitors: monitors} = state
    monitor(monitors, {worker, from})
    {:reply, worker, %{state | workers: rest}}
  end

  def handle_cast({:checkin, worker}, %State{monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, state |> handle_idle_worker(pid)}
      [] ->
        {:noreply, state}
    end
  end

  def handle_info(:start_workers, %State{worker_sup: sup, worker_spec: spec, size: size} = state) do
    workers =
      for _ <- 1..size do
        new_worker(sup, spec)
      end

    {:noreply, %{state | workers: workers}}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %State{monitors: monitors} = state) do
    case :ets.match(monitors, {:"$0", ref}) do
      [[pid]] ->
        true = :ets.delete(monitors, pid)
        {:noreply, state |> handle_idle_worker(pid)}
      [] ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, pid, _reason}, %State{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, state |> handle_worker_exit(pid)}
      [] ->
        if workers |> Enum.member?(pid) do
          {:noreply, state |> handle_worker_exit(pid)}
        else
          {:noreply, state}
        end
    end
  end

  def handle_info(msg, state) do
    IO.puts("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp new_worker(sup, spec) do
    {:ok, pid} = PoolToy.WorkerSup.start_worker(sup, spec)
    true = Process.link(pid)
    pid
  end

  defp monitor(monitors, {worker, client}) do
    ref = Process.monitor(client)
    :ets.insert(monitors, {worker, ref})
    ref
  end

  defp handle_idle_worker(%State{workers: workers} = state, idle_worker) when is_pid(idle_worker) do
    %{state | workers: [idle_worker | workers]}
  end

  defp handle_worker_exit(%State{workers: workers, worker_sup: sup, worker_spec: spec} = state, pid) do
    w = workers |> Enum.reject(& &1 == pid)
    %{state | workers: [new_worker(sup, spec) | w]}
  end
end
