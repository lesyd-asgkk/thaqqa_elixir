defmodule Thaqqa.Glyph.GlyphSpawner do
  import SVG.Path
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.GlyphManager, as: GlyphManager
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.LetterManager, as: LetterManager
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager
  use Thaqqa.DataTable.Const

  def new(%Prefab{} = prefab, fontname, glyphname, writing_direction, size) do
    case divide_name(glyphname) do
      {:error, _} = err ->
        err

      {:ok, divided_name} ->
        create_glyph(prefab, fontname, glyphname, writing_direction, divided_name, size)
    end
  end

  # 単独グリフの場合。
  # create_glyphで用いられている「!系は後々通常verに戻してエラーハンドリングを付け加えるか
  # そもそも「実行時のみに使用Managerに異常がないかを判断する」で対処する。
  defp create_glyph(
         %Prefab{} = prefab,
         fontname,
         glyphname,
         _writing_direction,
         %{
           "child" => nil,
           "vowel" => nil,
           "onset" => nil,
           "coda" => nil,
           "form" => form,
           "type" => type,
           "name" => name
         },
         size
       ) do
    glyph_name_for_query = name <> if form == "", do: "", else: form
    [name | variant] = Regex.split(~r/([0-9])+/, name, include_captures: true)
    variant = if variant == nil, do: nil, else: variant |> Enum.at(0)
    glyph_name = %{glyph: glyphname, variant: variant, type: type, form: form}

    with {:ok, glyph_data} =
           GlyphManager.get_glyph(prefab, fontname, fn %Thaqqa.Data{} = data ->
             Thaqqa.Data.get_value(data, @name) == glyph_name_for_query
           end),
         {:ok, is_null_vowel} =
           ConstRegexManager.match?(prefab, "NullVowel", glyphname),
         {:ok, letter_data} =
           LetterManager.get_letter(prefab, fn %Thaqqa.Data{} = data ->
             Thaqqa.Data.get_value(data, @name) == name
           end),
         {:ok, %{Height: font_height}} = Prefab.get_fontdata(prefab, fontname, ["Height"]) do
      path =
        glyph_data
        |> Enum.at(0)
        |> case do
          nil -> []
          data -> Thaqqa.Data.get_value(data, @precompile)
        end

      aligment =
        letter_data
        |> Enum.reduce([], fn {_, v}, acc -> acc ++ v end)
        |> Enum.at(0)
        |> case do
          nil ->
            %{x: 0, y: 0}

          data ->
            case {Thaqqa.Data.get_value(data, "x_Align"), Thaqqa.Data.get_value(data, "y_Align")} do
              {x, y} when not is_nil(x) and not is_nil(y) -> %{x: x, y: y}
              _ -> %{x: 0, y: 0}
            end
        end

      {:ok,
       %Glyph{
         offset: %{x: 0, y: 0},
         aligment: aligment,
         path: SVG.Path.new(path) |> SVG.Path.rescale(size / font_height),
         children_glyph_list: [],
         font: fontname,
         scale: size / font_height,
         name: glyph_name,
         height: %{y0: 0, y1: 0, y2: 0, y3: 0},
         internal_attribution: %{is_null: is_null_vowel}
       }}
    else
      {:error, _} = err -> err
    end
  end

  # Sの場合
  defp create_glyph(
         %Prefab{} = prefab,
         fontname,
         glyphname,
         writing_direction,
         %{
           "onset" => onset,
           "vowel" => vowel,
           "coda" => coda,
           "type" => "S" = type,
           "form" => form,
           "name" => name,
           "child" => nil
         },
         size
       ) do
    glyph_name = %{glyph: glyphname, variant: nil, type: type, form: form}

    [onset_glyph, vowel_glyph, coda_glyph] =
      Enum.map([onset, vowel, coda], fn k ->
        new(prefab, fontname, k, writing_direction, size)
      end)

    with {:ok, %{x0: off_onset_x, x1: off_coda_x, y0: off_onset_y, y1: off_coda_y}} <-
           GposManager.gpos(prefab, fontname, glyphname, writing_direction, @internal),
         {:ok, %Glyph{} = onset_glyph} <- onset_glyph,
         {:ok, %Glyph{} = vowel_glyph} <- vowel_glyph,
         {:ok, %Glyph{} = coda_glyph} <- coda_glyph,
         {:ok, %{Height: font_height}} = Prefab.get_fontdata(prefab, fontname, ["Height"]) do
      is_null_vowel = vowel_glyph.internal_attribution.is_null

      off_onset = %{x: off_onset_x, y: off_onset_y}
      off_coda = %{x: off_coda_x, y: off_coda_y}

      onset_glyph = %Glyph{onset_glyph | offset: off_onset}
      coda_glyph = %Glyph{coda_glyph | offset: off_coda}
      # pathデータは空
      {:ok,
       %Glyph{
         offset: %{x: 0, y: 0},
         aligment: %{x: 0, y: 0},
         path: %SVG.Path{},
         children_glyph_list: [onset_glyph, vowel_glyph, coda_glyph],
         font: fontname,
         scale: size / font_height,
         name: glyph_name,
         internal_attribution: %{is_null: is_null_vowel},
         # ↓ここでは設定しない
         height: %{y0: 0, y1: 0, y2: 0, y3: 0}
       }}
    else
      {:error, _} = err -> err
    end
  end

  # グリフ列の場合。単純な再帰処理とする

  defp create_glyph(
         %Prefab{} = prefab,
         fontname,
         glyphname,
         writing_direction,
         %{
           "child" => child,
           "type" => type,
           "form" => form,
           "name" => name
         },
         size
       ) do
    # 仮
    top_glyph =
      create_glyph(
        prefab,
        fontname,
        glyphname,
        writing_direction,
        %{
          "type" => type,
          "form" => form,
          "name" => name,
          "child" => nil,
          "vowel" => nil,
          "onset" => nil,
          "coda" => nil
        },
        size
      )

    child_glyph = new(prefab, fontname, child, writing_direction, size)

    with {:ok, %{x0: off_x, x1: _, y0: off_y, y1: _}} <-
           GposManager.gpos(prefab, fontname, glyphname, writing_direction, @diacritical),
         {:ok, %Glyph{} = top_glyph} <- top_glyph,
         {:ok, %Glyph{} = child_glyph} <- child_glyph,
         {:ok, %{Height: font_height}} = Prefab.get_fontdata(prefab, fontname, ["Height"]) do
      offset = %{x: off_x, y: off_y}

      child_glyph = %Glyph{child_glyph | offset: offset}

      glyph_name = %{top_glyph.name | glyph: glyphname}

      {:ok,
       %Glyph{
         top_glyph
         | name: glyph_name,
           children_glyph_list: [child_glyph],
           scale: size / font_height
       }}
    end
  end

  defp create_glyph(%Prefab{} = prefab, fontname, _glyphname, _writing_direction, %{}, size) do
    with {:ok, %{Height: font_height}} =
           Prefab.get_fontdata(prefab, fontname, ["Height"]) do
      {:ok, %Glyph{scale: size / font_height}}
    else
      {:error, _} = err -> err
    end
  end

  defp set_name(_type, ""), do: nil
  defp set_name(type, glyphname), do: "#{type}(#{glyphname})"
  defp set_name(_type, _form, ""), do: nil
  defp set_name(type, form, glyphname), do: "#{type}(#{form},#{glyphname})"

  defp divide_name(""), do: {:ok, %{}}
  defp divide_name(nil), do: {:ok, %{}}

  defp divide_name(name) do
    [type | rest] = Regex.split(~r/[\(\)]/, name)
    [letter_list | _] = rest
    letter = Regex.split(~r/,/, letter_list)
    divide_name_sub(letter, type)
  end

  defp divide_name_sub(letter, "S" = type) do
    if length(letter) != 4 do
      {:error, "仮エラー：argument number error"}
    else
      [form | rest] = letter
      [onset | rest] = rest
      [vowel | coda] = rest

      case form do
        k when k in ["init", "mid", "fin", "sol"] ->
          {:ok,
           %{
             "type" => type,
             "form" => k,
             "name" => letter,
             "onset" => set_name("C", "onset", onset),
             "vowel" => set_name("V", form, vowel),
             "coda" => set_name("C", "coda", coda),
             "child" => nil
           }}

        _ ->
          {:error, "仮エラー: invalid form error"}
      end
    end
  end

  defp divide_name_sub(letter, type) when type in ["Cd", "C"] do
    if length(letter) != 2 do
      {:error, "仮エラー：argument number error"}
    else
      [form | glyph_raw] = letter
      [glyph_top | glyph_list] = Regex.split(~r/-/, glyph_raw |> Enum.at(0))
      glyph_list = set_name("Cd", form, Enum.join(glyph_list, "-"))

      # 再帰的に処理できるように、最初か最初以外に分けたうえで最初以外のものは繋げる
      case form do
        k when k in ["onset", "coda"] ->
          {:ok,
           %{
             "type" => type,
             "form" => form,
             "name" => glyph_top,
             "onset" => nil,
             "vowel" => nil,
             "coda" => nil,
             "child" => glyph_list
           }}

        _ ->
          {:error, "仮エラー: invalid form error"}
      end
    end
  end

  defp divide_name_sub(letter, type) when type in ["Vd", "V"] do
    if length(letter) != 2 do
      {:error, "仮エラー：argument number error"}
    else
      [form | glyph_raw] = letter
      [glyph_top | glyph_list] = Regex.split(~r/-/, glyph_raw |> Enum.at(0))
      glyph_list = set_name("Vd", form, Enum.join(glyph_list, "-"))

      case form do
        k when k in ["init", "mid", "fin", "sol"] ->
          {:ok,
           %{
             "type" => type,
             "form" => form,
             "name" => glyph_top,
             "onset" => nil,
             "vowel" => nil,
             "coda" => nil,
             "child" => glyph_list
           }}

        _ ->
          {:error, "仮エラー: invalid form error"}
      end
    end
  end

  defp divide_name_sub(letter, type) when type in ["Pd", "P"] do
    if length(letter) != 1 do
      {:error, "仮エラー：argument number error"}
    else
      [glyph_top | glyph_list] = Regex.split(~r/-/, letter |> Enum.at(0))
      glyph_list = set_name("Pd", Enum.join(glyph_list, "-"))

      {
        :ok,
        %{
          "type" => type,
          "form" => "",
          "name" => glyph_top,
          "onset" => nil,
          "vowel" => nil,
          "coda" => nil,
          "child" => glyph_list
        }
      }
    end
  end

  defp divide_name_sub(letter, _), do: {:error, "仮エラー：invalid type error"}
end
