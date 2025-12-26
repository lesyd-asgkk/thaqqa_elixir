defmodule Thaqqa.Regex_Khhyl.Error do
  defexception [:type, :detail, :meta]

  def message(msg), do: msg

  # (の方のエラー（括弧が閉じていない）
  def unclosed_brancket_forward(range),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :unclosed_brancket,
         meta: %{direction: :forward, range: range}
       }}

  # )の方のエラー　（括弧が過剰に「閉じている」
  def unclosed_brancket_backward(range),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :unclosed_brancket,
         meta: %{direction: :backward, range: range}
       }}

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
