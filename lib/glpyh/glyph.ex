defmodule Thaqqa.Glyph do
  defstruct font: "",
            offset: %{x: 0, y: 0},
            children_glyph_list: [],
            size: 16,
            box: %{left: 0, right: 0, top: 0, bottom: 0, v_top: 0, v_bottom: 0},
            aligment: %{x: 0, y: 0},
            gap: %{top: 0, middle: 0, bottom: 0},
            name: %{fullname: "", type: "", name: "", variant: ""}
end
