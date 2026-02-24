defmodule Thaqqa.Column do
  defstruct [:name, :type, :desc, :order, :subtype, :dev]

  use Thaqqa.DataTable.Const

  # typeは:string :float :int :boolを取る
  # subtypeは

  # :int ならば :none :non_negative :natural :id :alig_x0 :alig_x1 :alig_y0

  # :alig_x0,:alig_x1,:alig_y0は -1,0,1のみを取る
  # :non_negativeは0以上、:naturalは1以上
  # :idは編集不可
  # :priority,:orderは順序に影響

  # :string ならば :none :name :language :writing_direction :gpos :precompile

  # :gposはinternal,external,kerning,diacriticalのみを,
  # :languageはuniversal,khehyelu,samlhta(それぞれ共通、東果、汽陸)、
  # :writing_directionはuniversal,vertical,horizontal(それぞれ共通、縦、横)のみを取る
  #
  # :nameは重複不可(※空文字に限って重複可)
  # :idは編集不可だし重複も不可

  # :bool ならば :none(特に判定しない)

  # :float ならば :none(特にvariant無し)

  # :volatizie：例外的に全ての値を受け付ける。内部データとして扱われるのみ、jsonとして特別保存はされない（デフォルトの状態では）
  # :path :regexの２種類（いずれも直接編集不可）

  def new(name, type, desc \\ "", order \\ 0, subtype \\ :none, dev \\ false),
    do: %__MODULE__{
      name: name,
      type: type,
      desc: desc,
      order: order,
      subtype: subtype,
      dev: dev
    }

  # rewritable?はシステム上で変更可能
  # editable?はユーザーが編集可能
  def is_editable?(%__MODULE__{subtype: subtype}), do: subtype not in [:path, :regex, :id]
  def is_rewritable?(%__MODULE__{subtype: subtype}), do: subtype not in [:id]
  def is_unique?(%__MODULE__{subtype: subtype}), do: subtype in [:name, :id]

  def is_available_type(type) when is_binary(type),
    do: type in ["string", "float", "int", "bool", "volatility"]

  def is_available_type(type) when is_atom(type),
    do: type in [:string, :float, :int, :bool, :volatility]

  # 初期値設定のため

  def init_val(%__MODULE__{type: type, subtype: subtype}, val) do
    val ||
      case type do
        :string ->
          ""

        :float ->
          0.0

        :int ->
          case subtype do
            :natural -> 1
            :id -> nil
            _ -> 0
          end

        :bool ->
          false

        _ ->
          nil
      end
  end

  def validate(%__MODULE__{} = column, val) do
    cond do
      !is_value_valid?(column, val) ->
        Error.invalid_value_type(val, column.type)

      !is_value_range_valid?(column, val) ->
        Error.invalid_value_range(val, column.type, column.subtype)

      true ->
        :ok
    end
  end

  def is_value_valid?(%__MODULE__{type: type}, val) do
    case type do
      :string -> is_binary(val)
      :float -> is_float(val) || is_integer(val)
      :int -> is_integer(val)
      :bool -> is_boolean(val)
      :volatility -> true
    end
  end

  # :alig_x0,:alig_x1,:alig_y0は -1,0,1のみを取る
  # :non_negativeは0以上、:naturalは1以上

  def adjust_val(%__MODULE__{} = self, val),
    do:
      if(is_value_range_valid?(self, val),
        do: val,
        else: init_val(self, nil)
      )

  def is_value_range_valid?(%__MODULE__{type: :int, subtype: subtype}, val) do
    if !is_integer(val) do
      false
    else
      case subtype do
        h when h in [:alig_x0, :alig_x1, :alig_y0] -> val in [-1, 0, 1]
        :non_negative -> val >= 0
        :natural -> val >= 1
        _ -> true
      end
    end
  end

  def is_value_range_valid?(%__MODULE__{type: :volatility, subtype: subtype}, _val), do: true

  def is_value_range_valid?(%__MODULE__{type: :string, subtype: subtype}, val) do
    if !is_binary(val) do
      false
    else
      case subtype do
        :language -> val in @language_list
        :writing_direction -> val in @writing_direction_list
        :gpos -> val in @gpos_list
        :token -> Regex.match?(~r/^([A-Za-z])*$/, val)
        _ -> true
      end
    end
  end

  def is_value_range_valid?(%__MODULE__{type: type}, val) when type in [:float, :bool] do
    case type do
      :float -> is_float(val) || is_integer(val)
      :bool -> is_boolean(val)
    end
  end

  def is_value_range_valid?(%__MODULE__{type: nil}, _val), do: true
end
