defmodule Thaqqa.Regex_Khhyl do
  alias Thaqqa.Regex_Khhyl.AST, as: AST
  alias Thaqqa.Regex_Khhyl.Error, as: Error
  alias Thaqqa.Regex_Khhyl.Translator, as: Translator
  alias Thaqqa.Regex_Khhyl.Normalizer, as: Normalizer
  alias Thaqqa.Regex_Khhyl.Tokenizer, as: Tokenizer

  def compile_as_regex!(string) when is_binary(string), do: compile!(string)
  def compile_as_regex(string) when is_binary(string), do: compile(string)

  def compile!(string) when is_binary(string) do
    case compile(string) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def compile(string) when is_binary(string) do
    case export(string) do
      {:ok, val} -> Regex.compile(val)
      {:error, msg} -> {:error, msg}
    end
  end

  def compile_as_string!(string) when is_binary(string), do: export!(string)
  def compile_as_string(string) when is_binary(string), do: export(string)
  def export_as_string!(string) when is_binary(string), do: export!(string)
  def export_as_string(string) when is_binary(string), do: export(string)

  def export!(string) when is_binary(string) do
    case export(string) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def export(string) when is_binary(string) do
    case string |> tokenize() |> normalize() do
      {:ok, val} -> translate(val)
      {:error, msg} -> {:error, msg}
    end
  end

  def translate!(ast) when is_list(ast), do: Translator.translate!(ast)
  def translate(ast) when is_list(ast), do: Translator.translate(ast)

  def normalize!(list) when is_list(list), do: Normalizer.normalize(list)
  def normalize(list) when is_list(list), do: Normalizer.normalize(list)

  def tokenize(string) when is_binary(string), do: Tokenizer.tokenize(string)
end
