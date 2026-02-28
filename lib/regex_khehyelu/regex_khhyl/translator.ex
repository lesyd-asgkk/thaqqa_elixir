defmodule Thaqqa.Regex_Khhyl.Translator do
  alias Thaqqa.Regex_Khhyl.AST, as: AST
  alias Thaqqa.Regex_Khhyl.Error, as: Error
  alias Thaqqa.Regex_Khhyl.Normalizer, as: Normalizer
  alias Thaqqa.Regex_Khhyl.Tokenizer, as: Tokenizer
  alias Thaqqa.LetterManager, as: LetterManager
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  # ※仕様変更につき、Translator系統はPrefab系統を引数として取るようにする
  # regex_khhylの一部関数にも適応する
  def translate!(ast, %Prefab{} = prefab) when is_list(ast) do
    case translate(ast, prefab) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def translate(ast, %Prefab{} = prefab) when is_list(ast) do
    Enum.map(ast, fn ast_ -> translate(ast_, prefab) end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.join(Enum.reverse(list), "")}
      {:error, reason} -> {:error, reason}
    end
  end

  def translate(%AST{} = ast, %Prefab{} = prefab) do
    t = translate_sub(ast, prefab)

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

  defp export_as_string!(string, %Prefab{} = prefab) when is_binary(string) do
    case string |> Tokenizer.tokenize() |> Normalizer.normalize() do
      {:ok, val} -> translate!(val, %Prefab{} = prefab)
      {:error, msg} -> raise msg
    end
  end

  defp translate_sub(%AST{type: :script, value: val}, %Prefab{} = prefab) do
    # 仕様変更につき、Translator系統はPrefab系統を取るようにする
    # ※0文字の@nameを持つ文字は除外（バグの温床でしかないので）
    # TODO:欄に応じてVOWEL/DIACRITICAL_Vのみ、のように変換する（regex長を縮める目的。*とは異なり個別指定なので。）
    # *や+、._がテーブル上にない文字を受け付けてしまう問題は現状は無視する
    # （regex長が伸びる、かつどの道最終的に不正なグリフを得た場合はglyphにエラーを検知する責務を果たさせる予定なので）
    case LetterManager.get_letter(prefab) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table_map} ->
        table_map
        |> Enum.reduce([], fn {_k, v}, acc -> v ++ acc end)
        |> Enum.filter(fn %Thaqqa.Data{} = data -> Thaqqa.Data.get_val(data, @name) != "" end)
        |> Enum.reduce_while([], fn letter, acc ->
          Thaqqa.Regex_Khhyl.Cond.convert(val, letter)
          |> case do
            {:error, msg} -> {:halt, {:error, msg}}
            {:ok, nil} -> {:cont, acc}
            {:ok, false} -> {:cont, acc}
            {:ok, true} -> {:cont, [Thaqqa.Data.get_val(letter, @name) | acc]}
          end
        end)
        |> case do
          {:error, msg} -> {:error, msg}
          otherwize -> "(?:" <> Enum.join(otherwize, "|") <> ")"
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

        if AST.has_astarisk_for_form?(head),
          do:
            translate_sub(
              %AST{type: :S, children: [AST.replace_astarisk_as_form(head) | tail]},
              %Prefab{} = prefab
            ),
          else: translate_brancket_sub("#{Atom.to_string(type)}\\(", children, %Prefab{} = prefab)

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
              %AST{
                type: :S,
                children: [head] ++ tail ++ tail ++ tail
              },
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

  defp translate_sub(%AST{type: :L = type, range: range, children: children}, %Prefab{} = prefab) do
    case argument_number(children) do
      0 -> export_as_string!("(?:S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))", prefab)
      _ -> Error.invalid_argument_num(type, range)
    end
  end

  defp translate_sub(%AST{type: :R, value: val}, %Prefab{} = _prefab),
    do: "R\\(#{val}\\)"

  defp translate_sub(%AST{type: type, range: range, children: children}, %Prefab{} = prefab)
       when type in [:P, :Pd] do
    case argument_number(children) do
      1 -> translate_brancket_sub("#{Atom.to_string(type)}\\(", children, prefab)
      _ -> Error.invalid_argument_num(type, range)
    end
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
