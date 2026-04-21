defmodule Thaqqa.DataTable.Const do
  # 指定column名
  defmacro __using__(_) do
    quote do
      # トークンの類
      # alphabetは[A-Za-z]+しか受け付けない

      # 予め「ソフトコーディング的」に変更しやすいようにすることで
      # 後の細かい仕様変更にも対応しやすい設計。
      # 実際、:nameの派生で:token()を追加する際に役立った。

      @id_subtype :id
      @unique_subtypes [:name, :id, :token]
      @valid_type [:string, :bool, :float, :int, :volatility]
      @primal_type [:string, :bool, :float, :int]
      # 頻出column名
      @id "ID"
      @name "Name"
      @rawregex "RawRegex"
      @precompile "PreCompile"
      @writing_direction "WritingDirection"
      @language "Language"
      @name_alt "NameAlt"
      @path "Path"
      @gpos_type "GPOSType"
      # table名
      @rootdata "ROOTDATA"
      @fontdata "FONTDATA"

      @vowel "VOWEL"
      @consonant "CONSONANT"
      @punctuation "PUNCTUATION"
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
