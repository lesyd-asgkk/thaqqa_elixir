defmodule SVG.Error do
  defexception [:type, :detail, :meta]

  def invalid_object(obj),
    do: {:error, %__MODULE__{type: :invalid, detail: :object, meta: %{object: obj}}}

  def invalid_command(cmd),
    do: {:error, %__MODULE__{type: :invalid, detail: :command, meta: %{command: cmd}}}

  def invalid_value(val),
    do: {:error, %__MODULE__{type: :invalid, detail: :value, meta: %{value: val}}}

  def message(str),
    do: {:error, str}

  def message(t, d),
    do: {:error, "SVG error (#{t}): #{inspect(d)}"}

  def message(%{type: t, detail: d}),
    do: {:error, "SVG error (#{t}): #{inspect(d)}"}
end
