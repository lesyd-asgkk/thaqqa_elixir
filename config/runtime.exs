env_path = Path.expand("../.env", __DIR__)

File.read!(env_path)
|> Dotenvy.Parser.parse()
|> case do
  {:ok, data} ->
    Enum.each(data, fn
      {k, v} ->
        System.put_env(k, v)

      {:error, _} ->
        nil
    end)
end
