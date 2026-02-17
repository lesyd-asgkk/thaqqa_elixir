defmodule Thaqqa.FontUpdater do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column

  def update(%Prefab{} = prefab, major, minor, patch) do
    update_ver_0_0_1(prefab, x, y, z)
  end

  defp update_ver_0_1_0(%Prefab{} = prefab, x, y, _) when x <= 0 and y <= 0 do
    prefab
  end

  defp update_ver_0_1_0(%Prefab{} = prefab, _, _, _), do: prefab

  defp update_ver_0_0_1(%Prefab{} = prefab, x, y, z) when x <= 0 and y <= 0 and z <= 0 do
    prefab
  end

  defp update_ver_0_0_1(%Prefab{} = prefab, _, _, _), do: prefab
end
