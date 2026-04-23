# jsonファイルとして出力する際の挙動を纏めたもの
# Dataについては個別定義せず、DataTableの方で纏めて処理を行っている
# (Dataのみでのvolatilityの除去が厳しいため)

defimpl Jason.Encoder, for: Thaqqa.Column do
  def encode(column, opts),
    do:
      Jason.Encode.map(
        %{
          name: column.name,
          type: column.type,
          subtype: column.subtype,
          order: column.order,
          desc: column.desc,
          dev: column.dev
        },
        opts
      )
end

defimpl Jason.Encoder, for: Thaqqa.DataTable do
  def encode(datatable, opts) do
    datalist_map =
      datatable.data_list
      |> Enum.with_index()
      |> Map.new(fn {v, i} -> {Integer.to_string(i), v.value_map} end)

    column_volatility =
      Thaqqa.DataTable.get_column(datatable, fn %Thaqqa.Column{type: type} ->
        type == :volatility
      end)
      |> Enum.map(fn %Thaqqa.Column{name: name} -> name end)

    datalist_map =
      Enum.reduce(datalist_map, %{}, fn {k, v}, acc ->
        v =
          Enum.reduce(v, %{}, fn {k, v}, acc ->
            if k in column_volatility, do: acc, else: Map.put(acc, k, v)
          end)

        Map.put(acc, k, v)
      end)

    Jason.Encode.map(
      %{
        name: datatable.name,
        global: datatable.global,
        compile_rule: datatable.compile_rule,
        single: datatable.single,
        columnList: datatable.column_list |> Map.new(fn v -> {v.name, v} end),
        dataList: datalist_map
      },
      opts
    )
  end
end

defimpl Jason.Encoder, for: Thaqqa.Font do
  def encode(font, opts) do
    Jason.Encode.map(Map.new(font.table_list, fn table -> {table.name, table} end), opts)
  end
end

defimpl Jason.Encoder, for: Thaqqa.FontRegistryPrefab do
  def encode(prefab, opts) do
    Jason.Encode.map(
      %{
        static_tables:
          Map.new(prefab.static_tables, fn {_, _} = table_with_key -> table_with_key end),
        fonts:
          Map.new(prefab.fonts, fn {key, font} ->
            {key,
             %{
               table_list: Map.new(font.table_list, fn table -> {table.name, table} end),
               filename: font.filename
             }}
          end)
      },
      opts
    )
  end
end
