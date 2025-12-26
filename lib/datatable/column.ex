defmodule Thaqqa.Column do
  defstruct [:name, :type, :desc, :order, :subtype, :dev]

  def is_available_type(type) do
    case type do
      h when h in ["char", "float", "INTEGER", "bool"] -> true
      _ -> false
    end
  end
end
