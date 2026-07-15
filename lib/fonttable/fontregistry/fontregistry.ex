defmodule Thaqqa.FontRegistry do
  use GenServer

  alias Thaqqa.Filename, as: Filename

  @timeout_default 50_000

  @apply_timeout 30_000

  @commit_timeout 30_000
  @rollback_timeout 30_000

  @import_timeout 30_000
  @export_timeout 30_000

  @bundles_stable :bundles_stable
  @bundles :bundles
  @bundles_shadow :bundles_shadow

  @bundles_name_key :bundles_name_key
  @bundles_shadow_name_key :bundles_shadow_name_key
  @bundles_name_key_reverse :bundles_name_key_reverse
  @bundles_shadow_name_key_reverse :bundles_shadow_name_key_reverse

  @bundle_uuid_to_commit :bundles_uuid_to_commit
  # shadowテーブルに保持されたbundleのうち
  # commitされる必要のあるuuidを{uuid,nil}の方式で保持するtable
  # commitされた時 or rollbackされた時、その対象uuidに応じたデータ{uuid,nil}を破棄する。

  @const_tables :const_tables
  @const_tables_shadow :const_tables_shadow

  ## API,直接呼び出せる関数群
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def import_const(), do: Thaqqa.FontRegistry.IO.import_const()

  def import_bundle(uuid), do: Thaqqa.FontRegistry.IO.import_bundle(uuid)

  defp safe_call(msg, timeout \\ @timeout_default) do
    try do
      GenServer.call(__MODULE__, msg, timeout)
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end

  def rollback_const(timeout \\ @rollback_timeout), do: safe_call({:rollback_const}, timeout)

  def rollback_bundle(uuid, timeout \\ @rollback_timeout),
    do: safe_call({:rollback_bundle, uuid}, timeout)

  def commit_const(timeout \\ @commit_timeout), do: safe_call({:commit_const}, timeout)

  def commit_bundle(uuid, timeout \\ @commit_timeout),
    do: safe_call({:commit_bundle, uuid}, timeout)

  def export_const(opts, timeout \\ @export_timeout),
    do: safe_call({:save_const, opts}, timeout)

  def export_bundle(uuid, opts, timeout \\ @export_timeout),
    do: safe_call({:save_bundle, uuid, opts}, timeout)

  def create_blank_prefab(), do: {:ok, Thaqqa.Bundle.new(%{}, %{})}
  def create_prefab(), do: create_blank_prefab()

  def create_prefab(uuid) do
    case :ets.lookup(@bundles_shadow, uuid) |> Enum.at(0) do
      nil ->
        {:ok, Thaqqa.Bundle.new(%{}, %{})}

      {_, otherwize} ->
        {:ok, otherwize}
    end
  end

  def create_const_table() do
    case :ets.lookup(@const_tables_shadow, 0) |> Enum.at(0) do
      nil -> {:ok, Thaqqa.ConstTable.new()}
      {_, otherwize} -> {:ok, otherwize}
    end
  end

  def create_const_table_managed(uuid, timeout \\ 5_000),
    do: safe_call({:create_const_table, uuid}, timeout)

  def create_blank_prefab_managed(timeout \\ 5_000),
    do: safe_call({:create_blank_prefab}, timeout)

  def create_prefab_managed(uuid, timeout \\ 5_000),
    do: safe_call({:create_prefab, uuid}, timeout)

  def apply_bundle(%Thaqqa.Bundle{} = prefab, uuid, timeout \\ @apply_timeout),
    do: safe_call({:apply_bundle, prefab, uuid}, timeout)

  def apply_const(const_map, timeout \\ @apply_timeout),
    do: safe_call({:apply_const, const_map}, timeout)

  ## 以下はCallbacks

  def init(:ok) do
    :ets.new(@bundles_stable, [:named_table, :protected, :set, read_concurrency: true])
    # ↑は将来予約
    :ets.new(@bundles, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@bundles_shadow, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@bundles_name_key, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@bundles_shadow_name_key, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@bundles_name_key_reverse, [:named_table, :protected, :set, read_concurrency: true])

    :ets.new(@bundles_shadow_name_key_reverse, [
      :named_table,
      :protected,
      :set,
      read_concurrency: true
    ])

    :ets.new(@bundle_uuid_to_commit, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@const_tables, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@const_tables_shadow, [:named_table, :protected, :set, read_concurrency: true])
    {:ok, %{}}
  end

  # rollback系

  defp rollback_bundle_internal(uuid) do
    case :ets.lookup(@bundles_shadow, uuid) do
      nil ->
        nil

      bundles when not is_nil(bundles) ->
        :ets.insert(@bundles_shadow, :ets.lookup(@bundles, uuid))
        :ets.delete(@bundle_uuid_to_commit, uuid)
    end
  end

  def handle_call({:rollback_const}, _from, state) do
    :ets.delete(@const_tables_shadow, 0)

    :ets.insert(
      @const_tables_shadow,
      :ets.tab2list(@const_tables) |> Enum.map(fn {k, v} -> {k, v} end)
    )

    {:reply, :ok, state}
  end

  def handle_call({:rollback_bundle, uuid}, _from, state) do
    rollback_bundle_internal(uuid)
    {:reply, :ok, state}
  end

  def handle_call({:rollback_all}, _from, state) do
    :ets.tab2list(@bundle_uuid_to_commit)
    |> Enum.map(fn {k, _} -> k end)
    |> Enum.each(&rollback_bundle_internal(&1))

    {:reply, :ok, state}
  end

  # commit系

  def handle_call({:commit_const}, _from, state) do
    :ets.delete(@const_tables, 0)

    :ets.insert(
      @const_tables,
      :ets.tab2list(@const_tables_shadow) |> Enum.map(fn {k, v} -> {k, v} end)
    )

    {:reply, :ok, state}
  end

  defp commit_bundle_internal(uuid) do
    case :ets.lookup(@bundles_shadow, uuid) do
      nil ->
        nil

      bundles when not is_nil(bundles) ->
        # uuid交換設定をここに
        case :ets.lookup(@bundles_name_key, uuid) |> Enum.at(0) do
          nil ->
            {_, bundlename} = :ets.lookup(@bundles_shadow_name_key, uuid) |> Enum.at(0)
            :ets.insert(@bundles_name_key, {uuid, bundlename})
            :ets.insert(@bundles_name_key_reverse, {bundlename, uuid})
            :ets.delete(@bundles_shadow_name_key, uuid)
            :ets.delete(@bundles_shadow_name_key_reverse, bundlename)

          {_, bundlename_old} when not is_nil(bundlename_old) ->
            {_, bundlename} = :ets.lookup(@bundles_shadow_name_key, uuid) |> Enum.at(0)
            :ets.delete(@bundles_name_key_reverse, bundlename)
            :ets.insert(@bundles_name_key, {uuid, bundlename})
            :ets.insert(@bundles_name_key_reverse, {bundlename, uuid})
            :ets.delete(@bundles_shadow_name_key, uuid)
            :ets.delete(@bundles_shadow_name_key_reverse, bundlename)
        end

        :ets.insert(@bundles, bundles)
        :ets.delete(@bundle_uuid_to_commit, uuid)
    end
  end

  def handle_call({:commit_bundle, uuid}, _from, state) do
    commit_bundle_internal(uuid)
    {:reply, :ok, state}
  end

  def handle_call({:commit_all}, _from, state) do
    :ets.tab2list(@bundle_uuid_to_commit)
    |> Enum.map(fn {k, _} -> k end)
    |> Enum.each(&commit_bundle_internal(&1))

    {:reply, :ok, state}
  end

  # apply系列
  defp get_bundlename(bundle),
    do: (bundle.static_tables["BUNDLEDATA"].data_list |> Enum.at(0)).value_map["Bundlename"]

  # get_bundlename
  def handle_call(
        {:apply_bundle, %Thaqqa.Bundle{} = bundle, uuid},
        _from,
        state
      ) do
    :ets.insert(@bundles_shadow, {uuid, bundle})
    :ets.insert(@bundle_uuid_to_commit, {uuid, nil})

    bundlename = get_bundlename(bundle)
    :ets.insert(@bundles_shadow_name_key, {uuid, bundlename})
    :ets.insert(@bundles_shadow_name_key_reverse, {bundlename, uuid})

    {:reply, :ok, state}
  end

  def handle_call(
        {:apply_const, const_map},
        _from,
        state
      ) do
    :ets.insert(@const_tables_shadow, {0, const_map})
    {:reply, :ok, state}
  end

  # prefab系列
  def handle_call({:create_blank_prefab}, _from, state) do
    result = Thaqqa.Bundle.new(%{}, %{})
    {:reply, {:ok, result}, state}
  end

  def handle_call({:create_prefab, uuid}, _from, state) do
    result =
      case :ets.lookup(@bundles_shadow, uuid) |> Enum.at(0) do
        nil -> Thaqqa.Bundle.new(%{}, %{})
        {_, otherwize} -> otherwize
      end

    {:reply, {:ok, result}, state}
  end

  def handle_call({:create_const_table}, _from, state) do
    result =
      case :ets.lookup(@const_tables_shadow, 0) |> Enum.at(0) do
        nil -> Thaqqa.ConstTable.new()
        {_, otherwize} -> otherwize
      end

    {:reply, {:ok, result}, state}
  end

  # ファイル保存系列

  def handle_call({:save_const, opts}, _from, state) do
    with [{_, const_table}] <- :ets.lookup(@const_tables, 0),
         {:ok, json} <- Jason.encode(const_table, opts),
         :ok <- File.write(Filename.root_folder() <> Filename.root_file(), json) do
      {:reply, :ok, state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  defp save_font_map(fonts, bundle_path, opts) do
    Enum.reduce_while(fonts, :ok, fn {_, v}, :ok ->
      uuid = Thaqqa.Font.get_table(v, "FONTSYSDATA") |> Thaqqa.DataTable.get_data() |> Enum.at(0)
      uuid = uuid.value_map |> Map.get("UUID")

      case save_font(v, uuid, bundle_path, opts) do
        {:error, _} = err -> {:halt, err}
        :ok -> {:cont, :ok}
      end
    end)
  end

  defp save_font(font, uuid, bundle_path, opts) do
    font_folder_name = bundle_path <> Filename.font_folder(uuid)

    with {:ok, json} <- Jason.encode(font, opts),
         :ok <- File.mkdir_p(font_folder_name),
         :ok <- File.write(font_folder_name <> Filename.font_file(), json),
         [major, minor, patch, pre] <-
           get_version_data("FONTSYSDATA", font.table_list),
         :ok <-
           File.write(
             font_folder_name <> Filename.version_file(major, minor, patch, pre),
             json
           ) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  defp get_version_data(tablename, data) do
    data_list = (data[tablename].data_list |> Enum.at(0)).value_map

    [
      data_list["VersionMajor"],
      data_list["VersionMinor"],
      data_list["VersionPatch"],
      data_list["VersionPreRelease"]
    ]
  end

  def handle_call({:save_bundle, uuid, opts}, _from, state) do
    bundle_folder_name = Filename.root_folder() <> Filename.bundle_folder(uuid)

    with [{_, %Thaqqa.Bundle{static_tables: static_tables, fonts: fonts}}] <-
           :ets.lookup(@bundles_shadow, uuid),
         {:ok, json_statics} <- Jason.encode(static_tables, opts),
         :ok <- File.mkdir_p(bundle_folder_name),
         :ok <- File.write(bundle_folder_name <> Filename.bundle_file(), json_statics),
         [major, minor, patch, pre] <-
           get_version_data("BUNDLESYSDATA", static_tables),
         :ok <-
           File.write(
             bundle_folder_name <> Filename.version_file(major, minor, patch, pre),
             json_statics
           ),
         :ok <- save_font_map(fonts, bundle_folder_name, opts) do
      {:reply, :ok, state}
    else
      {:error, _} = err -> {:reply, err, state}
    end

    # :ok <- File.mkdir_p(Filename.font_folder() <> font.filename),
  end

  def handle_info(:timeout, state), do: {:noreply, state}

  def handle_info(_, state), do: {:noreply, state}
end
