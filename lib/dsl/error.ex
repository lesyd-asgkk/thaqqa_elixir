defmodule Thaqqa.Regex_Khhyl.Error do
  defexception [:class, :detail, :meta]

  @impl true
  def message(%{class: class, reason: reason, meta: meta}) do
    base = "#{reason}: #{class}"

    case meta do
      %{} = m when map_size(m) > 0 ->
        base <> " " <> inspect(m)

      _ ->
        base
    end
  end

  def http_status(%__MODULE__{class: :invalid}), do: 400
  def http_status(_), do: 500

  def to_map(%__MODULE__{} = err) do
    %{
      error: %{
        responsible: :dsl,
        class: err.class,
        reason: err.reason,
        meta: err.meta
      }
    }
  end

  # (の方のエラー（括弧が閉じていない）
  def unclosed_brancket_forward(range),
    do:
      {:error,
       %__MODULE__{
         class: :invalid,
         detail: :unclosed_brancket,
         meta: %{direction: :forward, range: range}
       }}

  # )の方のエラー　（括弧が過剰に「閉じている」
  def unclosed_brancket_backward(range),
    do:
      {:error,
       %__MODULE__{
         class: :invalid,
         detail: :unclosed_brancket,
         meta: %{direction: :backward, range: range}
       }}

  def invalid_stack_at_end(stack),
    do: {:error, %__MODULE__{class: :invalid, detail: :stack_at_end, meta: %{stack: stack}}}

  def invalid_argument_num(class, range),
    do:
      {:error,
       %__MODULE__{
         class: :invalid,
         detail: :argument_num,
         meta: %{class: class, range: range}
       }}

  def invalid_astarisk(class, range),
    do:
      {:error,
       %__MODULE__{
         class: :invalid,
         detail: :asterisk,
         meta: %{class: class, range: range}
       }}

  def too_many_elements_in_stack(stack),
    do:
      {:error,
       %__MODULE__{
         class: :invalid,
         detail: :too_many_elements,
         meta: %{stack: Enum.reverse(stack)}
       }}
end
