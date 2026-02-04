defmodule Thaqqa.FontRegistry do
  use GenServer
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontIO, as: FontIO
  @fonts :fonts
  @static_tables :static_tables
  @fonts_shadow :fonts_shadow
  @static_tables_shadow :static_tables_shadow
  ## API,直接呼び出せる関数群
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  defp safe_call(msg, timeout \\ 5_000) do
    try do
      case GenServer.call(__MODULE__, msg, timeout) do
        t when is_tuple(t) and tuple_size(t) >= 2 -> t
        {value} -> {:ok, value}
        {} -> {:ok}
        value -> {:ok, value}
      end
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  defp check_tablename_conflict(name) do
    case get_static_table(name) do
      {:error, reason} -> Error.genserver_error(reason)
      {:ok, nil} -> {:ok, nil}
      {:ok, _} -> Error.nominal_conflict_datatable(name, :add)
    end
  end

  defp get_font_internal(name) do
    case :ets.lookup(@fonts_shadow, name) do
      [{^name, font}] -> font
      [] -> nil
    end
  end

  defp get_table_from_font_internal(name, tablename) do
    case :ets.lookup(@fonts_shadow, name) do
      [{^name, font}] -> font |> Font.get_table(tablename)
      [] -> nil
    end
  end

  def rollback(timeout \\ 30_000), do: safe_call({:rollback}, timeout)

  def commit(timeout \\ 30_000), do: safe_call({:commit}, timeout)

  def create_prefab(),
    do:
      {:ok,
       Thaqqa.FontRegisteryPrefab.new(
         :ets.tab2list(@fonts_shadow),
         :ets.tab2list(@static_tables_shadow)
       )}

  def create_prefab_managed(timeout \\ 5_000), do: safe_call({:create_prefab}, timeout)

  def apply_prefab(%Thaqqa.FontRegisteryPrefab{} = prefab, timeout \\ 5_000),
    do: safe_call({:apply_prefab, prefab}, timeout)

  def get_font_all(), do: {:ok, :ets.tab2list(@fonts_shadow)}

  def get_font(name), do: {:ok, get_font_internal(name)}

  def get_table_from_font(name, tablename),
    do: {:ok, get_table_from_font_internal(name, tablename)}

  def get_font_all_managed(timeout \\ 5_000), do: safe_call({:get_font_all}, timeout)

  def get_font_managed(name, timeout \\ 5_000), do: safe_call({:get_font, name}, timeout)

  def get_table_from_font_managed(name, tablename, timeout \\ 5_000),
    do: safe_call({:get_table_from_font, {name, tablename}}, timeout)

  def init_font(font, timeout \\ 5_000), do: safe_call({:init_font, font}, timeout)

  def add_font(fontname, timeout \\ 5_000), do: safe_call({:add_font, fontname}, timeout)

  def delete_font(name, timeout \\ 5_000), do: safe_call({:delete_font, name}, timeout)

  def edit_font(name, new_font, timeout \\ 5_000),
    do: safe_call({:edit_font, {name, new_font}}, timeout)

  def get_static_table_all(), do: {:ok, :ets.tab2list(@static_tables_shadow)}

  def get_static_table_global(),
    do: {:ok, :ets.tab2list(@static_tables_shadow) |> Enum.filter(fn {_, val} -> val.global end)}

  def get_static_table_local(),
    do: {:ok, :ets.tab2list(@static_tables_shadow) |> Enum.filter(fn {_, val} -> !val.global end)}

  defp get_static_table_internal(name) do
    case :ets.lookup(@static_tables_shadow, name) do
      [{^name, table}] -> table
      [] -> nil
    end
  end

  def get_static_table(name), do: {:ok, get_static_table_internal(name)}

  def get_static_table_all_managed(timeout \\ 5_000),
    do: safe_call({:get_static_table_all}, timeout)

  def get_static_table_global_managed(timeout \\ 5_000),
    do: safe_call({:get_static_table_global}, timeout)

  def get_static_table_local_managed(timeout \\ 5_000),
    do: safe_call({:get_static_table_local}, timeout)

  def get_static_table_managed(name, timeout \\ 5_000),
    do: safe_call({:get_static_table, name}, timeout)

  def add_static_table(table, timeout \\ 5_000),
    do: safe_call({:add_static_table, table}, timeout)

  def delete_static_table(name, timeout \\ 5_000),
    do: safe_call({:delete_static_table, name}, timeout)

  def edit_static_table(name, new_table, timeout \\ 5_000),
    do: safe_call({:edit_static_table, {name, new_table}}, timeout)

  ## 以下はCallbacks

  def init(:ok) do
    :ets.new(@fonts, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@static_tables, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@fonts_shadow, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@static_tables_shadow, [:named_table, :protected, :set, read_concurrency: true])
    {:ok, %{}}
  end

  def handle_call({:rollback}, _from, state) do
    :ets.delete_all_objects(@fonts_shadow)
    :ets.delete_all_objects(@static_tables_shadow)

    :ets.tab2list(@fonts)
    |> Enum.each(&:ets.insert(@fonts_shadow, &1))

    :ets.tab2list(@static_tables)
    |> Enum.each(&:ets.insert(@static_tables_shadow, &1))

    {:reply, :ok, state}
  end

  def handle_call({:commit}, _from, state) do
    :ets.delete_all_objects(@fonts)
    :ets.delete_all_objects(@static_tables)

    :ets.tab2list(@fonts_shadow)
    |> Enum.each(&:ets.insert(@fonts, &1))

    :ets.tab2list(@static_tables_shadow)
    |> Enum.each(&:ets.insert(@static_tables, &1))

    {:reply, :ok, state}
  end

  def handle_call(
        {:apply_prefab, %Thaqqa.FontRegisteryPrefab{fonts: f, static_tables: t}},
        _from,
        state
      ) do
    :ets.delete_all_objects(@fonts_shadow)
    :ets.delete_all_objects(@static_tables_shadow)
    Enum.each(f, &:ets.insert(@fonts_shadow, &1))
    Enum.each(t, &:ets.insert(@static_tables_shadow, &1))
    {:reply, :ok, state}
  end

  def handle_call({:create_prefab}, _from, state) do
    result =
      Thaqqa.FontRegisteryPrefab.new(
        :ets.tab2list(@fonts_shadow),
        :ets.tab2list(@static_tables_shadow)
      )

    {:reply, result, state}
  end

  def handle_call({:import_root}, _from, state) do
    result = FontIO.import()
    {:reply, result, state}
  end

  def handle_call({:import_font, fontname}, _from, state) do
    result = FontIO.import(fontname)
    {:reply, result, state}
  end

  def handle_call({:push}, _from, state) do
    # @fonts,@static_tablesに基づいてexportする
    # fontfileの指定くらいか？　そもそも構造自体を変えるべきな気もするが。
    # result = FontIO.export(@fonts,@static_tables)
    result = :ok
    {:reply, result, state}
  end

  def handle_call({:init_font, %Thaqqa.Font{name: name} = font}, _from, state) do
    :ets.insert(@fonts_shadow, {name, font})
    {:reply, :ok, state}
  end

  def handle_call({:add_font, fontname}, _from, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:delete_font, name}, _from, state) do
    :ets.delete(@fonts_shadow, name)
    {:reply, :ok, state}
  end

  def handle_call({:get_font, name}, _form, state) do
    reply = get_font_internal(name)

    {:reply, reply, state}
  end

  def handle_call({:get_font_all}, _form, state) do
    reply = :ets.tab2list(@fonts_shadow)
    {:reply, reply, state}
  end

  def handle_call({:edit_font, {name, new_font}}, _form, state) do
    :ets.insert(@fonts_shadow, {name, new_font})
    {:reply, :ok, state}
  end

  ## static_table類

  def handle_call({:add_static_table, table}, _from, state) do
    :ets.insert(@static_tables_shadow, {table.name, table})
    {:reply, :ok, state}
  end

  def handle_call({:get_static_table_all}, _from, state) do
    reply = :ets.tab2list(@static_tables_shadow)
    {:reply, reply, state}
  end

  # table.globalがtrueのやつだけ抜き出すver
  def handle_call({:get_static_table_global}, _from, state) do
    reply =
      :ets.tab2list(@static_tables_shadow)
      |> Enum.filter(fn {_, val} -> val.global end)

    {:reply, reply, state}
  end

  def handle_call({:get_static_table_local}, _from, state) do
    reply =
      :ets.tab2list(@static_tables_shadow)
      |> Enum.filter(fn {_, val} -> !val.global end)

    {:reply, reply, state}
  end

  def handle_call({:get_static_table, name}, _from, state) do
    reply = get_static_table_internal(name)
    {:reply, reply, state}
  end

  def handle_call({:delete_static_table, name}, _from, state) do
    :ets.delete(@static_tables_shadow, name)
    {:reply, :ok, state}
  end

  def handle_call({:edit_static_table, {name, new_table}}, _from, state) do
    :ets.insert(@static_tables_shadow, {name, new_table})
    {:reply, :ok, state}
  end

  ## table類

  def handle_call({:get_table_from_font, {name, tablename}}, _form, state) do
    reply = get_table_from_font_internal(name, tablename)

    {:reply, reply, state}
  end

  def handle_call({:add_table_into_all, {name, tablename}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:edit_tablename_from_all, {name, tablename, tablename_alt}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:delete_table_from_all, {name, tablename}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  # column
  def handle_call({:get_column_of_static, {column_name}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:add_column_of_static, {column}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:edit_column_of_static, {column_name, new_column}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:delete_column_of_static, {column_name}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  # 以降はfont用
  def handle_call({:get_column_of_font, {column_name}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:add_column_of_font, {column}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:edit_column_of_font, {column_name, new_column}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:delete_column_of_font, {column_name}}, _form, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_info(:timeout, state), do: {:noreply, state}

  def handle_info(_, state), do: {:noreply, state}
end
