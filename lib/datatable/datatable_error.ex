defmodule Thaqqa.FontRegistry.Error do
  defexception [:type, :detail, :meta]

  def message(msg), do: msg

  # 名義衝突
  def nominal_conflict_column(name),
    do:
      {:error,
       %__MODULE__{
         type: :conflict,
         detail: :column,
         meta: %{column_name: name}
       }}

  def nominal_conflict(column, name),
    do:
      {:error,
       %__MODULE__{
         type: :conflict,
         detail: :data,
         meta: %{column_name: column, data_name: name}
       }}

  def invalid_datatype(type),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :datatype,
         meta: %{type: type}
       }}

  def invalid_value_type(value, type),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :value_type,
         meta: %{value: value, type: type}
       }}

  # :alig_xに2を指定したとか。
  def invalid_value_range(value, type, subtype),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :value_range,
         meta: %{value: value, type: type, subtype: subtype}
       }}

  # 主にID用
  def edit_locked(subtype, column),
    do:
      {:error,
       %__MODULE__{
         type: :locked,
         detail: :subtype,
         meta: %{column_name: column, data_name: subtype}
       }}

  # precompile用
  def edit_denied(subtype, column),
    do:
      {:error,
       %__MODULE__{
         type: :denied,
         detail: :subtype,
         meta: %{column_name: column, data_name: subtype}
       }}
end
