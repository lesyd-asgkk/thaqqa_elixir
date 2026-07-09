defmodule Thaqqa.Render.Error do
  defexception [:class, :reason, :meta]

  @type class ::
          :invalid

  @type reason ::
          :type
          | :form
          | :argument_number
          | :syllable
          | :unparsed

  @type t :: %__MODULE__{
          class: atom(),
          reason: atom(),
          meta: map()
        }

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

  def http_status(_), do: 500

  def to_map(%__MODULE__{} = err) do
    %{
      error: %{
        responsible: :render,
        class: err.class,
        reason: err.reason,
        meta: err.meta
      }
    }
  end

  def http_status(%__MODULE__{class: :not_found}), do: 404
  def http_status(%__MODULE__{class: :already_exists}), do: 409
  def http_status(_), do: 500

  defp error(class, reason, meta),
    do: {:error, %__MODULE__{class: class, reason: reason, meta: meta}}

  def format(%__MODULE__{} = err), do: err

  def invalid_form(name),
    do: error(:invalid, :form, %{type: name})

  def invalid_type(name),
    do: error(:invalid, :type, %{type: name})

  def invalid_argument_number(number, required \\ nil),
    do: error(:invalid, :argument_number, %{number: number, required: required})

  def invalid_syllable(pattern),
    do: error(:invalid, :syllable, %{pattern: pattern})

  def unparsed_syllable(pattern),
    do: error(:invalid, :unparsed, %{pattern: pattern})
end
