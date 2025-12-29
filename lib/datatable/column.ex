defmodule Thaqqa.Column do
  defstruct [:name, :type, :desc, :order, :subtype, :dev]

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
  # :precompileは直接編集不可（正規表現の事前処理用）
  # :nameは重複不可(※空文字に限って重複可)
  # :idは編集不可

  # :bool ならば :none(特に判定しない)

  # :float ならば :none(特にvariant無し)

  def is_available_type(type) when is_binary(type), do: type in ["string", "float", "int", "bool"]
  def is_available_type(type) when is_atom(type), do: type in [:string, :float, :int, :bool]
end
