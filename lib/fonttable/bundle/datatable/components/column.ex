defmodule Thaqqa.Column do
  defstruct [:name, :type, :desc, :order, :subtype, :dev]

  use Thaqqa.DataTable.Const
  alias Thaqqa.FontRegistry.Error, as: Error

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

  # editable?はユーザーが編集可能かどうか(volatility枠だとか)
  # rewritable?はシステム上で変更可能かどうか(idはそもそも変更不能)
  # unique?は重複を許さないかどうか
  def is_editable?(%__MODULE__{subtype: subtype}), do: subtype not in @ineditable_subtypes
  def is_rewritable?(%__MODULE__{subtype: subtype}), do: subtype not in @immutable_subtypes
  def is_unique?(%__MODULE__{subtype: subtype}), do: subtype in @unique_subtypes

  # システム上で使用可能なtypeであるかどうか。
  def is_available_type(type) when is_binary(type), do: type in @valid_type_as_string
  def is_available_type(type) when is_atom(type), do: type in @valid_type

  # 初期値設定のための関数。columnに応じた初期値を返す。
  def init_value(%__MODULE__{type: type, subtype: subtype}, value) do
    value ||
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

  # valueがColumnの取りうる値であるかを検査する。問題ないなら:okが帰り、そうでないなら{:error,%Error{}}
  def validate(%__MODULE__{} = column, value) do
    cond do
      !is_value_valid?(column, value) ->
        Error.invalid_value_type(value, column.type)

      !is_value_range_valid?(column, value) ->
        Error.invalid_value_range(value, column.type, column.subtype)

      true ->
        :ok
    end
  end

  # Columnのtypeの取りうる値の範疇のvalueであるかを返す。
  def is_value_valid?(%__MODULE__{type: type}, val) do
    case type do
      :string -> is_binary(val)
      :float -> is_float(val) || is_integer(val)
      :int -> is_integer(val)
      :bool -> is_boolean(val)
      :volatility -> true
    end
  end

  # Columnの取りうるvalueでなかったら初期値を返す。そうでないならそのままvalueを返す。
  def adjust_value(%__MODULE__{} = self, value),
    do:
      if(is_value_range_valid?(self, value),
        do: value,
        else: init_value(self, nil)
      )

  # Columnのtypeとsubtypeの組から取りうる値の範疇のvalueであるかを返す。
  # そもそもintegerであるかどうかを判定した上でsubtypeで判定。
  def is_value_range_valid?(%__MODULE__{type: :int, subtype: subtype}, value) do
    is_integer(value) &&
      case subtype do
        h when h in [:alig_x0, :alig_x1, :alig_y0] -> value in [-1, 0, 1]
        :non_negative -> value >= 0
        :natural -> value >= 1
        _ -> true
      end
  end

  # そもそもbinary(文字列型)であるかどうかを判定した上でsubtypeで判定。
  def is_value_range_valid?(%__MODULE__{type: :string, subtype: subtype}, value) do
    is_binary(value) &&
      case subtype do
        :language -> value in @language_list
        :writing_direction -> value in @writing_direction_list
        :gpos -> value in @gpos_list
        :token -> Regex.match?(~r/^([A-Za-z])*$/, value)
        _ -> true
      end
  end

  def is_value_range_valid?(%__MODULE__{type: :float}, val), do: is_float(val) || is_integer(val)

  def is_value_range_valid?(%__MODULE__{type: :bool}, val), do: is_boolean(val)

  def is_value_range_valid?(%__MODULE__{type: nil}, _), do: true

  def is_value_range_valid?(%__MODULE__{type: :volatility}, _), do: true
end
