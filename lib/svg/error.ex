defmodule SVG.Error do
  defexception [:class, :reason, :meta]

  defp error(class, reason, meta \\ %{}),
    do: {:error, %__MODULE__{class: class, reason: reason, meta: meta}}

  def invalid_object(obj),
    do: error(:invalid, :object, %{object: obj})

  def invalid_command(cmd),
    do: error(:invalid, :command, %{command: cmd})

  def invalid_value(val),
    do: error(:invalid, :value, %{value: val})

  def format(%__MODULE__{} = err), do: err
end
