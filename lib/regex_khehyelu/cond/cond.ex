defmodule Thaqqa.Regex_Khhyl.Cond.AST do
  defstruct type: nil, value: nil, children: []

  def get_value(%__MODULE__{value: value}), do: value

  def is_ast?(%__MODULE__{}), do: true
  def is_ast?(_), do: false
end

defmodule Thaqqa.Regex_Khhyl.Cond do
  alias Thaqqa.Regex_Khhyl.Cond.AST, as: AST
  alias Thaqqa.Regex_Khhyl.Error, as: Error

  alias Thaqqa.Data, as: Data

  def convert!(string, %Data{} = letter_data) when is_binary(string) do
    case convert(string, letter_data) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def convert(string, %Data{} = letter_data) when is_binary(string) do
    case string |> tokenize() |> normalize() do
      {:ok, val} -> translate(val, letter_data)
      {:error, _} = err -> err
    end
  end

  def translate!(ast, %Data{} = letter_data) when is_list(ast) do
    case translate(ast, letter_data) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def translate(ast, %Data{} = letter_data) when is_list(ast) do
    t = translate_sub(ast, letter_data, [])

    case t do
      {:error, _reason} -> t
      _ -> {:ok, t}
    end
  end

  def translate_sub([], _letter, stack) when is_list(stack) and length(stack) == 1,
    do: Enum.at(stack, 0)

  def translate_sub([], letter, stack) when is_list(stack) and length(stack) != 1,
    do: Error.invalid_stack_at_end(stack)

  #

  def translate_sub(ast, %Data{} = letter_data, stack) when is_list(ast) do
    [head | tail] = ast
    stack = [translate_sub(head, letter_data, []) | stack]
    translate_calc(tail, letter_data, stack)
  end

  def translate_calc(tail, %Data{} = letter_data, stack) when is_list(tail) do
    first = Enum.at(stack, 0, nil)
    second = Enum.at(stack, 1, nil)
    third = Enum.at(stack, 2, nil)

    rest_alt = Enum.slice(stack, 2..-1//1)
    rest = Enum.slice(stack, 3..-1//1)

    first = if AST.is_ast?(first), do: AST.get_value(first), else: first
    second = if AST.is_ast?(second), do: AST.get_value(second), else: second
    third = if AST.is_ast?(third), do: AST.get_value(third), else: third

    # a == !b のようなとき
    # [!,==,a]の時点では演算しない
    # [b,!,==,a]の時に演算する
    if first != "!" do
      case second do
        "!" ->
          stack = [!first | rest_alt]
          translate_calc(tail, letter_data, stack)

        "&&" ->
          stack = [first && third | rest]
          translate_calc(tail, letter_data, stack)

        "||" ->
          stack = [first || third | rest]
          translate_calc(tail, letter_data, stack)

        "==" ->
          stack = [first == third | rest]
          translate_calc(tail, letter_data, stack)

        "!=" ->
          stack = [first != third | rest]
          translate_calc(tail, letter_data, stack)

        ">=" ->
          stack = [first >= third | rest]
          translate_calc(tail, letter_data, stack)

        "<=" ->
          stack = [first <= third | rest]
          translate_calc(tail, letter_data, stack)

        ">" ->
          stack = [first > third | rest]
          translate_calc(tail, letter_data, stack)

        "<" ->
          stack = [first < third | rest]
          translate_calc(tail, letter_data, stack)

        _ ->
          translate_sub(tail, letter_data, stack)
      end
    else
      translate_sub(tail, letter_data, stack)
    end
  end

  def translate_sub(
        %AST{type: type, value: val, children: children} = _ast,
        %Data{} = letter_data,
        _stack
      ) do
    cond do
      type == :brancket ->
        translate_sub(children, letter_data, [])

      type == :underbar ->
        # int string bool float 以外は受け付けない
        # 現状、他の値が飛んできた場合は無条件でfalseにする
        # nilとか特にそう（「なるわけがない」）
        # string == boolみたいなものも演算式として例外判定にしない。
        # というのも、本モジュールは長文を想定していない為。
        value = Data.get_value(letter_data, val)

        if is_integer(value) || is_float(value) || is_boolean(value) || is_binary(value),
          do: value,
          else: false

      true ->
        val
    end
  end

  def normalize!(list) when is_list(list) do
    case normalize(list) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def normalize(list) when is_list(list) do
    t = normalize_sub(list, [])

    case t do
      {:error, _reason} -> t
      _ -> {:ok, t}
    end
  end

  def normalize_sub([], acum), do: Enum.reverse(acum)

  def normalize_sub([head | tail], acum) when is_list(tail) do
    cond do
      head == "(" ->
        normalize_brancket_sub(tail, acum, 0, [])

      head == ")" ->
        Error.unclosed_brancket_backward([head | tail] |> Enum.join(""))

      head == "_." ->
        [tail1 | tail2] = tail
        normalize_sub(tail2, [%AST{type: :underbar, value: tail1} | acum])

      head in ["!", "||", "&&", "==", "<=", ">=", ">", "<"] ->
        normalize_sub(tail, [%AST{type: :operator, value: head} | acum])

      head in ["true", "false"] ->
        normalize_sub(tail, [%AST{type: :bool, value: head} | acum])

      true ->
        cond do
          Regex.match?(~r/^\"([A-Za-z]*)\"/, head) ->
            name = String.slice(head, 1..-2//1)
            normalize_sub(tail, [%AST{type: :string, value: name} | acum])

          Regex.match?(~r/^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/, head) ->
            normalize_sub(tail, [%AST{type: :number, value: head} | acum])

          true ->
            normalize_sub(tail, [%AST{type: :bool, value: head} | acum])
        end
    end
  end

  def normalize_brancket_sub([], _acum_all, _level, acum),
    do: Error.unclosed_brancket_forward(Enum.reverse(acum) |> Enum.join(""))

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
    string
    |> String.split(~r/ /)
    |> Enum.join("")
    |> String.split(
      ~r/(\(|\)|\|\||&&|==|!=|>=|<=|>|<|!|_.)/,
      include_captures: true
    )
    |> Enum.filter(fn x -> x != "" end)
  end
end
