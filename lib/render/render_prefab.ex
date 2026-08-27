defmodule Thaqqa.Render.Box do
  defstruct top: 0, bottom: 0, left: 0, right: 0
end

defmodule Thaqqa.Render.Coordinate do
  defstruct x: 0, y: 0
end

defmodule Thaqqa.Render.GlyphData do
  alias Thaqqa.Glyph, as: Glyph

  defstruct glyph: %Glyph{},
            new_line: false,
            word_breaker: false,
            prohibit_line_start: false,
            prohibit_line_end: false,
            box: %Thaqqa.Render.Box{},
            gap: %Thaqqa.Render.Box{},
            gap_when_newline: %Thaqqa.Render.Box{},
            coordinate: %Thaqqa.Render.Coordinate{}
end

defmodule Thaqqa.Render.Word do
  # GlyphDataのarray
  defstruct glyph_list: [],
            box: %Thaqqa.Render.Box{}
end

defmodule Thaqqa.Render.Oneline do
  # %Thaqqa.Render.WordPrefab{},
  defstruct word_list: [],
            box: %Thaqqa.Render.Box{}
end

defmodule Thaqqa.Render.Sentence do
  # %Thaqqa.Render.WordPrefab{},
  defstruct oneline_list: [],
            box: %Thaqqa.Render.Box{}

  def parse_sentence(array_of_glyphdata) do
    Enum.chunk_while(
      array_of_glyphdata,
      [],
      fn %Thaqqa.Render.GlyphData{} = glyphdata, acc ->
        if glyphdata.new_line,
          do: {:cont, Enum.reverse([glyphdata | acc]), []},
          else: {:cont, [glyphdata | acc]}
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
    |> Enum.map(fn oneline ->
      Enum.chunk_by(oneline, fn %Thaqqa.Render.GlyphData{} = glyphdata ->
        glyphdata.word_breaker
      end)
    end)
    |> Enum.map(fn oneline ->
      %Thaqqa.Render.Oneline{
        word_list:
          Enum.map(oneline, fn word ->
            %Thaqqa.Render.Word{glyph_list: word, box: %Thaqqa.Render.Box{}}
          end),
        box: %Thaqqa.Render.Box{}
      }
    end)
  end
end
