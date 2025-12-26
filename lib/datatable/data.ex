defmodule Thaqqa.Data do
  defstruct [:value_list]

  def set_val(%__MODULE__{value_list: v} = data, key, val),
    do: %{data | value_list: Map.put(v, key, val)}

  def get_val(%__MODULE__{value_list: v}, key), do: Map.get(v, key)
end
