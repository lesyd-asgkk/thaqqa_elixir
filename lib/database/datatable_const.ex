defmodule Thaqqa.DataTable.Const do
  # 指定column名
  defmacro __using__(_) do
    quote do
      # 頻出column名
      @id "ID"
      @name "Name"
      @precompile "PreCompile"
      @writing_direction "WritingDirection"
      @language "Language"
      @name_alt "NameAlt"

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

      @universal_language "universal"
      @khehyelu "khehyelu"
      @samlhta "samlhta"
      @language_list [@universal_language, @khehyelu, @samlhta]

      @universal_direction "universal"
      @vertical "vertical"
      @horizontal "horizontal"
      @writing_direction_list [@universal_direction, @vertical, @horizontal]

      @internal "internal"
      @external "external"
      @kerning "kerning"
      @diacritical "diacritical"

      @gpos_list [@internal, @external, @kerning, @diacritical]
    end
  end
end
