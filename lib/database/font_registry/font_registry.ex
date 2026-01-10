defmodule Thaqqa.FontRegistry do
  use GenServer
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Font, as: Font
  @fonts :fonts
  @static_tables :static_tables

  ## API,直接呼び出せる関数群
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  defp check_tablename_conflict(name) do
    case get_static_table(name) do
      {:error, reason} -> Error.genserver_error(reason)
      {:ok, nil} -> {:ok, nil}
      {:ok, _} -> Error.nominal_conflict_datatable(name, :add)
    end
  end

  def get_font(name, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:get_font, name})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def get_table_from_font(name, tablename, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:get_table_from_font, {name, tablename}})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def init_font(font, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:init_font, font})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def add_font(fontname, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:add_font, fontname})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def delete_font(name, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:delete_font, name})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def edit_font(name, new_font, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:edit_font, {name, new_font}})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def get_static_table_all() do
    try do
      {:ok, GenServer.call(__MODULE__, {:get_static_table_all})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def get_static_table(name) do
    try do
      {:ok, GenServer.call(__MODULE__, {:get_static_table, name})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def add_static_table(name) do
    try do
      {:ok, GenServer.call(__MODULE__, {:add_static_table, name})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def delete_static_table(name) do
    try do
      {:ok, GenServer.call(__MODULE__, {:delete_static_table, name})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def edit_static_table(name, new_table) do
    try do
      {:ok, GenServer.call(__MODULE__, {:edit_static_table, {name, new_table}})}
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  ## 以下はCallbacks

  def init(:ok) do
    :ets.new(@fonts, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@static_tables, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  def handle_call({:init_font, %Thaqqa.Font{name: name} = font}, _from, state) do
    :ets.insert(@fonts, {name, font})
    {:reply, :ok, state}
  end

  def handle_call({:add_font, fontname}, _from, state) do
    # 現状はnilのみ
    reply = nil
    {:reply, reply, state}
  end

  def handle_call({:delete_font, name}, _from, state) do
    :ets.delete(@fonts, name)
    {:reply, :ok, state}
  end

  def handle_call({:get_font, name}, _form, state) do
    reply =
      case :ets.lookup(@fonts, name) do
        [{^name, font}] -> font
        [] -> nil
      end

    {:reply, reply, state}
  end

  def handle_call({:edit_font, {name, new_font}}, _form, state) do
    :ets.insert(@fonts, {name, new_font})
    {:reply, :ok, state}
  end

  ## static_table類

  def handle_call({:add_static_table, table}, _from, state) do
    :ets.insert(@static_tables, {table.name, table})
    {:reply, :ok, state}
  end

  def handle_call({:get_static_table_all}, _from, state) do
    reply = :ets.tab2list(@static_tables)
    {:reply, reply, state}
  end

  def handle_call({:get_static_table, name}, _from, state) do
    reply =
      case :ets.lookup(@static_tables, name) do
        [{^name, table}] -> table
        [] -> nil
      end

    {:reply, reply, state}
  end

  def handle_call({:delete_static_table, name}, _from, state) do
    :ets.delete(@static_tables, name)
    {:reply, :ok, state}
  end

  def handle_call({:edit_static_table, {name, new_table}}, _from, state) do
    :ets.insert(@static_tables, {name, new_table})
    {:reply, :ok, state}
  end

  ## table類

  def handle_call({:get_table_from_font, {name, tablename}}, _form, state) do
    reply =
      case :ets.lookup(@fonts, name) do
        [{^name, font}] -> font |> Font.get_table(tablename)
        [] -> nil
      end

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
