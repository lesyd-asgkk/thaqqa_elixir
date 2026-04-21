defmodule Thaqqa.Regex_Khhyl do
  # alias Thaqqa.Regex_Khhyl.AST, as: AST
  # alias Thaqqa.Regex_Khhyl.Error, as: Error
  alias Thaqqa.Regex_Khhyl.Translator, as: Translator
  alias Thaqqa.Regex_Khhyl.Normalizer, as: Normalizer
  alias Thaqqa.Regex_Khhyl.Tokenizer, as: Tokenizer
  alias Thaqqa.FontRegistryPrefab, as: Prefab

  @moduledoc """
  東果文字の処理に適したDSL(正規表現の糖衣構文)を通常の正規表現に変換するModuleである。
  例： S(*) -> S(init,,a0,)やS(mid,t0,a0-sfour0,c0),...など、全てのSyllableを受け付ける

  本DSLは東果文字の内部表現および処理に特化した糖衣構文の提供を目的とする。
  汎用言語を目指すものではない。

  実装の単純性および移植の容易性を重視した仕様とする。

  本DSLは最終的に標準正規表現へと展開される。
  そのため最終的な挙動は実行環境の正規表現エンジンに依存する。
  　本DSLは仕様優先であり、実装はその一例である。

  <グリフ名> := [A-Za-z]+
  <異体字セレクタ> := [0-9]+

  <グリフ> := <グリフ名><異体字セレクタ>
  <ダイアクリティカルを伴う文字> := <素グリフ> (-<素グリフ>)*


  <東果文字(音節)> := S\\(form,onset,vowel,coda\\)

  formはinit(頭系),mid(中系),fin(尾系),sol(単独系),null(内部処理上予約したスロット)及びその組み合わせ((init|mid)や*など)を取る。
  onsetは頭系の子音、codaは尾系の子音、vowelは母音を指定。

  例: S(init,kh0-d0,e0,ng0)でgheng(頭字)

  <東果文字(母音)> :=  V\\(form,vowel\\)
  formはinit(頭系),mid(中系),fin(尾系),sol(単独系),null(内部処理上予約したスロット)を取る。

  vowelは母音。 なお、約物であっても母音のように挿入される（結合及び字形変化を伴う）場合はPではなくVを用いる。

  <東果文字(子音)> := C\\(form,consonant\\)
  formはonset(頭系),coda(中系),null(内部処理上予約したスロット)を取る。
  consonantは子音。

  <東果文字(約物)> := P\\(punctuation\\)
  字形が変化しない約物の表記に用いる。

  <東果文字(母音用ダイアクリティカルマーク)> := Vd\\(form,vowel_diacritial\\)
  <東果文字(子音用ダイアクリティカルマーク)> := Cd\\(form,consonant_diacritical\\)
  <東果文字(約物用ダイアクリティカルマーク)> := Pd\\(punctuation_diacritical\\)
  各々のダイアクリティカルマークだけを表記する場合に用いる。

  また、内部での変換処理を容易にするため、以下の表現を用意している。

  <現実世界の文字> := R\\(letter\\) 現実世界の文字を1文字だけ格納する。
  現実世界の文字から東果文字を変換させる場合、初めに一文字ずつR(*)の形に変換しておく。


  正規表現相応の機能を持つ表現群。

  <汎グリフ名> := .
  <汎異体字セレクタ> := _
  それぞれ全てのグリフ名、全ての異体字を表す。
  　
  　内部上、.は(?:[A-Za-z]+)に, _は(?:[0-9]+)に変換される。


  <条件式グリフ> := [<boolを返す式>]
  条件式に合致する全ての文字を返す。
  <DataTable参照子> _.<VOWEL,CONSONANT,PUNCTUATION,V_DIACRITICAL,C_DIACRITICAL,P_DIACRITICAL TABLEのcolumn名>
  の形でDataTableからcolumnを参照する。
  例えば、母音を表す箇所にて「[_.Name!="a"]_」ならばa以外のあらゆる母音という意味になる。


  　<boolを返す式>は下記の制約を持つ。

  - 使用可能な値型は bool, string, int, float のみ。
  - 使用可能な演算子は ==, !=, >=, <=, >, <, ||, &&, ! のみ。
  - 演算子に優先順位は存在しない。すべて左結合で評価される。
  - 評価順序を変更したい場合は必ず () によって明示すること。
  - 型不一致・未定義値、上記4型以外の値、nilは例外を投げず false として評価される。
  - DataTable参照子は上記の全てのテーブルから条件検索を行うものとする。
  - 不正なテーブル（例：母音のスロットに子音テーブル参照）は除外を行わず、不正なグリフの処理も行わないものとする。
  　- 不正なグリフについてはRender段階で例外を投じる。
  - DSLは閉じており、副作用を持たない。

  　※　bool式用DLSは長大な条件式の記述を想定していない。
  　 そのため演算子優先順位は設けず、例外処理も行わない設計としている。

  <汎素グリフ列> := * | + | ?
  <汎追加グリフ列> := | -* |-+ |-?
  *は0列以上の素グリフ列、+は1列以上の素グリフ列,?は0か1列の素グリフ列を表す。
  -*,-+,-?は以降にそれぞれ0列以上/1列以上/0か1列の任意の素グリフ列が連なることを意味する。

  <東果文字（音節）汎用> := S(*) 東果文字の一音節の範疇のあらゆる一文字を表す。
  内部上は(?:S(*,*,*,*))に変換される。

  <東果文字（音節）形指定汎用> := S(form,*) 東果文字の一音節の範疇で、formが一致するあらゆる一文字を表す。
  内部上は(?:S(form,*,*,*))に変換される。

  C(*) あらゆる子音を表す。
  (?:C(*,*))と等価。

  V(*) あらゆる母音を表す。
  (?:V(*,*))と等価。

  Cd(*) あらゆる子音用ダイアクリティカルマークを表す。
  (?:Cd(*,*))と等価。

  Vd(*) あらゆる母音用ダイアクリティカルマークを表す。
  (?:Vd(*,*))と等価。

  <東果文字汎用> := L() 東果文字の範疇のあらゆる一文字を表す。
  (?:S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))と等価であり、処理上でも変換される。

  Null() 何の文字もないことを表す。一部処理に使用。
  Sep() C,Vなどを音節へと変換する際の処理に使用。

  - 非キャプチャグループ (?:...) や繰り返し指定 {n,m} 等の拡張構文は使用可能とする。
  - 名前付きキャプチャ (?<name>...) や高度な先読み・後読み構文等は、
  実行環境依存性および安定性の観点から使用非推奨とする。

  キャプチャグループに関する注意：

  - khhyl_regex は最終的に標準正規表現へ展開される。
  - キャプチャグループ番号は展開後の正規表現に基づいて決定される。

  - 糖衣構文の展開によって内部的に生成される括弧は、すべて非キャプチャグループ (?:...) とする。
  - そのため、DSL利用者が明示的に記述したキャプチャグループの番号は、展開後も変化しない。
  - 置換文字列におけるグループ参照は、実行環境の正規表現仕様に従う。
  （例：Elixir/Rustでは \1、JavaScriptでは $1 など）
  - 移植性および将来的な保守性を考慮し、明示的なグループは可能な限り (?:...) を用いることを推奨する。




  キャプチャグループ仕様（Thaqqa Module）
  1. 展開後のグループ方針

  DSL展開によって生成されるグループは、すべて非キャプチャグループ (?:...) とする。

  これにより、利用者が記述したキャプチャグループ番号が
  展開処理によって変動しないことを保証する。

  移植性および挙動の安定性の観点から、明示的に (?:...) を使用することを推奨する。

  2. キャプチャグループ保存形式

  キャプチャグループの保存形式は
  Elixir / Rust 標準形式である \g{<number>} を内部表現として使用すること。

  例：

  \g{1}
  \g{2}


  3. キャプチャグループ参照の変換

  実行環境ごとの正規表現仕様差異を吸収するため、
  出力時に各言語仕様へ変換する処理を設けること。


  """
  @letter_list ["S", "V", "C", "Cd", "Vd", "P", "Pd", "Lx", "L", "R", "Sep", "Null"]
  @style_list [
    "Size",
    "Color",
    "Offset",
    "Rotate",
    "Scale",
    "Skew",
    "Font",
    "StrokeWidth",
    "StrokeColor",
    "SetStyle"
  ]

  # 未使用。
  # 一応遺しておくだけ。
  def compile_as_replacement(string) when is_binary(string) do
    prefix_list = Enum.join(@letter_list ++ @style_list, "|")

    regex_list = "((" <> prefix_list <> ")?" <> "\\(.+?\\))|\\\\g\\{.*?\\}"

    {list, _} =
      String.split(
        string,
        Regex.compile!(regex_list),
        include_captures: true
      )
      |> Enum.filter(&(&1 != ""))
      |> Enum.reduce({[], 0}, fn k, {acc, n} ->
        n_str = to_string(n)

        if Regex.match?(~r/\\g\{.*?\}/, k) do
          n_str = to_string(n - 1)
          k_ = if n == 0, do: k, else: "\\g{style" <> n_str <> "}" <> k

          {[k_ | acc], n + 1}
        else
          k_ =
            String.split(k, ~r/,/, include_captures: false)

          k_ =
            case length(k_) do
              1 ->
                [k_glyph] = k_
                [letter] = String.split(k_glyph, ~r/\\\)/, include_captures: false)
                letter <> "\\g{attr" <> n_str <> "}" <> ")"

              2 ->
                [k_form, k_glyph] = k_
                [k_glyph] = String.split(k_glyph, ~r/\\\)/, include_captures: false)
                k_form <> "," <> k_glyph <> "\\g{attr" <> n_str <> "}" <> ")"

              4 ->
                [k_form, k_onset, k_vowel, k_coda] = k_
                [k_coda] = String.split(k_coda, ~r/\\\)/, include_captures: false)

                k_onset_string = k_onset <> "\\g{attronset" <> n_str <> "}"
                k_vowel_string = k_vowel <> "\\g{attrvowel" <> n_str <> "}"
                k_coda_string = k_coda <> "\\g{attrcoda" <> n_str <> "}" <> ")"

                k_form <> "," <> k_onset_string <> "," <> k_vowel_string <> "," <> k_coda_string
            end

          k_ = if n == 0, do: k_, else: "\\g{style" <> n_str <> "}" <> k_

          {[k_ | acc], n + 1}
        end
      end)

    list |> Enum.reverse() |> Enum.join("")
  end

  def compile_as_regex!(string, %Prefab{} = prefab) when is_binary(string),
    do: compile!(string, prefab)

  def compile_as_regex(string, %Prefab{} = prefab) when is_binary(string),
    do: compile(string, prefab)

  def compile!(string, %Prefab{} = prefab) when is_binary(string) do
    case compile(string, prefab) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def compile(string, %Prefab{} = prefab) when is_binary(string) do
    case export(string, prefab) do
      {:ok, val} ->
        Regex.compile(val)

      {:error, _} = err ->
        err
    end
  end

  def compile_as_string!(string, %Prefab{} = prefab) when is_binary(string),
    do: export!(string, prefab)

  def compile_as_string(string, %Prefab{} = prefab) when is_binary(string),
    do: export(string, prefab)

  def export_as_string!(string, %Prefab{} = prefab) when is_binary(string),
    do: export!(string, prefab)

  def export_as_string(string, %Prefab{} = prefab) when is_binary(string),
    do: export(string, prefab)

  def export!(string, %Prefab{} = prefab) when is_binary(string) do
    case export(string, prefab) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def export(string, %Prefab{} = prefab) when is_binary(string) do
    case string |> tokenize() |> normalize() do
      {:ok, val} -> translate(val, prefab)
      {:error, _} = err -> err
    end
  end

  def translate!(ast, %Prefab{} = prefab) when is_list(ast),
    do: Translator.translate!(ast, prefab)

  def translate(ast, %Prefab{} = prefab) when is_list(ast), do: Translator.translate(ast, prefab)

  def normalize!(list) when is_list(list), do: Normalizer.normalize!(list)
  def normalize(list) when is_list(list), do: Normalizer.normalize(list)

  def tokenize(string) when is_binary(string), do: Tokenizer.tokenize(string)
end
