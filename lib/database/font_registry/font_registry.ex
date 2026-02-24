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

  def rollback(timeout \\ 30_000), do: safe_call({:rollback}, timeout)

  def commit(timeout \\ 30_000), do: safe_call({:commit}, timeout)

  def create_prefab(),
    do:
      {:ok,
       Thaqqa.FontRegistryPrefab.new(
         :ets.tab2list(@fonts_shadow) |> Map.new(),
         :ets.tab2list(@static_tables_shadow) |> Map.new()
       )}

  def create_prefab_managed(timeout \\ 5_000), do: safe_call({:create_prefab}, timeout)

  def apply_prefab(%Thaqqa.FontRegistryPrefab{} = prefab, timeout \\ 5_000),
    do: safe_call({:apply_prefab, prefab}, timeout)

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
        {:apply_prefab, %Thaqqa.FontRegistryPrefab{fonts: f, static_tables: t}},
        _from,
        state
      ) do
    :ets.delete_all_objects(@fonts_shadow)
    :ets.delete_all_objects(@static_tables_shadow)
    Enum.each(Map.to_list(f), &:ets.insert(@fonts_shadow, &1))
    Enum.each(Map.to_list(t), &:ets.insert(@static_tables_shadow, &1))
    {:reply, :ok, state}
  end

  def handle_call({:create_prefab}, _from, state) do
    result =
      Thaqqa.FontRegistryPrefab.new(
        :ets.tab2list(@fonts),
        :ets.tab2list(@static_tables)
      )

    {:reply, result, state}
  end

  def handle_info(:timeout, state), do: {:noreply, state}

  def handle_info(_, state), do: {:noreply, state}
end
