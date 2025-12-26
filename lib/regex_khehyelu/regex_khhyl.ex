defmodule Thaqqa.Regex_Khhyl.AST do
  # , include: nil
  defstruct type: nil, value: nil, layer: nil, children: [], range: nil

  def new(type, layer, range, value \\ nil, children \\ []) do
    %__MODULE__{type: type, value: value, layer: layer, children: children, range: range}
  end

  def has_astarisk_for_form?(%__MODULE__{value: val, children: children}) do
    if children == [], do: val == "*", else: Enum.any?(children, &has_astarisk_for_form?/1)
  end
end

defmodule Thaqqa.Regex_Khhyl do
  alias Thaqqa.Regex_Khhyl.AST, as: AST
  import Thaqqa.Regex_Khhyl.Error

  def convert!(string) when is_binary(string) do
    case convert(string) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def convert(string) when is_binary(string) do
    case string |> tokenize() |> normalize() do
      {:ok, val} -> translate(val)
      {:error, msg} -> {:error, msg}
    end
  end

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
        {:ok, Enum.join(Enum.reverse(list), " ")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def translate(%AST{} = ast) do
    t = translate_sub(ast)

    case t do
      {:error, msg} -> t
      _ -> {:ok, t}
    end
  end

  def translate_sub(%AST{type: :script, value: val}),
    # 暫定的な処置。todo:scriptパーサ (テーブル実装後になります)
    do: "[" <> val <> "]"

  def translate_sub(%AST{type: :finite, value: val}), do: val

  def translate_sub(%AST{type: :brancket, value: val, children: children}),
    do: "(" <> val <> Enum.map_join(children, "", &translate_sub/1) <> ")"

  # S(*), C(*)のようなvariantをこっちで実装する。
  # *を取り出す方法……？

  def translate_sub(%AST{type: :S = type, children: children, range: range} = ast)
      when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("S((?:init|mid|fin|sol|null),*,*,*)")
    else
      Thaqqa.Regex_Khhyl.Error.invalid_astarisk(type, range)
    end
  end

  def translate_sub(%AST{type: :S = type, children: children, range: range})
      when length(children) == 3 do
    if AST.has_astarisk_for_form?(Enum.at(children, 2)) do
      tail = [Enum.at(children, 1), Enum.at(children, 2)]

      translate_sub(%AST{
        type: :S,
        children: children ++ tail ++ tail
      })
    else
      Thaqqa.Regex_Khhyl.Error.invalid_astarisk(type, range)
    end
  end

  def translate_sub(%AST{type: :V = type, children: children, range: range} = ast)
      when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("V((?:init|mid|fin|sol|null),*)")
    else
      Thaqqa.Regex_Khhyl.Error.invalid_astarisk(type, range)
    end
  end

  def translate_sub(%AST{type: :Vd = type, children: children, range: range} = ast)
      when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("Vd((?:init|mid|fin|sol|null),*)")
    else
      Thaqqa.Regex_Khhyl.Error.invalid_astarisk(type, range)
    end
  end

  def translate_sub(%AST{type: :C = type, children: children, range: range} = ast)
      when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("C((?:onset|coda|null),*)")
    else
      Thaqqa.Regex_Khhyl.Error.invalid_astarisk(type, range)
    end
  end

  def translate_sub(%AST{type: :Cd = type, children: children, range: range} = ast)
      when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("Cd((?:onset|coda|null),*)")
    else
      Thaqqa.Regex_Khhyl.Error.invalid_astarisk(type, range)
    end
  end

  def translate_sub(%AST{type: :S = t, children: children}) when length(children) == 7 do
    if AST.has_astarisk_for_form?(Enum.at(children, 0)) do
      [_, tail] = children
      translate_brancket_sub("#{Atom.to_string(t)}\\((?:init|mid|fin|sol|null)", tail)
    end

    translate_brancket_sub("#{Atom.to_string(t)}\\(", children)
  end

  def translate_sub(%AST{type: :S = t, range: range}),
    do: Thaqqa.Regex_Khhyl.Error.invalid_argument_num(t, range)

  def translate_sub(%AST{type: t, children: children})
      when t in [:V, :Vd] and length(children) == 3 do
    if AST.has_astarisk_for_form?(Enum.at(children, 0)) do
      [_, tail] = children
      translate_brancket_sub("#{Atom.to_string(t)}\\((?:init|mid|fin|sol|null)", tail)
    end

    translate_brancket_sub("#{Atom.to_string(t)}\\(", children)
  end

  def translate_sub(%AST{type: t, children: children})
      when t in [:C, :Cd] and length(children) == 3 do
    if AST.has_astarisk_for_form?(Enum.at(children, 0)) do
      [_, tail] = children
      translate_brancket_sub("#{Atom.to_string(t)}\\((?:onset|coda|null)", tail)
    end

    translate_brancket_sub("#{Atom.to_string(t)}\\(", children)
  end

  def translate_sub(%AST{type: t, range: range})
      when t in [:C, :Cd, :V, :Vd],
      do: Thaqqa.Regex_Khhyl.Error.invalid_argument_num(t, range)

  def translate_sub(%AST{type: :L, children: children}) when length(children) == 0,
    do: convert("(:?S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))")

  def translate_sub(%AST{type: :L = t, range: range}),
    do: Thaqqa.Regex_Khhyl.Error.invalid_argument_num(t, range)

  def translate_sub(%AST{type: :R, value: val}),
    do: "R\\(#{val}\\)"

  def translate_sub(%AST{type: t, children: children})
      when length(children) == 1
      when t in [:P, :Pd],
      do: translate_brancket_sub("#{Atom.to_string(t)}\\(", children)

  def translate_sub(%AST{type: t, range: range})
      when t in [:P, :Pd],
      do: Thaqqa.Regex_Khhyl.Error.invalid_argument_num(t, range)

  def translate_sub(%AST{type: :X = t, children: children}) when length(children) == 3,
    do: translate_brancket_sub("#{Atom.to_string(t)}\\(", children)

  def translate_sub(%AST{type: :X = t, range: range}),
    do: Thaqqa.Regex_Khhyl.Error.invalid_argument_num(t, range)

  def translate_brancket_sub(val, children),
    do: val <> Enum.map_join(children, "", &translate_sub/1) <> "\\)"

  # 処理がやや複雑
  def translate_sub(%AST{type: :token, value: val, layer: :glyph}) do
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

  def translate_sub(%AST{children: children}),
    do: Enum.map_join(children, "", &translate_sub/1)

  def normalize!(list) when is_list(list) do
    case normalize(list) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def normalize(list) when is_list(list) do
    t = normalize_sub(list, [], :sentence)

    case t do
      {:error, msg} -> t
      _ -> {:ok, t}
    end
  end

  def normalize_sub([], acum_all, _), do: Enum.reverse(acum_all)

  # S()系統→Glyph群→Glyphの順に分解。

  # 1層目
  def normalize_sub(list, acum_all, :sentence = current_layer) when is_list(list) do
    [head | tail] = list
    next_layer = :syllable

    case head do
      # S(*),S(form,*) のようなものも実装したい

      h when h in ["S", "V", "C", "Cd", "Vd", "P", "Pd", "L", "X", "R"] ->
        normalize_branckets(:"#{h}", nil, acum_all, tail, next_layer, current_layer)

      # Rは別処理とする

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        Thaqqa.Regex_Khhyl.Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      h when h in ["^", "$", "*", "+", "?", "|", "*?", "+?", "??"] ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
        )

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )

          true ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )
        end
    end
  end

  # 2層目
  def normalize_sub(list, acum_all, :syllable = current_layer) when is_list(list) do
    [head | tail] = list

    _next_layer = :glyph_group

    case head do
      # 形状指定用
      h when h in ["init", "mid", "fin", "sol", "onset", "coda", "null"] ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
        )

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        Thaqqa.Regex_Khhyl.Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      "," ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
        )

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              current_layer,
              1
            )

          # Regex.match?(~r/\{.*?}/, head) ->
          #  "Quantifier {...} is not supported in glyph group layer."

          true ->
            # next_layer。(:glyphの場合は未実装)
            # normalize_glpyh_groupを作る。,か末端までをグループとして扱う。
            normalize_glyph_group(
              acum_all,
              list
            )
        end
    end
  end

  # 3層目
  def normalize_sub(list, acum_all, :glyph_group = current_layer) when is_list(list) do
    [head | tail] = list

    next_layer = :glyph

    case head do
      # 形状指定用

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        Thaqqa.Regex_Khhyl.Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      "-" ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
        )

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )

          true ->
            # next_layer。(:glyphの場合は未実装)
            normalize_sub(
              list,
              [AST.new(:glyph, current_layer, head, nil) | acum_all],
              next_layer
            )
        end
    end
  end

  # 4層目
  def normalize_sub(list, acum_all, :glyph = current_layer) when is_list(list) do
    [head | tail] = list

    # next_layer = :glyph_eval

    case head do
      # 形状指定用
      h when h in ["-+", "-*", "-?", "-+?", "-*?", "-??"] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head, head) | acum_all],
          current_layer
        )

      h when h in ["*", "+", "?", "*?", "+?", "??", "_", "."] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head, head) | acum_all],
          current_layer
        )

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        Thaqqa.Regex_Khhyl.Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      "]" ->
        Thaqqa.Regex_Khhyl.Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              current_layer,
              1
            )

          Regex.match?(~r/^\[.*?\]$/, head) ->
            script = String.slice(head, 1..-1//1)

            normalize_sub(
              tail,
              [AST.new(:script, current_layer, head, script) | acum_all],
              current_layer
            )

          # ↑のように閉じていない場合の処置。
          Regex.match?(~r/^\[.*$/, head) ->
            Thaqqa.Regex_Khhyl.Error.unclosed_brancket_forward(head)

          true ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )
        end
    end
  end

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         list,
         next_layer,
         current_layer,
         branket_nest \\ 0
       ),
       do:
         normalize_branckets(
           token,
           br_val,
           acum_all,
           list,
           next_layer,
           current_layer,
           branket_nest,
           []
         )

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         [],
         next_layer,
         current_layer,
         branket_nest,
         acum
       ),
       do:
         Thaqqa.Regex_Khhyl.Error.unclosed_brancket_forward(
           "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"
         )

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         list,
         next_layer,
         current_layer,
         branket_nest,
         acum
       )
       when is_list(list) do
    [head | tail] = list

    case head do
      "(" ->
        acum = if branket_nest == 0, do: acum, else: [head | acum]

        normalize_branckets(
          token,
          br_val,
          acum_all,
          tail,
          next_layer,
          current_layer,
          branket_nest + 1,
          acum
        )

      ")" ->
        if branket_nest == 1 do
          if token == :R do
            text = Enum.reverse(acum) |> Enum.join("")

            normalize_sub(
              tail,
              [AST.new(token, current_layer, "R(#{text})", text, []) | acum_all],
              current_layer
            )
          else
            children = normalize_sub(Enum.reverse(acum), [], next_layer)
            text = "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"

            normalize_sub(
              tail,
              [AST.new(token, current_layer, text, br_val, children) | acum_all],
              current_layer
            )
          end
        else
          normalize_branckets(
            token,
            br_val,
            acum_all,
            tail,
            next_layer,
            current_layer,
            branket_nest - 1,
            [
              head | acum
            ]
          )
        end

      _ ->
        normalize_branckets(
          token,
          br_val,
          acum_all,
          tail,
          next_layer,
          current_layer,
          branket_nest,
          [head | acum]
        )
    end
  end

  defp normalize_glyph_group(
         acum_all,
         [] = _list,
         acum
       ) do
    children = normalize_sub(Enum.reverse(acum), [], :glyph_group)
    text = Enum.reverse(acum) |> Enum.join("")

    normalize_sub(
      [],
      [AST.new(:glyph_group, :syllable, text, nil, children) | acum_all],
      :syllable
    )
  end

  defp normalize_glyph_group(
         acum_all,
         list,
         acum \\ []
       )
       when is_list(list) do
    [head | tail] = list

    case head do
      "," ->
        children = normalize_sub(Enum.reverse(acum), [], :glyph_group)
        text = Enum.reverse(acum) |> Enum.join("")

        normalize_sub(
          list,
          [AST.new(:glyph_group, :syllable, text, nil, children) | acum_all],
          :syllable
        )

      _ ->
        normalize_glyph_group(
          acum_all,
          tail,
          [head | acum]
        )
    end
  end

  def tokenize(string) when is_binary(string) do
    String.split(
      string,
      ~r/(\[.*?\]|(\(\?<?[=!])|(\(\?(:|<.*?>))|
      ((\{\\d+(,(\\d+)?)?\})\??)|(\-?(\+|\*|\?)\??)|[\(\)\-\,\|])/,
      include_captures: true
    )
    |> Enum.filter(fn x -> x != "" end)
  end
end
