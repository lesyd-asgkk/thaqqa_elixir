defmodule Thaqqa.FontRegistryPrefab.Compiler do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data

  @concurrency_percentage 50
  @chunk_percentage 25

  def set_precompile_all(%Prefab{} = self) do
    with {:ok, static_tables_alt} <- set_precompile_on_root(self),
         {:ok, fonts_alt} <- set_precompile_on_all_font(self) do
      {:ok, %Prefab{self | static_tables: static_tables_alt, fonts: fonts_alt}}
    else
      {:error, _} = err -> err
    end
  end

  def set_precompile_on_root(%Prefab{static_tables: static_tables} = self) do
    Enum.map(static_tables, fn {key, value} ->
      {:ok, {key, set_precompile_on_datatable(self, value)}}
    end)
    |> Enum.reduce_while({:ok, %{}}, fn
      {:ok, {key, {:ok, value}}}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, key, value)}}
      {:ok, {_, {:error, _} = err}}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
  end

  def set_precompile_on_all_font(%Prefab{fonts: fonts} = self) do
    Enum.map(fonts, fn {key, value} ->
      {:ok, {key, set_precompile_on_font(self, value)}}
    end)
    |> Enum.reduce_while({:ok, %{}}, fn
      {:ok, {key, {:ok, value}}}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, key, value)}}
      {:ok, {_, {:error, _} = err}}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
  end

  def set_precompile_on_font(
        %Prefab{} = self,
        %Font{table_list: table_list} = font
      ) do
    Enum.map(
      table_list,
      fn table ->
        {:ok, set_precompile_on_datatable(self, table)}
      end
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, table}}, {:ok, acc} -> {:cont, {:ok, [table | acc]}}
      {:ok, {:error, _} = err}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, table_list} -> {:ok, %Font{font | table_list: table_list}}
      {:error, _} = err -> err
    end
  end

  def set_precompile_on_font(%Prefab{} = self, fontname) when is_binary(fontname) do
    with {:ok, %Font{} = font} <- Prefab.get_font_or_error(self, fontname),
         {:ok, %Font{} = font} <- set_precompile_on_font(self, font) do
      {:ok, font}
    else
      {:error, _} = err -> err
    end
  end

  defp set_precompile_on_datatable(
         %Prefab{} = self,
         %DataTable{data_list: data_list} = table
       ) do
    concurrency_ratio = @concurrency_percentage / 100
    chunk_ratio = @chunk_percentage / 100

    Enum.chunk_every(
      data_list,
      max(
        1,
        round(length(data_list) / System.schedulers_online() * concurrency_ratio * chunk_ratio)
      )
    )
    |> Task.async_stream(
      fn data_chunk ->
        Enum.map(data_chunk, fn data -> Data.set_precompile(data, table, self) end)
      end,
      ordered: false,
      max_concurrency: max(1, round(System.schedulers_online() * concurrency_ratio))
    )
    |> Enum.flat_map(fn
      {:ok, res} -> res
      {:exit, _} = ext -> ext
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, data}, {:ok, acc} -> {:cont, {:ok, [data | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, data_list} -> {:ok, %DataTable{table | data_list: data_list}}
      {:error, _} = err -> err
    end
  end
end
