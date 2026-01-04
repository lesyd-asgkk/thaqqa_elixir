defmodule Thaqqa.Regex_Khhyl.AST do
  # , include: nil
  defstruct type: nil, value: nil, layer: nil, children: [], range: nil

  def new(type, layer, range, value \\ nil, children \\ []),
    do: %__MODULE__{type: type, value: value, layer: layer, children: children, range: range}

  def has_astarisk_for_form?(%__MODULE__{value: val, children: children}),
    do: if(children == [], do: val == "*", else: Enum.any?(children, &has_astarisk_for_form?/1))

  def replace_astarisk_as_form(%__MODULE__{value: val, children: children} = ast) do
    if val == "*",
      do: %__MODULE__{ast | value: "(?:init|mid|fin|sol|null)", type: :finite},
      else: %__MODULE__{
        ast
        | children: children |> Enum.map(&replace_astarisk_as_form(&1))
      }
  end

  def replace_astarisk_as_form_consonant(%__MODULE__{value: val, children: children} = ast) do
    if val == "*",
      do: %__MODULE__{ast | value: "(?:onset|coda|null)", type: :finite},
      else: %__MODULE__{
        ast
        | children: children |> Enum.map(&replace_astarisk_as_form_consonant(&1))
      }
  end

  def has_comma?(%__MODULE__{value: val, children: children}),
    do: if(children == [], do: val == ",", else: Enum.any?(children, &has_comma?/1))
end
