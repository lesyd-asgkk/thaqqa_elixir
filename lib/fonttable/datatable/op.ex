defmodule Thaqqa.DataTable.Op do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable.DataMapValidator, as: Validator

  alias Thaqqa.FontRegistry.Error, as: Error

  use Thaqqa.DataTable.Const

  def add_column(
        %DataTable{data_list: datalist, column_list: col_list} = table,
        %Column{name: column_name, type: type} = column,
        val_init \\ nil
      ) do
    if DataTable.has_column?(table, column_name) do
      Error.nominal_conflict_column(column_name, :add)
    else
      if !Column.is_available_type(type) do
        Error.invalid_datatype(type)
      else
        val_init = Column.init_value(column, val_init)
        datalist = Enum.map(datalist, fn data -> Data.set_value(data, column_name, val_init) end)

        ans = %{table | column_list: col_list ++ [column], data_list: datalist}

        {:ok, ans}
      end
    end
  end

  # Columnを追加したDataTableを返す関数。
  # エラーを吐いた場合は即raise。
  def add_column!(%DataTable{} = table, %Column{} = column, val_init \\ nil) do
    case add_column(table, column, val_init) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  # Column情報を編集したDataTableを返す関数。削除するColumnの指定にはそのColumnのNameを使用する。
  # 返り値は{:ok,%DataTable{}}。削除すべきColumnが存在しない場合は{:error,%Error{}}。
  def delete_column(
        %DataTable{column_list: column_list, data_list: data_list, name: table_name} = table,
        column_name
      ) do
    if !DataTable.has_column?(table, column_name) do
      Error.column_not_found(table_name, column_name, :delete)
    else
      new_columnlist = Enum.filter(column_list, fn %Column{name: name} -> name != column_name end)

      new_datalist = Enum.map(data_list, fn data -> Data.delete_value(data, column_name) end)

      {:ok, %{table | column_list: new_columnlist, data_list: new_datalist}}
    end
  end

  def delete_column!(%DataTable{} = table, column_name) do
    case delete_column(table, column_name) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def edit_column(
        %DataTable{column_list: col_list} = table,
        column_name,
        %Column{name: new_name, type: type} = column
      ) do
    if DataTable.has_column?(table, column_name) and
         column_name != new_name do
      Error.nominal_conflict_column(column_name, :edit)
    else
      if !Column.is_available_type(type) do
        Error.invalid_datatype(type)
      else
        new_cols =
          Enum.map(col_list, fn
            %Column{name: ^column_name} -> column
            col -> col
          end)

        # データのキーも変更する
        new_datas =
          Enum.map(table.data_list, fn data ->
            raw_val = Data.get_value(data, column_name)
            # Columnのtype,subtypeが変わった場合の値の補正。
            val = Column.adjust_value(column, raw_val)
            data = Data.set_value(data, new_name, val)

            if new_name == column_name,
              do: %{data | value_list: data.value_list},
              else: %{data | value_list: Map.delete(data.value_list, column_name)}
          end)

        {:ok, %{table | column_list: new_cols, data_list: new_datas}}
      end
    end
  end

  def edit_column!(%DataTable{} = table, column_name, %Column{} = column) do
    case edit_column(table, column_name, column) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  # DataTableの初期化に用いる関数。
  # value_mapをDataにした上で追加する。
  def init_data(%DataTable{data_list: datas} = table, value_map)
      when is_map(value_map) do
    case Validator.validate_data(table, value_map, :add) do
      {:error, _} = err ->
        err

      :ok ->
        new_data =
          value_map
          |> DataTable.modify_value_map(table)
          |> DataTable.attach_id(table)
          |> Data.new()

        {:ok, %{table | data_list: [new_data | datas]}}
    end
  end

  def add_data!(%DataTable{} = table, %Data{} = data) do
    case add_data(table, data) do
      {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  def add_data(%DataTable{data_list: datas} = table, %Data{value_list: value_map} = data) do
    case Validator.validate_data(table, value_map, :add) do
      {:error, _} = err -> err
      :ok -> {:ok, %DataTable{table | data_list: [data | datas]}}
    end
  end

  def delete_data!(%DataTable{} = table, %Data{} = data) do
    case delete_data(table, data) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def delete_data(%DataTable{data_list: datas, name: tablename} = table, %Data{} = data) do
    if !DataTable.has_data?(table, data) do
      Error.data_not_found(data, tablename, nil)
    else
      new_datas = Enum.filter(datas, &(&1 != data))
      {:ok, %DataTable{table | data_list: new_datas}}
    end
  end

  def edit_data!(%DataTable{} = table, %Data{} = data, %Data{} = new_data) do
    case edit_data(table, data, new_data) do
      {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  def edit_data(
        %DataTable{data_list: data_list, name: tablename} = table,
        %Data{} = data,
        %Data{value_list: new_value_map} = new_data
      ) do
    if !DataTable.has_data?(table, data) do
      Error.data_struct_not_found(data, tablename, nil)
    else
      case DataMapValidator.validate_data(table, new_value_map, :edit, data) do
        {:error, _} = err -> err
        :ok -> {:ok, %{table | data_list: [new_data | List.delete(data_list, data)]}}
      end
    end
  end
end
