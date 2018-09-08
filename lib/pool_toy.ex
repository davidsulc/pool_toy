defmodule PoolToy do
  defdelegate start_pool(args), to: PoolToy.PoolsSup
  defdelegate stop_pool(pool_name), to: PoolToy.PoolsSup
  defdelegate checkout(pool), to: PoolToy.PoolMan
  defdelegate checkin(pool, worker), to: PoolToy.PoolMan
end
