defmodule Thaqqa.Regex_Khhyl do
  alias Thaqqa.Regex_Khhyl.AST, as: AST

  def normalize(list) when is_list(list), do: normalize_sub(list, [], :syllable)

  def normalize_sub([], acum_all, _), do: Enum.reverse(acum_all)

  # S()系統→Glyph群→Glyphの順に分解。

  # 1層目
  def normalize_sub(list, acum_all, :syllable = current_layer) when is_list(list) do
    [head | tail] = list
    next_layer = :glyph_group

    case head do
      h when h in ["S", "V", "C", "Cd", "Vd", "P", "Pd", "L", "X", "R"] ->
        normalize_branckets(:"#{h}", nil, acum_all, tail, next_layer, current_layer)

      "(" ->
        normalize_branckets(:branket, nil, acum_all, list, current_layer, current_layer)

      "(?:" ->
        normalize_branckets(:branket, :no_match, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        raise "unclosed Branket found: )"

      h when h in ["^", "$", "*", "+", "?"] ->
        normalize_sub(tail, [AST.new(:token, head) | acum_all], current_layer)

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 2..-1)

            normalize_branckets(
              :branket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(tail, [AST.new(:token, head) | acum_all], current_layer)

          true ->
            normalize_sub(tail, [AST.new(:token, head) | acum_all], current_layer)
        end
    end
  end

  # 2層目
  def normalize_sub(list, acum_all, :glyph_group = current_layer) when is_list(list) do
    [head | tail] = list

    next_layer = :glyph

    case head do
      h when h in ["init", "mid", "fin", "sol", "null"] ->
        normalize_sub(tail, [AST.new(:token, head) | acum_all], current_layer)

      "(" ->
        normalize_branckets(:branket, nil, acum_all, list, current_layer, current_layer)

      "(?:" ->
        normalize_branckets(:branket, :no_match, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        raise "unclosed Branket found: )"

      "," ->
        # ,は無視する
        normalize_sub(tail, acum_all, current_layer)

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 2..-1)

            normalize_branckets(
              :branket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(tail, [AST.new(:token, head) | acum_all], current_layer)

          true ->
            # next_layer。(:glyphの場合は未実装)
            normalize_sub(tail, [AST.new(:token, head) | acum_all], current_layer)
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
         list,
         next_layer,
         current_layer,
         branket_nest,
         acum
       )
       when is_list(list) do
    if list == [], do: raise("unclosed Branket found: (")

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
          children = normalize_sub(Enum.reverse(acum), [], next_layer)
          normalize_sub(tail, [AST.new(token, br_val, children) | acum_all], current_layer)
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

  def tokenize(string) when is_binary(string) do
    String.split(
      string,
      ~r/(\[.*?\]|(\(\?<?[=!])|(\(\?(:|<.*?>))|(\{.+?\})|[\(\)\-\,])/,
      include_captures: true
    )
    |> Enum.filter(fn x -> x != "" end)
  end
end

defmodule Thaqqa.Regex_Khhyl.AST do
  defstruct type: nil, value: nil, children: []

  def new(type, value \\ nil, children \\ []) do
    %Thaqqa.Regex_Khhyl.AST{type: type, value: value, children: children}
  end
end
