defmodule Thaqqa.FontRegistry.Error do
  defexception [:class, :reason, :meta]

  # 何かが存在していない
  @type class ::
          :not_found
          # すでに存在している（重複）
          | :already_exists
          # 値が無効
          | :invalid
          # 重複。already_existsより深刻。
          | :conflict
          # システム的に変更できない(ID系譜とか)
          | :locked
          # 直接弄れない（precompiledとか）
          | :forbidden
          # 変更対象が多すぎ
          | :limit_exceeded
          # ...?
          | :internal

  # フォントが
  @type reason ::
          :font
          # データテーブルが
          | :datatable
          # 列が
          | :column
          # 値が
          | :subject
          # データタイプ自体（無効な型）
          | :datatype
          # サブタイプ自体（同上）
          | :subtype
          # データがタイプに違反している
          | :value_datatype
          # データがサブタイプに違反している
          | :value_range
          # 重複不可な列で重複しています
          | :unique
          # インポート中
          | :import
          # genserverで
          | :genserver

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

  def http_status(%__MODULE__{class: :not_found}), do: 404
  def http_status(%__MODULE__{class: :already_exists}), do: 409
  def http_status(%__MODULE__{class: :conflict}), do: 409
  def http_status(%__MODULE__{class: :invalid}), do: 400
  def http_status(%__MODULE__{class: :forbidden}), do: 403
  def http_status(%__MODULE__{class: :locked}), do: 423
  def http_status(%__MODULE__{class: :limit_exceeded}), do: 429
  def http_status(%__MODULE__{class: :internal}), do: 500
  def http_status(_), do: 500

  def to_map(%__MODULE__{} = err) do
    %{
      error: %{
        responsible: :font,
        class: err.class,
        reason: err.reason,
        meta: err.meta
      }
    }
  end

  defp error(class, reason, meta),
    do: {:error, %__MODULE__{class: class, reason: reason, meta: meta}}

  def format(%__MODULE__{} = err), do: err

  # 鯖エラー
  def genserver_error(detail),
    do: error(:internal, :genserver, %{detail: detail})

  # 名義衝突
  def nominal_conflict_font(name, op),
    do: error(:already_exists, :font, %{font_name: name, operation: op})

  def nominal_conflict_column(name, op),
    do: error(:already_exists, :column, %{column_name: name, operation: op})

  def nominal_conflict_datatable(name, op),
    do: error(:already_exists, :datatable, %{table_name: name, operation: op})

  def filename_conflict_font(name, op),
    do: error(:already_exists, :font, %{file_name: name, operation: op})

  # ユニーク行での衝突（※""は例外とする)
  def unique_column_conflict(tablename, column, name, op),
    do:
      error(:conflict, :unique, %{
        table_name: tablename,
        column_name: column,
        value: name,
        operation: op
      })

  def column_not_found(tablename, column, op),
    do:
      error(:not_found, :column, %{
        table_name: tablename,
        column_name: column,
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

  # 多すぎ 現状未使用
  def too_many_subject(values, op),
    do: error(:limit_exceeded, :subject, %{subject_list: values, operation: op})

  # 何も無い
  def table_not_found(tablename, fontname \\ nil),
    do: error(:not_found, :datatable, %{table_name: tablename, font_name: fontname})

  def font_not_found(fontname),
    do: error(:not_found, :font, %{font_name: fontname})

  def data_not_found(columnname, value, tablename, fontname \\ nil),
    do:
      error(:not_found, :data, %{
        value: value,
        column_name: columnname,
        table_name: tablename,
        font_name: fontname
      })

  def requried_data_not_found(data, tablename),
    do: error(:not_found, :import, %{data: data, table_name: tablename})

  def requried_information_not_found(data, tablename),
    do: error(:not_found, :import, %{data: data, table_name: tablename})

  def requried_status_not_found(status_list),
    do: error(:not_found, :import, %{status_list: status_list})
end
