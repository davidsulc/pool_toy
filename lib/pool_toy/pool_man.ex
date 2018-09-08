defmodule PoolToy.PoolMan do
  use GenServer

  defmodule State do
    defstruct [
      :name, :size, :worker_spec, :pool_sup,
      :monitors, :worker_sup,
      workers: []
    ]
  end

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def checkout(pool) do
    GenServer.call(pool, :checkout)
  end

  def checkin(pool, worker) do
    GenServer.cast(pool, {:checkin, worker})
  end

  def init(args), do: init(args, %State{})

  defp init([{:name, name} | rest], %State{} = state) when is_atom(name) do
    init(rest, %{state | name: name})
  end

  defp init([{:name, _name} | _], _state) do
    {:stop, {:invalid_args, {:name, "must be an atom"}}}
  end

  defp init([{:size, size} | rest], %State{} = state) when is_integer(size) and size > 0 do
    init(rest, %{state | size: size})
  end

  defp init([{:size, _size} | _], _state) do
    {:stop, {:invalid_args, {:size, "must be a positive integer"}}}
  end

  defp init([{:pool_sup, pid} | rest], %State{} = state) when is_pid(pid) do
    init(rest, %{state | pool_sup: pid})
  end

  defp init([{:worker_spec, spec} | rest], %State{} = state) do
    init(rest, %{state | worker_spec: spec})
  end

  defp init([{:pool_sup, _} | _], _state) do
    {:stop, {:invalid_args, {:pool_sup, "must be provided"}}}
  end

  defp init([], %State{name: nil}) do
    {:stop, {:missing_args, {:name, "atom `name` is required"}}}
  end

  defp init([], %State{size: nil}) do
    {:stop, {:missing_args, {:size, "positive integer `size` is required"}}}
  end

  defp init([], %State{worker_spec: nil}) do
    {:stop, {:missing_args, {:worker_spec, "child spec `worker_spec` is required"}}}
  end

  defp init([], %State{name: _, size: _} = state) do
    Process.flag(:trap_exit, true)
    send(self(), :start_worker_sup)
    monitors = :ets.new(:monitors, [:protected, :named_table])
    {:ok, %{state | monitors: monitors}}
  end

  defp init([_ | t], state), do: init(t, state)

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

  def handle_info(:start_worker_sup, %State{pool_sup: sup} = state) do
    {:ok, worker_sup} = Supervisor.start_child(sup, PoolToy.WorkerSup)
    Process.link(worker_sup)

    state =
      state
      |> Map.put(:worker_sup, worker_sup)
      |> start_workers()

    {:noreply, state}
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

  def handle_info({:EXIT, pid, reason}, %State{worker_sup: pid} = state) do
    {:stop, {:worker_sup_exit, reason}, state}
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

  def start_workers(%State{worker_sup: sup, worker_spec: spec, size: size} = state) do
    workers =
      for _ <- 1..size do
        new_worker(sup, spec)
      end

    %{state | workers: workers}
  end

  defp new_worker(sup, spec) do
    child_spec = Supervisor.child_spec(spec, restart: :temporary)
    {:ok, pid} = PoolToy.WorkerSup.start_worker(sup, child_spec)
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
