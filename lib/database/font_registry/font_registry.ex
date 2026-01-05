defmodule Thaqqa.FontRegistry do
  use GenServer
  # import Thaqqa.Font
  @fonts :fonts
  @static_tables :static_tables

  ## API,直接呼び出せる関数群
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
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

  def add_font(font, timeout \\ 5_000) do
    try do
      {:ok, GenServer.call(__MODULE__, {:add_font, font})}
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

  def handle_call({:add_font, %Thaqqa.Font{name: name} = font}, _from, state) do
    :ets.insert(@fonts, {name, font})
    {:reply, :ok, state}
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

  def handle_info(:timeout, state), do: {:noreply, state}

  def handle_info(_, state), do: {:noreply, state}
end
