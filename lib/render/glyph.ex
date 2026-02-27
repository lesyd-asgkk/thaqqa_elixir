# font設定etcは必要ないと判断。

defmodule Thaqqa.Glyph do
  import SVG.Path
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.GlyphManager, as: GlyphManager
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.LetterManager, as: LetterManager
  use Thaqqa.DataTable.Const

  defstruct offset: %{x: 0, y: 0},
            height: %{y0: 0, y1: 0, y2: 0, y3: 0},
            # 頭、母音の頭、母音の尾、尾
            aligment: %{x: 0, y: 0},
            children_glyph_list: [],
            name: %{glyph: "", variant: "", type: "", form: ""},
            font: "",
            path: SVG.Path.parse_string!("m0,0"),
            element_internal: %{is_null: false}

  # element_internalは内部処理で保持しておくと楽な値の一覧。

  # 明らかに肥大化しすぎているので、今後にモジュールの区画化を取り行う

  # relativeな高さにしたい場合の処理。　音節の場合

  def render_with_relative_height(
        %Prefab{} = prefab,
        %__MODULE__{name: %{type: "S"}, font: font, element_internal: %{is_null: true}} = self,
        height,
        vowel_height
      ) do
    nil
  end

  def render_with_relative_height(
        %Prefab{} = prefab,
        %__MODULE__{name: %{type: "S"}, font: font, element_internal: %{is_null: false}} = self,
        height,
        vowel_height
      ) do
    nil
  end

  # そんなことはない場合
  def render_with_relative_height(
        %Prefab{} = prefab,
        %__MODULE__{name: %{type: type}, font: font} = self,
        height,
        vowel_height
      ) do
    nil
  end

  # absoluteな高さにしたい場合の処理。
  # まずは音節の場合から
  def render_with_absolute_height(
        %Prefab{} = prefab,
        %__MODULE__{name: %{type: "S"}, font: font} = self,
        height,
        vowel_height
      ) do
    thickness = Prefab.get_single_data_value(prefab, font, "FONTDATA", "Thickness")
  end

  # その他の場合。
  def render_with_absolute_height(
        %Prefab{} = prefab,
        %__MODULE__{font: font} = self,
        height,
        vowel_height
      ) do
    nil
  end

  ############
  ############
  ############
  ############
  ############
  ############
  ############ ↓まずはここから
  ############

  # path設定
  def set_path(%__MODULE__{name: %{type: "S"}, children_glyph_list: children, path: path} = self) do
    [onset_glyph, vowel_glyph, coda_glyph] =
      Enum.map(children, fn k -> set_path(k) end)
  end

  # S以外の時の設定(再帰処理)
  def set_path(%__MODULE__{name: %{type: type}, children_glyph_list: [], path: path} = self) do
    %{left: _, top: t, right: _, bottom: b} = SVG.Path.get_border(path)
    %__MODULE__{self | height: %{y0: t, y1: t, y2: b, y3: b}}
  end

  def set_path(
        %__MODULE__{
          name: %{type: type, form: form},
          children_glyph_list: children,
          path: top_path
        } = self
      ) do
    top_glyph = %__MODULE__{self | children_glyph_list: []} |> set_path()
    child = Enum.at(children, 0)
    sub_glyph = child |> set_path()

    dir = if type in ["C", "Cd"] and form == "coda", do: -1, else: 1
    off = calc_offset(top_glyph, sub_glyph)
    IO.inspect(off)
    child_path = child.path
    %{left: l, top: t, right: r, bottom: b} = SVG.Path.get_border(child_path)

    off_child_x = dir * (r + l) / 2

    off_child_y = dir * (t + b) / 2

    path_new =
      merge_path_2(
        top_path,
        child_path,
        off_child_x + off.x,
        off_child_y + off.y
      )
      |> to_relative()

    %{left: _, top: t, right: _, bottom: b} = SVG.Path.get_border(path_new)
    %__MODULE__{self | height: %{y0: t, y1: t, y2: b, y3: b}, path: path_new}
  end

  # 無の場合。そのまま初期値のM0,0が帰ります
  def set_path(%__MODULE__{name: %{glyph: "", variant: "", type: "", form: ""}} = self), do: self

  #

  def calc_offset(
        %__MODULE__{name: %{type: type, form: form}, path: top_path} = top_glyph,
        %__MODULE__{offset: sub_offset, aligment: sub_aligment} = sub_glyph
      ) do
    %{left: l, top: t, right: r, bottom: b} = SVG.Path.get_border(top_path)
    dir = if type in ["C", "Cd"] and form == "coda", do: -1, else: 1

    %{
      x:
        l * (1 - sub_aligment.x * dir) / 2 + r * (1 + sub_aligment.x * dir) / 2 +
          sub_offset.x * dir,
      y: t * (1 - sub_aligment.y) / 2 + b * (1 + sub_aligment.y) / 2
    }
  end

  def calc_offset(
        %__MODULE__{} = onset_glyph,
        %__MODULE__{element_internal: %{is_null: true}} = vowel_glyph,
        %__MODULE__{} = coda_glyph
      ) do
  end

  def calc_offset(
        %__MODULE__{} = onset_glyph,
        %__MODULE__{element_internal: %{is_null: false}} = vowel_glyph,
        %__MODULE__{} = coda_glyph
      ) do
  end

  # 単独グリフの場合。
  # create_glyphで用いられている「!系は後々通常verに戻してエラーハンドリングを付け加えるか
  # そもそも「実行時のみに使用Managerに異常がないかを判断する」で対処する。
  defp create_glyph(%Prefab{} = prefab, font, _glyphname, _writing_direction, %{
         "child" => nil,
         "vowel" => nil,
         "onset" => nil,
         "coda" => nil,
         "form" => form,
         "type" => type,
         "name" => name
       }) do
    glyph_name_for_query = name <> if form == "", do: "", else: form
    [name | variant] = Regex.split(~r/([0-9])+/, name, include_captures: true)
    variant = if variant == nil, do: nil, else: variant |> Enum.at(0)
    glyph_name = %{glyph: name, variant: variant, type: type, form: form}

    path =
      GlyphManager.get_glyph!(prefab, font, fn %Thaqqa.Data{} = data ->
        Thaqqa.Data.get_val(data, @name) == glyph_name_for_query
      end)
      |> Enum.at(0)
      |> case do
        nil -> %SVG.Path{}
        data -> Thaqqa.Data.get_val(data, @precompile)
      end

    is_null_vowel =
      LetterManager.get_letter!(prefab, fn %Thaqqa.Data{} = data ->
        Thaqqa.Data.get_val(data, "isNullVowel") == true and
          Thaqqa.Data.get_val(data, @name) == name
      end)
      |> Enum.reduce([], fn {_, v}, acc -> acc ++ v end) != []

    aligment =
      LetterManager.get_letter!(prefab, fn %Thaqqa.Data{} = data ->
        Thaqqa.Data.get_val(data, @name) == name
      end)
      |> Enum.reduce([], fn {_, v}, acc -> acc ++ v end)
      |> Enum.at(0)
      |> case do
        nil ->
          %{x: 0, y: 0}

        data ->
          case {Thaqqa.Data.get_val(data, "x_Align"), Thaqqa.Data.get_val(data, "y_Align")} do
            {nil, _} -> %{x: 0, y: 0}
            {_, nil} -> %{x: 0, y: 0}
            {x, y} -> %{x: x, y: y}
          end
      end

    %__MODULE__{
      offset: %{x: 0, y: 0},
      aligment: aligment,
      path: SVG.Path.new(path),
      children_glyph_list: [],
      font: font,
      name: glyph_name,
      height: %{y0: 0, y1: 0, y2: 0, y3: 0},
      element_internal: %{is_null: is_null_vowel}
    }
  end

  # Sの場合
  defp create_glyph(%Prefab{} = prefab, font, glyphname, writing_direction, %{
         "onset" => onset,
         "vowel" => vowel,
         "coda" => coda,
         "type" => "S" = type,
         "form" => form,
         "name" => name,
         "child" => nil
       }) do
    glyph_name = %{glyph: glyphname, variant: nil, type: type, form: form}

    [onset_glyph, vowel_glyph, coda_glyph] =
      Enum.map([onset, vowel, coda], fn k ->
        new(prefab, font, k, writing_direction)
      end)

    %{x0: off_onset_x, x1: off_coda_x, y0: off_onset_y, y1: off_coda_y} =
      GposManager.gpos!(prefab, font, glyphname, writing_direction, @internal)

    off_onset = %{x: off_onset_x, y: off_onset_y}
    off_coda = %{x: off_coda_x, y: off_coda_y}

    onset_glyph = %__MODULE__{onset_glyph | offset: off_onset}
    coda_glyph = %__MODULE__{coda_glyph | offset: off_coda}
    # pathは空
    # 仮
    %__MODULE__{
      offset: %{x: 0, y: 0},
      aligment: %{x: 0, y: 0},
      path: %SVG.Path{},
      children_glyph_list: [onset_glyph, vowel_glyph, coda_glyph],
      font: font,
      name: glyph_name,
      # ↓ここでは設定しない
      height: %{y0: 0, y1: 0, y2: 0, y3: 0}
    }
  end

  # グリフ列の場合。単純な再帰処理とする

  defp create_glyph(%Prefab{} = prefab, font, glyphname, writing_direction, %{
         "child" => child,
         "type" => type,
         "form" => form,
         "name" => name
       }) do
    # 仮
    top_glyph =
      create_glyph(prefab, font, glyphname, writing_direction, %{
        "type" => type,
        "form" => form,
        "name" => name,
        "child" => nil,
        "vowel" => nil,
        "onset" => nil,
        "coda" => nil
      })

    child_glyph = new(prefab, font, child, writing_direction)

    %{x0: off_x, x1: _, y0: off_y, y1: _} =
      GposManager.gpos!(prefab, font, glyphname, writing_direction, @diacritical)

    offset = %{x: off_x, y: off_y}

    child_glyph = %__MODULE__{child_glyph | offset: offset}

    # pathは空
    # 仮
    %__MODULE__{top_glyph | children_glyph_list: [child_glyph]}
  end

  defp create_glyph(%Prefab{} = _prefab, _font, _glyphname, _writing_direction, %{}),
    do: %__MODULE__{}

  def new(%Prefab{} = prefab, font, glyphname, writing_direction) do
    # 長すぎ、ここも別関数に分けます
    case divide_name(glyphname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, divided_name} ->
        # IO.inspect(divided_name)
        create_glyph(prefab, font, glyphname, writing_direction, divided_name)
    end
  end

  defp divide_name(""), do: {:ok, %{}}
  defp divide_name(_name) when is_nil(_name), do: {:ok, %{}}

  defp set_name(_type, ""), do: nil
  defp set_name(type, glyphname), do: "#{type}(#{glyphname})"
  defp set_name(_type, _form, ""), do: nil
  defp set_name(type, form, glyphname), do: "#{type}(#{form},#{glyphname})"

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
        _k when _k in ["onset", "coda"] ->
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
        _k when _k in ["init", "mid", "fin", "sol"] ->
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
