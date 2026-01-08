defmodule Thaqqa.FontRegistry.Error do
  defexception [:class, :reason, :meta]

  @type class ::
          :not_found
          | :already_exists
          | :invalid
          | :conflict
          | :locked
          | :forbidden
          | :limit_exceeded
          | :internal

  @type reason ::
          :font
          | :datatable
          | :column
          | :subject
          | :datatype
          | :value_datatype
          | :value_range
          | :unique

  @type t :: %__MODULE__{
          class: atom(),
          reason: atom(),
          meta: map()
        }

  defp error(class, reason, meta \\ %{}),
    do: {:error, %__MODULE__{class: class, reason: reason, meta: meta}}

  def format(%__MODULE__{} = err), do: err

  # 鯖エラー
  def genserver_error(detail),
    do: error(:internal, :genserver, %{detail: detail})

  # 名義衝突
  def nominal_conflict_column(name, op),
    do: error(:already_exists, :column, %{column_name: name, operation: op})

  def nominal_conflict_datatable(name, op),
    do: error(:already_exists, :datatable, %{table_name: name, operation: op})

  def nominal_conflict_font(name, op),
    do: error(:already_exists, :font, %{font_name: name, operation: op})

  # ユニーク行での衝突（※""は例外とする)
  def unique_column_conflict(tablename, column, name, op),
    do:
      error(:conflict, :unique, %{
        table_name: tablename,
        column_name: column,
        name: name,
        operation: op
      })

  def column_not_found(tablename, column, name, op),
    do:
      error(:not_found, :column, %{
        table_name: tablename,
        column_name: column,
        name: name,
        operation: op
      })

  def invalid_datatype(datatype),
    do: error(:invalid, :datatype, %{datatype: datatype})

  def invalid_value_type(value, datatype),
    do: error(:invalid, :datatype, %{value: value, datatype: datatype})

  # :alig_xに2を指定したとか。
  def invalid_value_range(value, type, subtype),
    do: error(:invalid, :value_range, %{value: value, type: type, subtype: subtype})

  # 主にID用
  def edit_locked(column, subtype),
    do: error(:locked, :column, %{column_name: column, subtype: subtype})

  # precompile用
  def edit_forbidden(column, subtype),
    do: error(:forbidden, :column, %{column_name: column, subtype: subtype})

  def too_many_subject(values, op),
    do: error(:limit_exceeded, :subject, %{subject_list: values, operation: op})

  def table_not_found(tablename, fontname \\ nil),
    do: error(:not_found, :datatable, %{table_name: tablename, font_name: fontname})

  def font_not_found(fontname),
    do: error(:not_found, :font, %{font_name: fontname})
end
