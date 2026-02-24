defmodule Thaqqa.Data do
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  defstruct [:value_list]

  def new(v) when is_map(v), do: %__MODULE__{value_list: v}

  def set_val(%__MODULE__{value_list: v} = data, key, val),
    do: %{data | value_list: Map.put(v, key, val)}

  def get_val(%__MODULE__{value_list: v}, key), do: Map.get(v, key)

  def delete_val(%__MODULE__{value_list: v} = data, key),
    do: %__MODULE__{data | value_list: Map.delete(v, key)}

  def edit_val(%__MODULE__{value_list: v}, nv) when is_map(nv),
    do: %__MODULE__{value_list: Map.merge(v, nv)}

  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "none"} = _table,
        %Prefab{} = _prefab
      ),
      do: {:ok, self}

  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "regex_0"},
        %Prefab{} = prefab
      ) do
    name = get_val(self, @name)

    if name != nil do
      case Regex_Khhyl.compile(name, prefab) do
        {:error, msg} -> {:error, msg}
        {:ok, val} -> {:ok, set_val(self, @precompile, val)}
      end
    else
      {:error, "name_not_found"}
    end
  end

  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "path_0"},
        %Prefab{} = _prefab
      ) do
    path = get_val(self, @path)

    if path != nil do
      case SVG.Path.parse_string(path) do
        {:error, msg} -> {:error, msg}
        {:ok, val} -> {:ok, set_val(self, @precompile, val)}
      end
    else
      {:error, "path_not_found"}
    end
  end
end
