defmodule Thaqqa.Error do
  def is_thaqqa_error?(%Thaqqa.Render.Error{}), do: true
  def is_thaqqa_error?(%Thaqqa.FontRegistry.Error{}), do: true
  def is_thaqqa_error?(%Thaqqa.Regex_Khhyl.Error{}), do: true
  def is_thaqqa_error?(_), do: false

  def http_status(%Thaqqa.Render.Error{} = err), do: Thaqqa.Render.Error.http_status(err)

  def http_status(%Thaqqa.FontRegistry.Error{} = err),
    do: Thaqqa.FontRegistry.Error.http_status(err)

  def http_status(%Thaqqa.Regex_Khhyl.Error{} = err),
    do: Thaqqa.Regex_Khhyl.Error.http_status(err)

  def to_map(%Thaqqa.Render.Error{} = err), do: Thaqqa.Render.Error.to_map(err)
  def to_map(%Thaqqa.FontRegistry.Error{} = err), do: Thaqqa.FontRegistry.Error.to_map(err)
  def to_map(%Thaqqa.Regex_Khhyl.Error{} = err), do: Thaqqa.Regex_Khhyl.Error.to_map(err)
end
