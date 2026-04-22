defmodule Thaqqa.FontRegistry do
  use GenServer
  @fonts :fonts
  @static_tables :static_tables
  @fonts_shadow :fonts_shadow
  @static_tables_shadow :static_tables_shadow

  ## API,直接呼び出せる関数群
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def import_as_root(), do: Thaqqa.FontRegistry.IO.import_as_root()
  def import_as_font(filename), do: Thaqqa.FontRegistry.IO.import_as_font(filename)

  defp safe_call(msg, timeout \\ 5_000) do
    try do
      GenServer.call(__MODULE__, msg, timeout)
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def rollback(timeout \\ 30_000), do: safe_call({:rollback}, timeout)

  def commit(timeout \\ 30_000), do: safe_call({:commit}, timeout)

  def export_as_root(opts, timeout \\ 30_000),
    do: safe_call({:save_root, opts}, timeout)

  def export_as_font(fontname, opts, timeout \\ 30_000),
    do: safe_call({:save_font, fontname, opts}, timeout)

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

    {:reply, {:ok, result}, state}
  end

  # この指定は仮。
  # 将来的にはdefmacroのquoteとする
  # (外部から触りやすい値に！)
  @root_file "data/main.json"

  def handle_call({:save_root, opts}, _from, state) do
    with {:ok, json} <-
           Jason.encode(
             :ets.tab2list(@static_tables)
             |> Map.new(),
             opts
           ),
         :ok <- File.write(@root_file, json) do
      {:reply, :ok, state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  @font_folder "data/"
  @font_file "/main.json"

  def handle_call({:save_font, fontname, opts}, _from, state) do
    with font when not is_nil(font) <- :ets.tab2list(@fonts) |> Map.new() |> Map.get(fontname),
         {:ok, json} <- Jason.encode(font, opts),
         :ok <- File.mkdir_p(@font_folder <> font.filename),
         :ok <- File.write(@font_folder <> font.filename <> @font_file, json) do
      {:reply, :ok, state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_info(:timeout, state), do: {:noreply, state}

  def handle_info(_, state), do: {:noreply, state}
end
