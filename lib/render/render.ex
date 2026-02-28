defmodule Khhyl.Render do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.ParserManager, as: ParserManager
  alias Thaqqa.GsubManager, as: GsubManager
  alias Thaqqa.UniqueGsubManager, as: UniqueGsubManager

  def convert_into_khhyl_letter(%Prefab{} = prefab, string, font, language, writing_direction)
      when language in [@khehyelu, @samlhta] and writing_direction in [@vertical, @horizontal] do
    with {:ok, parsed_string} <- Thaqqa.ParserManager.parse(prefab, string, language),
         {:ok, gsub_string} <- Thaqqa.GsubManager.gsub(prefab, parsed_string, writing_direction),
         {:ok, unique_gsub_string} <-
           Thaqqa.UniqueGsubManager.unique_gsub(prefab, gsub_string, writing_direction) do
      {:ok, unique_gsub_string}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  # prefabを持たない場合、FontRegistryから直接読み込む。
  def convert_into_khhyl_letter!(string, font, language, writing_direction) do
    case Thaqqa.FontRegistry.create_prefab() do
      {:ok, prefab} ->
        convert_into_khhyl_letter(prefab, string, font, language, writing_direction)

      {:error, msg} ->
        {:error, msg}
    end

    # prefab
    # |> Thaqqa.UniqueGposManager.gpos("Default", "S(mid,t0,e0,t0)", "vertical", "internal")
    # |> IO.inspect()
  end
end
