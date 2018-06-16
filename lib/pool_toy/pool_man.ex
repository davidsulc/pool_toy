defmodule PoolToy.PoolMan do
  use GenServer

  @name __MODULE__

  def start_link(size) when is_integer(size) and size > 0 do
    GenServer.start_link(__MODULE__, size, name: @name)
  end

  def init(size) do
    state = List.duplicate(:worker, size)
    {:ok, state}
  end
end
