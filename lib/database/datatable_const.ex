defmodule Thaqqa.DataTable.Const do
  # 指定column名
  defmacro __using__(_) do
    quote do
      # 頻出column名
      @id "ID"
      @name "Name"
      @precompile "PreCompile"

      # table名
      @rootdata "ROOTDATA"

      @vowel "VOWEL"
      @consonant "CONSONANT"
      @punctuation "PUCTUATION"
      @diacritic_v "DIACRITIC_V"
      @diacritic_c "DIACRITIC_C"
      @diacritic_p "DIACRITIC_P"
      @lettertable_list [
        @vowel,
        @consonant,
        @punctuation,
        @diacritic_v,
        @diacritic_c,
        @diacritic_p
      ]

      @gsub "GSUB"
      @parser "PARSER"
      @gpos "GPOS"

      @unique_gsub "UniqueGSUB"
      @glyph "GLYPH"
      @fontdata "FONTDATA"

      # 指定された値
      @universal "universal"
      @khehyelu "khehyelu"
      @samlhta "samlhta"
      @language_list [@universal, @khehyelu, @samlhta]

      @vertical "vertical"
      @horizontal "horizontal"
      @writing_direction_list [@universal, @vertical, @horizontal]

      @internal "internal"
      @external "external"
      @kerning "kerning"
      @diacritical "diacritical"

      @gpos_list [@internal, @external, @kerning, @diacritical]
    end
  end
end
