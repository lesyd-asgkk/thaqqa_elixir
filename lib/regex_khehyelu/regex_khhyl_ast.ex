defmodule Thaqqa.Regex_Khhyl.AST do
  # , include: nil
  defstruct type: nil, value: nil, layer: nil, children: [], range: nil

  def new(type, layer, range, value \\ nil, children \\ []) do
    %__MODULE__{type: type, value: value, layer: layer, children: children, range: range}
  end

  def has_astarisk_for_form?(%__MODULE__{value: val, children: children}) do
    if children == [], do: val == "*", else: Enum.any?(children, &has_astarisk_for_form?/1)
  end

  def has_comma?(%__MODULE__{value: val, children: children}) do
    if children == [], do: val == ",", else: Enum.any?(children, &has_comma?/1)
  end
end
