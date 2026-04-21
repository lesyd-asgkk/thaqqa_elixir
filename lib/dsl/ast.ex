# 本東果文字変換用正規表現は汎用正規表現の完全代替を目指さない

# 実装は段階的変換構造。
# []をstruct、→変換モジュール→　を　変換モジュールによる対象の変換として
# [raw string] →Tokenizer → [list of raw string] →  Normalizer → [AST] → Translator → [string] ないし [regex]）。

# 言語仕様は定義済
#

defmodule Thaqqa.Regex_Khhyl.AST do
  # , include: nil
  defstruct type: nil,
            value: nil,
            layer: nil,
            children: [],
            range: nil,
            table_range: nil

  def new(type, layer, range, value \\ nil, children \\ []),
    do: %__MODULE__{
      type: type,
      value: value,
      layer: layer,
      children: children,
      range: range,
      table_range: nil
    }

  def has_astarisk_for_form?(%__MODULE__{value: val, children: children}),
    do: if(children == [], do: val == "*", else: Enum.any?(children, &has_astarisk_for_form?/1))

  def set_table_range(%__MODULE__{children: children} = ast, table_range)
      when is_list(table_range),
      do: %__MODULE__{
        ast
        | table_range: table_range,
          children: children |> Enum.map(&set_table_range(&1, table_range))
      }

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
