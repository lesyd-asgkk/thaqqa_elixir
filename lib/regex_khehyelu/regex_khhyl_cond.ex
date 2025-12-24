defmodule Thaqqa.Regex_Khhyl.Cond.AST do
  defstruct type: nil, value: nil, children: []
end

defmodule Thaqqa.Regex_Khhyl.Cond do
  alias Thaqqa.Regex_Khhyl.Cond.AST, as: AST

  # letterは%{a: ...}のような形。

  def convert(string, letter) when is_binary(string) do
    string
    |> tokenize()
    |> normalize()
    |> translate(letter)
  end

  def translate(ast, letter) when is_list(ast), do: translate_sub(ast, letter, [])

  def translate_sub([], _letter, stack) when is_list(stack) and length(stack) == 1,
    do: Enum.at(stack, 0)

  def translate_sub([], _letter, stack) when is_list(stack) and length(stack) != 1,
    do: raise("Invalid stack at end: #{inspect(stack)}")

  def translate_sub(ast, letter, stack) when is_list(ast) do
    [head, tail] = ast
    stack = [translate_sub(head, letter, stack), stack]
    [first, second, third | rest] = stack

    cond do
      third == nil && second == "!" ->
        stack = [!first | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == "&&" ->
        stack = [first && third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == "||" ->
        stack = [first || third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == "==" ->
        stack = [first == third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == "!=" ->
        stack = [first != third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == ">=" ->
        stack = [first >= third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == "<=" ->
        stack = [first <= third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == ">" ->
        stack = [first > third | rest]
        translate_sub(tail, letter, stack)

      third != nil && second == "<" ->
        stack = [first < third | rest]
        translate_sub(tail, letter, stack)

      third != nil ->
        raise "Too many elements in stack: #{inspect(stack)}"

      true ->
        translate_sub(tail, letter, stack)
    end
  end

  def translate_sub(%AST{type: type, value: val, children: children}, letter, _stack)
      when is_map(letter) do
    cond do
      type == :brancket ->
        translate_sub(children, letter, nil)

      type == :underbar ->
        Map.get(letter, val, nil)

      true ->
        val
    end
  end

  def normalize(list) when is_list(list), do: normalize_sub(list, [])

  def normalize_sub([], acum), do: Enum.reverse(acum)

  def normalize_sub([head | tail], acum) when is_list(tail) do
    cond do
      head == "(" ->
        normalize_brancket_sub(tail, acum, 0, [])

      head == ")" ->
        raise "Unmatched closing parenthesis"

      head == "._" ->
        [tail1 | tail2] = tail
        normalize_sub(tail2, [%AST{type: :underbar, value: tail1} | acum])

      true ->
        normalize_sub(tail, [%AST{type: :operator, value: head} | acum])
    end
  end

  def normalize_brancket_sub([], _acum_all, _level, _acum), do: raise("Unclosed brancket")

  def normalize_brancket_sub([head | tail], acum_all, level, acum) when is_list(tail) do
    cond do
      head == "(" ->
        normalize_brancket_sub(tail, acum_all, level + 1, [head | acum])

      head == ")" ->
        if level == 0 do
          acum_rev = Enum.reverse(acum)
          normalized = normalize_sub(acum_rev, [])
          normalize_sub(tail, [%AST{type: :brancket, children: normalized} | acum_all])
        else
          normalize_brancket_sub(tail, acum_all, level - 1, [head | acum])
        end

      true ->
        normalize_brancket_sub(tail, acum_all, level, [head | acum])
    end
  end

  def tokenize(string) when is_binary(string) do
    String.split(
      string,
      ~r/(\(|\)|\|\||&&|==|!=|>=|<=|>|<|!|_.)/,
      include_captures: true
    )
    |> Enum.filter(fn x -> x != "" end)
  end
end
