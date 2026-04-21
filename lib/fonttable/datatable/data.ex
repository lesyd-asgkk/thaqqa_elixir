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

  # データを作成する関数。 返り値は%Data{}
  def new(v) when is_map(v), do: %__MODULE__{value_list: v}

  # DataTableを第2引数として渡した場合は「そのテーブルの要求項目に沿うように加工する」。
  def new(v, %DataTable{} = table) when is_map(v),
    do: %__MODULE__{value_list: v |> modify_value_map(table) |> attach_id(table)}

  # さらにFontRegistryPrefabを第3引数として渡した場合はVolatility column用のprecompileも済ませる。
  def new(v, %DataTable{} = table, %Prefab{} = prefab) when is_map(v),
    do: %__MODULE__{
      value_list:
        v |> modify_value_map(table) |> attach_id(table) |> set_precompile(table, prefab)
    }

  # value_mapに、DataTableのdata_list上で使用されていない最小のIDを付加する。
  # 返り値はmap。
  # ※一意性を鑑みるならば最大のIDを付加する方式にしてもよい。変更コストが著しく小さいため保留としている。
  def attach_id(value_map, %DataTable{} = table) when is_map(value_map) do
    if Map.has_key?(value_map, @id) and Map.get(value_map, @id) != nil,
      do: value_map,
      else: Map.put(value_map, @id, DataTable.get_least_available_id(table))
  end

  # 第二引数として渡したDataTableの要求項目に沿うように加工。
  # 返り値はmap。
  def modify_value_map(value_map, %DataTable{} = table) when is_map(value_map) do
    Enum.reduce(table.column_list, value_map, fn %Column{name: name} = column, acc ->
      if Map.has_key?(acc, name),
        do: acc,
        else: Map.put(acc, name, Column.init_value(column, nil))
    end)
  end

  # value_listに新たな値を設定した上で%Data{}の形で返す。
  # 以降の関数ではColumnとの型整合を担保することはない。
  def set_value(%__MODULE__{value_list: v} = data, key, val),
    do: %{data | value_list: Map.put(v, key, val)}

  # value_listに新たな値を追加した上で%Data{}の形で返す。
  # set_value/3とは違い、既に存在するkeyの場合は値を変更しない。
  def add_value(%__MODULE__{value_list: v} = data, key, val),
    do: %{data | value_list: Map.put_new(v, key, val)}

  # value_listから指定したkeyに対する値を取得する。
  # ないkeyを参照した場合はnilを返す。
  def get_value(%__MODULE__{value_list: v}, key), do: Map.get(v, key)

  # value_listから指定したkeyに対する値を取得し、{:ok,%Data{}}の形で返す。
  # ないkeyを参照した場合は{:error,%Error{}}の形式。
  def get_value_or_error(%__MODULE__{value_list: v}, key) do
    case Map.get(v, key) do
      nil -> Error.data_not_found(nil, key, nil, nil)
      otherwise -> {:ok, otherwise}
    end
  end

  # value_listから指定したkeyに対する値を削除し、%Data{}の形で返す。
  # 無いkeyを指定した場合は変更なし。
  def delete_value(%__MODULE__{value_list: v} = data, key),
    do: %__MODULE__{data | value_list: Map.delete(v, key)}

  # value_listから指定したkeyに対する値を削除し、、{:ok,%Data{}}の形で返す。
  # ないkeyを参照した場合は{:error,%Error{}}の形式。
  def delete_value_or_error(%__MODULE__{} = data, key) do
    if get_value(data, key) != nil,
      do: {:ok, delete_value(data, key)},
      else: Error.data_not_found(nil, key, nil, nil)
  end

  # value_listから指定したkeyに対する値を変更し、%Data{}の形で返す。
  # ないkeyを参照した場合は変更なし。
  def edit_value(%__MODULE__{value_list: v} = data, key, new_value) do
    if get_value(data, key) != nil,
      do: %__MODULE__{data | value_list: Map.put(v, key, new_value)},
      else: data
  end

  # value_listから指定したkeyに対する値を変更し、{:ok,%Data{}}の形で返す。
  # ないkeyを参照した場合は{:error,%Error{}}の形式。
  def edit_value_or_error(%__MODULE__{} = data, key, new_value) do
    if get_value(data, key) != nil,
      do: {:ok, edit_value(data, key, new_value)},
      else: Error.data_not_found(nil, key, nil, nil)
  end

  # Regex_khhylやpathのdを表すstringといったものをprecompileしたDataを{:ok,%Data{}}の形で返す関数。
  # 処理についてはDataの属するDataTableのcompile_ruleに依存する関数。
  # 参照ColumnがDataTableのcolumn_listから欠けていた場合は{:error,%Error{}}の形式でエラーを吐く。
  def set_precompile(%__MODULE__{} = self, %DataTable{compile_rule: "none"}, %Prefab{}),
    do: {:ok, self}

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
