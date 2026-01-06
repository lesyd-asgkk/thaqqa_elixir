defmodule Thaqqa.FontRegistry.Error do
  defexception [:type, :detail, :meta]

  def message(msg) do
    case msg do
      {:error, data} -> data
      _ -> msg
    end
  end

  # 名義衝突
  def nominal_conflict_column(name, op),
    do:
      {:error,
       %__MODULE__{
         type: :conflict,
         detail: :column,
         meta: %{column_name: name, operation: op}
       }}

  # ユニーク行での衝突（※""は例外とする)
  def unique_column_conflict(tablename, column, name, op),
    do:
      {:error,
       %__MODULE__{
         type: :conflict,
         detail: :data,
         meta: %{table_name: tablename, column_name: column, name: name, operation: op}
       }}

  # ユニーク行での衝突（※""は例外とする)
  def column_not_found(tablename, column, name, op),
    do:
      {:error,
       %__MODULE__{
         type: :invalid,
         detail: :not_found,
         meta: %{table_name: tablename, column_name: column, name: name, operation: op}
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
  def edit_locked(column, subtype),
    do:
      {:error,
       %__MODULE__{
         type: :locked,
         detail: :subtype,
         meta: %{column_name: column, subtype: subtype}
       }}

  # precompile用
  def edit_denied(column, subtype),
    do:
      {:error,
       %__MODULE__{
         type: :denied,
         detail: :subtype,
         meta: %{column_name: column, subtype: subtype}
       }}

  def too_many_subject(values, op),
    do:
      {:error,
       %__MODULE__{
         type: :subject,
         detail: :too_many_subjects,
         meta: %{subject_list: values, operation: op}
       }}

  def table_not_found(tablename, fontname \\ nil),
    do:
      {:error,
       %__MODULE__{
         type: :table,
         detail: :notfound,
         meta: %{tablename: tablename, fontname: fontname}
       }}
end
