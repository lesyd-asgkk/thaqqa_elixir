# Thaqqa

## Description
**TODO: more description**

複雑な処理を必要とする文字をレンダリングするシステムをバックエンドとして実装したもの。
軽量プロセスと高い並行処理性能を持つBEAM上で動作し、保守性と可読性がより高いElixirを選択。
今後のチーム開発も見据えている。
細かい粒度の処理を独立プロセスに分解し、マルチパイプライン的に並列実行することでスループットを改善した。



## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `thaqqa` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thaqqa, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/thaqqa>.

