defmodule Thaqqa.FontManager do
  use GenServer
  import Thaqqa.Font
  @fonts :fonts
  @static_tables :static_tables

  ## API,直接呼び出せる関数群
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_font(name) do
    case :ets.lookup(@fonts, name) do
      [{^name, font}] -> font
      [] -> nil
    end
  end

  def add_font(font) do
    GenServer.call(__MODULE__, {:add_font, font})
  end

  def delete_font(name) do
    :ets.delete(@fonts, name)
  end

  def edit_font(name, new_font) do
    :ets.insert(@fonts, {name, new_font})
  end

  def get_static_table_all() do
    :ets.tab2list(@static_tables)
  end

  def get_static_table(name) do
    case :ets.lookup(@static_tables, name) do
      [{^name, table}] -> table
      [] -> nil
    end
  end

  def add_static_table(table) do
    :ets.insert(@static_tables, {table.name, table})
  end

  def delete_static_table(name) do
    :ets.delete(@static_tables, name)
  end

  def edit_static_table(name, new_table) do
    :ets.insert(@static_tables, {name, new_table})
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
end
