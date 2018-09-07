defmodule PoolToy do
  defdelegate start_pool(args), to: PoolToy.PoolsSup
end
