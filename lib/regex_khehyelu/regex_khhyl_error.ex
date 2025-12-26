defmodule Thaqqa.Regex_Khhyl.Error do
  defexception [:type, :detail, :meta]

  def message(msg), do: msg

  def unclosed_brancket_forward(range),
    do:
      {:error,
       %__MODULE__{type: :invalid, detail: :unclosed_brancket, meta: %{range: range, rest: nil}}}

  # )の方のエラー　
  def unclosed_brancket_backward(rest),
    do:
      {:error,
       %__MODULE__{type: :invalid, detail: :unclosed_brancket, meta: %{range: nil, rest: rest}}}

  def invalid_stack_at_end(stack),
    do: {:error, %__MODULE__{type: :invalid, detail: :stack_at_end, meta: %{stack: stack}}}

  def too_many_elements_in_stack(stack),
    do: {:error, %__MODULE__{type: :invalid, detail: :too_many_elements, meta: %{stack: stack}}}

  def invalid_argument_num(type, range),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :argument_num,
         meta: %{type: type, range: range}
       }}

  def invalid_astarisk(type, range),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :asterisk,
         meta: %{type: type, range: range}
       }}

  def too_many_elements_in_stack(stack),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :too_many_elements,
         meta: %{stack: Enum.reverse(stack)}
       }}
end
