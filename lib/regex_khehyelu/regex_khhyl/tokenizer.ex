defmodule Thaqqa.Regex_Khhyl.Tokenizer do
  def tokenize(string) when is_binary(string) do
    String.split(
      string,
      ~r/(\[.*?\]|(\(\?<?[=!])|(\(\?(:|<.*?>))|
      ((\{\\d+(,(\\d+)?)?\})\??)|(\-?(\+|\*|\?)\??)|[\(\)\-\,\|])/,
      include_captures: true
    )
    |> Enum.filter(fn x -> x != "" end)
  end
end
