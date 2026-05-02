defmodule Thaqqa.Regex_Khhyl.Translator do
  alias Thaqqa.Regex_Khhyl.AST, as: AST
  alias Thaqqa.Regex_Khhyl.Error, as: Error
  alias Thaqqa.Regex_Khhyl.Normalizer, as: Normalizer
  alias Thaqqa.Regex_Khhyl.Tokenizer, as: Tokenizer
  alias Thaqqa.FontRegistryPrefab.LetterTable, as: LetterTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  # ※仕様変更につき、Translator系統はPrefab系統を引数として取るようにする
  # regex_khhylの一部関数にも適応する
  def translate!(ast, %Prefab{} = prefab) when is_list(ast) do
    case translate(ast, prefab) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def translate(ast, %Prefab{} = prefab) when is_list(ast) do
    Enum.map(ast, fn ast_ -> translate(ast_, prefab) end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.join(Enum.reverse(list), "")}
      {:error, _} = err -> err
    end
  end

  def translate(%AST{} = ast, %Prefab{} = prefab) do
    t = translate_sub(ast, prefab)

    case t do
      {:error, _reason} -> t
      _ -> {:ok, t}
    end
  end

  defp argument_number([]), do: 0

  defp argument_number(list) when is_list(list),
    do: Enum.reduce(list, 1, fn x, acc -> if AST.has_comma?(x), do: acc + 1, else: acc end)

  defp export_as_string!(string, %Prefab{} = prefab) when is_binary(string) do
    case string |> Tokenizer.tokenize() |> Normalizer.normalize() do
      {:ok, val} -> translate!(val, %Prefab{} = prefab)
      {:error, reason} -> raise reason
    end
  end

  defp translate_sub(
         %AST{type: :script, value: val, table_range: _table_range},
         %Prefab{} = prefab
       ) do
    # 仕様変更につき、Translator系統はPrefab系統を取るようにする
    # ※0文字の@nameを持つ文字は除外（バグの温床でしかないので）
    # TODO:欄に応じてVOWEL/DIACRITICAL_Vのみ、のように変換する（regex長を縮める目的。*とは異なり個別指定なので、a|e|...|sのような長さとなると流石にハゲる ）
    # 技術的に困難である(S(init, ,a0,) だと init , , a0 , のようになってしまい
    # onset vowel codaの位置がばらばらになる)ことと、regex長の影響は小さいので優先度は低。
    # （regex長が伸びる、かつどの道最終的に不正なグリフを得た場合はglyphにエラーを検知する責務を果たさせる予定なので）
    case LetterTable.get_letter(prefab) do
      {:error, _} = err ->
        err

      {:ok, table_map} ->
        table_map
        |> Enum.reduce([], fn {k, v}, acc ->
          v ++ acc
          # if k in table_range, do: v ++ acc, else: acc
          # (set_table_rangeを真面目に実装した場合、こちらに切り替える)
        end)
        |> Enum.filter(fn %Thaqqa.Data{} = data -> Thaqqa.Data.get_value(data, @name) != "" end)
        |> Enum.reduce_while({:ok, []}, fn letter, {:ok, acc} ->
          Thaqqa.Regex_Khhyl.Cond.convert(val, letter)
          |> case do
            {:error, _} = err -> {:halt, err}
            {:ok, nil} -> {:cont, {:ok, acc}}
            {:ok, false} -> {:cont, {:ok, acc}}
            {:ok, true} -> {:cont, {:ok, [Thaqqa.Data.get_value(letter, @name) | acc]}}
          end
        end)
        |> case do
          {:error, _} = err -> err
          {:ok, otherwize} -> "(?:" <> Enum.join(otherwize, "|") <> ")"
        end
    end
  end

  defp translate_sub(%AST{type: :finite, value: val}, %Prefab{} = _prefab), do: val

  defp translate_sub(%AST{type: :brancket, value: val, children: children}, %Prefab{} = prefab),
    do: "(" <> val <> Enum.map_join(children, "", fn ch -> translate_sub(ch, prefab) end) <> ")"

  defp translate_sub(
         %AST{type: :S = type, range: range, children: children} = ast,
         %Prefab{} = prefab
       ) do
    case argument_number(children) do
      4 ->
        [head | tail] = children
        # |> Enum.map(&set_table_range(&1,))

        if AST.has_astarisk_for_form?(head) do
          translate_sub(
            %AST{type: :S, children: [AST.replace_astarisk_as_form(head) | tail]},
            prefab
          )
        else
          translate_brancket_sub("#{Atom.to_string(type)}\\(", [head | tail], prefab)
        end

      2 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(
              %AST{
                type: :S,
                children: [AST.replace_astarisk_as_form(head)] ++ tail ++ tail ++ tail
              },
              prefab
            ),
          else:
            translate_sub(
              %AST{type: :S, children: [head] ++ tail ++ tail ++ tail},
              prefab
            )

      1 ->
        if AST.has_astarisk_for_form?(ast),
          do: export_as_string!("S(*,*,*,*)", prefab),
          else: Error.invalid_astarisk(type, range)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: type, range: range, children: children} = ast, %Prefab{} = prefab)
       when type in [:V, :Vd] do
    case argument_number(children) do
      2 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(
              %AST{type: type, children: [AST.replace_astarisk_as_form(head) | tail]},
              prefab
            ),
          else: translate_brancket_sub("#{Atom.to_string(type)}\\(", children, prefab)

      1 ->
        if AST.has_astarisk_for_form?(ast),
          do: export_as_string!("#{Atom.to_string(type)}(*,*)", prefab),
          else: Error.invalid_astarisk(type, range)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: type, range: range, children: children} = ast, %Prefab{} = prefab)
       when type in [:C, :Cd] do
    case argument_number(children) do
      2 ->
        [head | tail] = children

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(
              %AST{
                type: type,
                children: [AST.replace_astarisk_as_form_consonant(head) | tail]
              },
              prefab
            ),
          else: translate_brancket_sub("#{Atom.to_string(type)}\\(", children, prefab)

      1 ->
        if AST.has_astarisk_for_form?(ast),
          do: export_as_string!("#{Atom.to_string(type)}(*,*)", prefab),
          else: Error.invalid_astarisk(type, range)

      _ ->
        Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: type, range: range, children: children}, %Prefab{} = _prefab)
       when type in [:Sep, :Null] do
    case argument_number(children) do
      0 -> "#{Atom.to_string(type)}\\(\\)"
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: :Lx = type, range: range, children: children}, %Prefab{} = prefab) do
    case argument_number(children) do
      0 -> export_as_string!("(?:S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))", prefab)
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: :L = type, range: range, children: children}, %Prefab{} = prefab) do
    case argument_number(children) do
      0 -> export_as_string!("(?:S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))", prefab)
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  # attribute_filterの処理(未使用)
  # こちらは将来用に残してはおく。
  defp translate_sub(
         %AST{type: :attribute_filler, value: {arg, letter_number}} = ast,
         %Prefab{} = prefab
       ) do
    ln = to_string(letter_number)

    case letter_number do
      nil ->
        "(?:;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"

      n ->
        y =
          case arg do
            nil -> "(?<attr#{ln}>;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"
            0 -> "(?<attr#{ln}>;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"
            1 -> "(?<attronset#{ln}>;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"
            2 -> "(?<attrvowel#{ln}>;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"
            3 -> "(?<attrcoda#{ln}>;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"
          end

        # "(?:;(?:[A-Za-z]|[0-9]|(?:\\.|=|-|:|&&| ))+)?"
    end
  end

  #

  defp translate_sub(%AST{type: :finite, value: val}, %Prefab{} = _prefab), do: val

  defp translate_sub(%AST{type: :R, value: val}, %Prefab{} = _prefab),
    do: "R\\(#{val}\\)"

  defp translate_sub(%AST{type: type, range: range, children: children}, %Prefab{} = prefab)
       when type in [:P, :Pd] do
    case argument_number(children) do
      1 -> translate_brancket_sub("#{Atom.to_string(type)}\\(", children, prefab)
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(
         %AST{type: :S = type, children: children} = ast,
         %Prefab{} = prefab
       ) do
  end

  defp translate_brancket_sub(val, children, %Prefab{} = prefab),
    do: val <> Enum.map_join(children, "", fn ch -> translate_sub(ch, prefab) end) <> "\\)"

  # 処理がやや複雑
  defp translate_sub(%AST{type: :token, value: val, layer: :glyph}, %Prefab{} = _prefab) do
    case val do
      # 全てのvariant
      "_" -> "(?:\\d+)"
      # 任意のglyph
      "." -> "(?:[A-Za-z]+)"
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

  defp translate_sub(%AST{children: children}, %Prefab{} = prefab),
    do: Enum.map_join(children, "", fn ch -> translate_sub(ch, prefab) end)
end
