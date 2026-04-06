# defimpl Jason.Encoder, for: Thaqqa.Data do
#  def encode(data, opts), do: Jason.Encode.map(data.value_list, opts)
# end

defmodule Thaqqa.Data do
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  defstruct [:value_list]

  def new(v) when is_map(v), do: %__MODULE__{value_list: v}

  def new(v, %DataTable{} = table) when is_map(v),
    do: %__MODULE__{value_list: v |> modify_value_map(table) |> attach_id(table)}

  def new(v, %DataTable{} = table, %Prefab{} = prefab) when is_map(v),
    do: %__MODULE__{
      value_list:
        v |> modify_value_map(table) |> attach_id(table) |> set_precompile(table, prefab)
    }

  def attach_id(value_map, %DataTable{} = table) when is_map(value_map) do
    if Map.has_key?(value_map, @id) and Map.get(value_map, @id) != nil,
      do: value_map,
      else: Map.put(value_map, @id, DataTable.get_least_available_id(table))
  end

  def modify_value_map(value_map, %DataTable{} = table) when is_map(value_map) do
    Enum.reduce(table.column_list, value_map, fn %Column{name: name} = column, acc ->
      if Map.has_key?(acc, name),
        do: acc,
        else: Map.put(acc, name, Column.init_value(column, nil))
    end)
  end

  def set_value(%__MODULE__{value_list: v} = data, key, val),
    do: %{data | value_list: Map.put(v, key, val)}

  def get_value(%__MODULE__{value_list: v}, key), do: Map.get(v, key)

  def get_value_or_error(%__MODULE__{value_list: v}, key) do
    case Map.get(v, key) do
      nil -> Error.data_not_found(nil, key, nil, nil)
      otherwise -> {:ok, otherwise}
    end
  end

  def delete_value(%__MODULE__{value_list: v} = data, key),
    do: %__MODULE__{data | value_list: Map.delete(v, key)}

  def edit_value(%__MODULE__{value_list: v}, nv) when is_map(nv),
    do: %__MODULE__{value_list: Map.merge(v, nv)}

  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "none"} = _table,
        %Prefab{} = _prefab
      ),
      do: {:ok, self}

  # TODO:translate層にてletter_numberからのキャプチャグループ反映＋音節間のStyle()挿入後、
  # NameAltにも設定する機能をつける
  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "regex_0"} = datatable,
        %Prefab{} = prefab
      ) do
    name = get_value(self, @name)

    if name != nil do
      case Regex_Khhyl.compile(name, prefab) do
        {:error, _} = err -> err
        {:ok, val} -> {:ok, set_value(self, @precompile, val)}
      end
    else
      Error.data_not_found(@name, name, datatable, nil)
    end
  end

  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "regex_1"} = datatable,
        %Prefab{} = prefab
      ) do
    name = get_value(self, @rawregex)

    if name != nil do
      case Regex_Khhyl.compile(name, prefab) do
        {:error, _} = err -> err
        {:ok, val} -> {:ok, set_value(self, @precompile, val)}
      end
    else
      Error.data_not_found(@name, name, datatable, nil)
    end
  end

  def set_precompile(
        %__MODULE__{} = self,
        %DataTable{compile_rule: "path_0"} = datatable,
        %Prefab{} = _prefab
      ) do
    path = get_value(self, @path)

    if path != nil do
      case SVG.Path.parse_string(path) do
        {:error, _} = err -> err
        {:ok, val} -> {:ok, set_value(self, @precompile, val)}
      end
    else
      Error.data_not_found(@path, path, datatable, nil)
    end
  end
end
