defmodule Thaqqa.FontUpdater do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column

  def update(%Prefab{} = prefab, x, y, z) do
    major = 0
    minor = 0
    patch = 0

    {prefab, major, minor, patch, x, y, z}
    |> update_ver_0_0_1()
    |> update_ver_0_1_0()
    |> extract_updated_prefab()
  end

  defp extract_updated_prefab({%Prefab{} = prefab, _, _, _, _x_cond, _y_cond, _z_cond}),
    do: prefab

  defp update_ver_0_1_0({%Prefab{} = prefab, x, y, z, x_cond, y_cond, z_cond})
       when x <= 0 and y <= 0,
       do: {prefab, x, y, z, x_cond, y_cond, z_cond}

  defp update_ver_0_1_0({%Prefab{} = prefab, x, y, z, x_cond, y_cond, z_cond}),
    do: {prefab, x, y, z, x_cond, y_cond, z_cond}

  defp update_ver_0_0_1({%Prefab{} = prefab, x, y, z, x_cond, y_cond, z_cond})
       when x <= 0 and y <= 0 and z <= 0 do
    {prefab, x, y, z, x_cond, y_cond, z_cond}
  end

  defp update_ver_0_0_1({%Prefab{} = prefab, x, y, z, x_cond, y_cond, z_cond}),
    do: {prefab, x, y, z, x_cond, y_cond, z_cond}
end
