defmodule Thaqqa.Regex_Khhyl.Translator do
  alias Thaqqa.Regex_Khhyl.AST, as: AST
  alias Thaqqa.Regex_Khhyl.Error, as: Error
  alias Thaqqa.Regex_Khhyl.Normalizer, as: Normalizer
  alias Thaqqa.Regex_Khhyl.Tokenizer, as: Tokenizer
  alias Thaqqa.LetterRegister, as: LetterRegister
  use Thaqqa.DataTable.Const

  def translate!(ast) when is_list(ast) do
    case translate(ast) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def translate(ast) when is_list(ast) do
    Enum.map(ast, &translate/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} ->
        {:cont, {:ok, [str | acc]}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, list} ->
        {:ok, Enum.join(Enum.reverse(list), "")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def translate(%AST{} = ast) do
    t = translate_sub(ast)

    case t do
      {:error, _msg} -> t
      _ -> {:ok, t}
    end
  end

  defp argument_number([]), do: 0

  defp argument_number(list) when is_list(list) do
    Enum.reduce(list, 1, fn x, acc ->
      if AST.has_comma?(x), do: acc + 1, else: acc
    end)
  end

  defp export_as_string!(string) when is_binary(string) do
    case string |> Tokenizer.tokenize() |> Normalizer.normalize() do
      {:ok, val} -> translate!(val)
      {:error, msg} -> raise msg
    end
  end

  defp translate_sub(%AST{type: :script, value: val}) do
    # 暫定的な処置。todo:scriptパーサ (テーブル実装後になります)

    letter_list =
      LetterRegister.get_letter()
      |> Enum.reduce([], fn {_k, v}, acc -> acc = v ++ acc end)

    letter_available =
      Enum.reduce_while(letter_list, [], fn letter, acc ->
        true_or_false = Thaqqa.Regex_Khhyl.Cond.convert(val, letter)

        case true_or_false do
          {:error, _msg} -> {:halt, true_or_false}
          {:ok, nil} -> {:cont, acc}
          {:ok, false} -> {:cont, acc}
          {:ok, true} -> {:cont, [Thaqqa.Data.get_val(letter, @name) | acc]}
        end
      end)

    case letter_available do
      {:error, msg} -> letter_available
      val -> "(?:" <> Enum.join(val, "|") <> ")"
    end
  end

  defp translate_sub(%AST{type: :finite, value: val}), do: val

  defp translate_sub(%AST{type: :brancket, value: val, children: children}),
    do: "(" <> val <> Enum.map_join(children, "", &translate_sub/1) <> ")"

  # S(*), C(*)のようなvariantをこっちで実装する。
  # *を取り出す方法……？

  defp translate_sub(%AST{type: :S = type, range: range, children: children} = ast) do
    case argument_number(children) do
      4 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(%AST{type: :S, children: [AST.replace_astarisk_as_form(head) | tail]}),
          else: translate_brancket_sub("#{Atom.to_string(type)}\\(", children)

      2 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(Enum.at(children, 2)),
          do:
            translate_sub(%AST{
              type: :S,
              children: [AST.replace_astarisk_as_form(head)] ++ tail ++ tail
            }),
          else: Error.invalid_astarisk(type, range)

      1 ->
        if AST.has_astarisk_for_form?(ast),
          do: export_as_string!("S(*,*,*,*)"),
          else: Error.invalid_astarisk(type, range)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: type, range: range, children: children} = ast)
       when type in [:V, :Vd] do
    case argument_number(children) do
      2 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(%AST{type: type, children: [AST.replace_astarisk_as_form(head) | tail]}),
          else: translate_brancket_sub("#{Atom.to_string(type)}\\(", children)

      1 ->
        if AST.has_astarisk_for_form?(ast),
          do: export_as_string!("#{Atom.to_string(type)}(*,*)"),
          else: Error.invalid_astarisk(type, range)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: type, range: range, children: children} = ast)
       when type in [:C, :Cd] do
    case argument_number(children) do
      2 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(%AST{
              type: type,
              children: [AST.replace_astarisk_as_form_consonant(head) | tail]
            }),
          else: translate_brancket_sub("#{Atom.to_string(type)}\\(", children)

      1 ->
        if AST.has_astarisk_for_form?(ast),
          do: export_as_string!("#{Atom.to_string(type)}(*,*)"),
          else: Error.invalid_astarisk(type, range)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: type, range: range, children: children})
       when type in [:Sep, :Null] do
    case argument_number(children) do
      0 -> "#{Atom.to_string(type)}\\(\\)"
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: :L = type, range: range, children: children}) do
    case argument_number(children) do
      0 -> export_as_string!("(?:S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))")
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: :R, value: val}),
    do: "R\\(#{val}\\)"

  defp translate_sub(%AST{type: type, range: range, children: children}) when type in [:P, :Pd] do
    case argument_number(children) do
      1 -> translate_brancket_sub("#{Atom.to_string(type)}\\(", children)
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: :X = type, range: range, children: children}) do
    case argument_number(children) do
      2 ->
        translate_brancket_sub("#{Atom.to_string(type)}\\(", children)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_brancket_sub(val, children),
    do: val <> Enum.map_join(children, "", &translate_sub/1) <> "\\)"

  # 処理がやや複雑
  defp translate_sub(%AST{type: :token, value: val, layer: :glyph}) do
    case val do
      # 全てのvariant
      "_" -> "(?:\\d+)"
      # 任意のglyph
      "." -> "(?:[A-Za-z]+\\d+)"
      # 0グリフ以上
      "*" -> "(?:|(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*))"
      # 1グリフ以上
      "+" -> "(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*)"
      # 0 or 1グリフ
      "?" -> "(?:(?:[A-Za-z]+\\d+)?)"
      # 0グリフ以上
      "*?" -> "(?:|(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*?))"
      # 1グリフ以上
      "+?" -> "(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*?)"
      # 0 or 1グリフ
      "??" -> "(?:(?:[A-Za-z]+\\d+)??)"
      # 0グリフ以上
      "-*" -> "(?:(?:\-[A-Za-z]+\\d+)*)"
      # 1グリフ以上
      "-+" -> "(?:(?:\-[A-Za-z]+\\d+)+)"
      # 0 or 1グリフ
      "-?" -> "(?:(?:\-[A-Za-z]+\\d+)?)"
      # 0グリフ以上
      "-*?" -> "(?:(?:\-[A-Za-z]+\\d+)*?)"
      # 1グリフ以上
      "-+?" -> "(?:(?:\-[A-Za-z]+\\d+)+?)"
      # 0 or 1グリフ
      "-??" -> "(?:(?:\-[A-Za-z]+\\d+)??)"
    end
  end

  defp translate_sub(%AST{children: children}),
    do: Enum.map_join(children, "", &translate_sub/1)
end
