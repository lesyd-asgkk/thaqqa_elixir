defmodule SVG.Path do
  alias SVG.Command, as: Command

  @moduledoc """
  Documentation for `SVG.Path`.

  As its name told, it presents path of SVG.
  It contains List of %SVG.Command{} as commands.


  """
  defstruct commands: []

  def new(commands) when is_list(commands) do
    %__MODULE__{commands: commands}
  end

  def new() do
    %__MODULE__{commands: []}
  end

  def round_values(%__MODULE__{commands: commands}, decimal_places)
      when is_integer(decimal_places) and decimal_places >= 0 do
    rounded_commands =
      Enum.map(commands, fn command -> Command.round_values(command, decimal_places) end)

    %__MODULE__{commands: rounded_commands}
  end

  @doc """
  Parses binary into Path Instance.
  If error occurs, it raises message.

  parameter - string(binary)
  returns: %Path
  """
  def parse_string!(string) when is_binary(string) do
    case parse_string(string) do
      {:ok, path} -> path
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Parses binary into Path Instance.
  Returns {:ok,path} or {:error,reason}
  """
  def parse_string(string) when is_binary(string) do
    str_b =
      String.split(
        string,
        ~r/(([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?))|[ZzAaCcQqSsMmLlHhVv, ]/,
        include_captures: true
      )

      # 数字基準で分割する
      # 一旦スペースでくっつける
      |> Enum.join(" ")
      # 空白とコンマを削除する
      |> String.split(~r/(?: |,)/)
      # 空データも削除する
      |> Enum.filter(fn x -> x not in [" ", ""] end)

    case parse_token(str_b) do
      {:ok, list} -> parse_command(list)
      {:error, _} = err -> err
    end
  end

  defp parse_command(list) do
    to_command(list, [], :None)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      {:error, _} = err -> err
    end
  end

  defp parse_token(str_b) do
    Enum.map(str_b, &to_token/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      {:error, _} = err -> err
    end
  end

  defp to_token(value) do
    case Float.parse(value) do
      {float, _} ->
        {:ok, float}

      _ ->
        atom = String.to_atom(value)

        if Command.is_legal_command?(atom),
          do: {:ok, atom},
          else: SVG.Error.invalid_value(value)
    end
  end

  defp to_command([], acum, _prev), do: Enum.reverse(acum)

  defp to_command(list, acum, prev) do
    [head | tail] = list

    case head do
      h when h in [:t, :T, :l, :L] ->
        [val_0, val_1 | rest] = tail
        command = {:ok, %Command{command: head, x: val_0, y: val_1}}
        to_command(rest, [command | acum], head)

      :m ->
        [val_0, val_1 | rest] = tail
        command = {:ok, %Command{command: head, x: val_0, y: val_1}}
        to_command(rest, [command | acum], :l)

      :M ->
        [val_0, val_1 | rest] = tail
        command = {:ok, %Command{command: head, x: val_0, y: val_1}}
        to_command(rest, [command | acum], :L)

      h when h in [:z, :Z] ->
        command = {:ok, %Command{command: head}}
        to_command(tail, [command | acum], :None)

      h when h in [:v, :V] ->
        [val_0 | rest] = tail
        command = {:ok, %Command{command: head, y: val_0}}
        to_command(rest, [command | acum], head)

      h when h in [:h, :H] ->
        [val_0 | rest] = tail
        command = {:ok, %Command{command: head, x: val_0}}
        to_command(rest, [command | acum], head)

      h when h in [:s, :S] ->
        [val_0, val_1, val_2, val_3 | rest] = tail
        command = {:ok, %Command{command: head, x: val_2, y: val_3, x2: val_0, y2: val_1}}
        to_command(rest, [command | acum], head)

      h when h in [:q, :Q] ->
        [val_0, val_1, val_2, val_3 | rest] = tail
        command = {:ok, %Command{command: head, x: val_2, y: val_3, x1: val_0, y1: val_1}}
        to_command(rest, [command | acum], head)

      h when h in [:c, :C] ->
        [val_0, val_1, val_2, val_3, val_4, val_5 | rest] = tail

        command =
          {:ok,
           %Command{
             command: head,
             x: val_4,
             y: val_5,
             x1: val_0,
             y1: val_1,
             x2: val_2,
             y2: val_3
           }}

        to_command(rest, [command | acum], head)

      h when h in [:a, :A] ->
        [val_0, val_1, val_2, val_3, val_4, val_5, val_6 | rest] = tail

        command =
          {:ok,
           %Command{
             command: head,
             x: val_5,
             y: val_6,
             rx: val_0,
             ry: val_1,
             angle: val_2,
             laf: val_3,
             sf: val_4
           }}

        to_command(rest, [command | acum], head)

      _ ->
        if prev != :None and is_number(head),
          do: to_command([prev | list], acum, :None),
          else: SVG.Error.invalid_command(head)
    end
  end

  @doc """
  Converts Path to binary (using async_stream)
  If error occurs, it raises message
  """
  def export_as_string_mass!(%__MODULE__{commands: commands}) do
    commands
    |> Task.async_stream(&Command.export_as_string!/1, ordered: true)
    |> Enum.map(fn {:ok, s} -> s end)
    |> Enum.join(" ")
  end

  @doc """
  Converts Path to binary (using async_stream)
  Returns {:ok,val} or {:error,msg}
  """
  def export_as_string_mass(%__MODULE__{commands: commands}) do
    commands
    |> Task.async_stream(&Command.export_as_string/1, ordered: true)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, str}}, {:ok, acc} ->
        {:cont, {:ok, [str | acc]}}

      {:ok, {:error, reason}}, _acc ->
        {:halt, {:error, reason}}

      {:exit, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, list} ->
        {:ok, Enum.join(Enum.reverse(list), " ")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Converts Path to binary.
  If error occurs, it raises message
  """
  def export_as_string!(arg) do
    case export_as_string(arg) do
      {:ok, str} -> str
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Converts Path to binary.
  Returns {:ok,val} or {:error,msg}
  """
  def export_as_string(%__MODULE__{commands: commands}) do
    Enum.map(commands, &Command.export_as_string/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} ->
        {:cont, {:ok, [str | acc]}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, list} ->
        {:ok, Enum.join(Enum.reverse(list), " ")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Defragments m commands: Compress sequential m/M commands to one m/M command.
  """
  def defragment_m(%__MODULE__{commands: commands}) do
    commands
    |> Enum.reduce([], fn command, acc ->
      case acc do
        [%{command: c, x: x, y: y} = _prev | rest]
        when c == command.command and c in [:m, :M] ->
          # 連続する m / M を合算
          [Command.add_position(command, x, y) | rest]

        _ ->
          [command | acc]
      end
    end)
    |> Enum.reverse()
    |> new()
  end

  @doc """
  Converts every command to relative one.
  """
  def to_relative(%__MODULE__{commands: commands} = path),
    do: gather_sub(path, [], List.duplicate(:relative, length(commands)))

  @doc """
  Converts every command to absolute one.
  """
  def to_absolute(%__MODULE__{commands: commands} = path),
    do: gather_sub(path, [], List.duplicate(:absolute, length(commands)))

  @doc """
  Gets border of path according to commands point. (Not actual border when they contains curve)
  Return type: %{left: l, top: t, right: r, bottom: b}
  """
  def get_border(%__MODULE__{commands: commands} = path),
    do: gather_sub(path, nil, List.duplicate(:border, length(commands)))

  defp gather_sub(%__MODULE__{commands: commands}, acum, mode),
    do:
      gather_sub(
        commands,
        acum,
        mode,
        %{left: :inf, top: :inf, right: :neg_inf, bottom: :neg_inf},
        %{x: 0.0, y: 0.0},
        %{x: nil, y: nil}
      )

  defp gather_sub([], nil, [], %{left: l, top: t, right: r, bottom: b}, _, _),
    do: %{
      left: normalize_float(l),
      top: normalize_float(t),
      right: normalize_float(r),
      bottom: normalize_float(b)
    }

  defp gather_sub([], acum, [], _, _, _), do: %__MODULE__{commands: Enum.reverse(acum)}

  defp gather_sub(
         commands,
         acum,
         mode,
         %{left: _l, top: _t, right: _r, bottom: _b} = border,
         %{x: x0, y: y0} = _current_pos,
         %{x: x1, y: y1} = _subpath_start_pos
       ) do
    [head | rest] = commands
    [mode_head | mode_rest] = mode

    {current_pos, subpath_start_pos, border} =
      case head.command do
        c when c in [:z, :Z] ->
          cp = %{x: x1, y: y1}
          spsp = %{x: nil, y: nil}
          # borderは更新しない
          {cp, spsp, border}

        _ ->
          x0_ = calc_next_coord(head.command, x0, head.x)
          y0_ = calc_next_coord(head.command, y0, head.y)
          cp = %{x: x0_, y: y0_}
          spsp = if head.command in [:m, :M], do: %{x: x0_, y: y0_}, else: %{x: x1, y: y1}
          {cp, spsp, border_comp(border, cp)}
      end

    case mode_head do
      :border ->
        gather_sub(rest, nil, mode_rest, border, current_pos, subpath_start_pos)

      :absolute ->
        gather_sub(
          rest,
          [Command.to_absolute!(head, x0, y0) | acum],
          mode_rest,
          border,
          current_pos,
          subpath_start_pos
        )

      :relative ->
        gather_sub(
          rest,
          [Command.to_relative!(head, x0, y0) | acum],
          mode_rest,
          border,
          current_pos,
          subpath_start_pos
        )
    end
  end

  defp calc_next_coord(command, curr, next),
    do: if(Command.is_relative_command?(command), do: add(curr, next), else: next || curr)

  defp add(nil, d), do: d
  defp add(v, nil), do: v
  defp add(v, d), do: v + d

  defp normalize_float(:neg_inf), do: 0.0
  defp normalize_float(:inf), do: 0.0
  defp normalize_float(f), do: f

  defp border_comp(%{left: l, top: t, right: r, bottom: b}, %{x: x, y: y}) do
    %{left: _min(l, x), top: _min(t, y), right: _max(r, x), bottom: _max(b, y)}
  end

  defp _max(:neg_inf, b), do: b
  defp _max(a, :neg_inf), do: a
  defp _max(a, b), do: max(a, b)

  defp _min(:inf, b), do: b
  defp _min(a, :inf), do: a
  defp _min(a, b), do: min(a, b)

  @doc """
  extracts each of commands are :absolute or :relative.
  """
  def extract_abs_or_rel(%__MODULE__{commands: commands}) do
    commands
    |> Enum.map(fn command ->
      case Command.is_relative_command?(command.command) do
        true -> :relative
        false -> :absolute
      end
    end)
  end

  @doc """
  Sets start position (as M command) and shifts locate of path.
  """
  def set_start_position(%__MODULE__{commands: commands}, x, y) do
    %__MODULE__{
      commands: [
        Command.new_m_absolute(x, y)
        | Enum.map(commands, fn command ->
            case Command.is_relative_command?(command.command) do
              true -> command
              false -> Command.add_position(command, x, y)
            end
          end)
      ]
    }
  end

  @doc """
  Sets end position (as M command)
  """
  def set_end_position(%__MODULE__{commands: commands}, x, y) do
    %__MODULE__{commands: commands ++ [Command.new_m_absolute(x, y)]}
  end

  @doc """
    Merges three pathes into one path.
    x0,y0,x1,y1 specifies offset of path1 or path2。
  """
  def merge_path_3(
        %__MODULE__{} = path0,
        %__MODULE__{} = path1,
        %__MODULE__{} = path2,
        x0,
        y0,
        x1,
        y1
      ),
      do: merge_path_3(path0, path1, path2, %{x: x0, y: y0}, %{x: x1, y: y1})

  def merge_path_3(
        %__MODULE__{} = path0,
        %__MODULE__{} = path1,
        %__MODULE__{} = path2,
        %{x: x0, y: y0},
        %{x: x1, y: y1}
      ),
      do:
        merge_path_2(path0, path1, x0, y0)
        |> merge_path_2(path2, x1, y1)

  @doc """
    Merges two pathes into one path.
    x0,y0 specifies offset of path1
  """
  def merge_path_2(%__MODULE__{} = path0, %__MODULE__{} = path1, x0, y0),
    do: merge_path_2(path0, path1, %{x: x0, y: y0})

  def merge_path_2(%__MODULE__{} = path0, %__MODULE__{} = path1, %{x: x0, y: y0}),
    do: concat_path(path0, set_start_position(path1, x0, y0))

  @doc """
      simply concats two path.
  """
  def concat_path(%__MODULE__{commands: commands0}, %__MODULE__{commands: commands1}),
    do: %__MODULE__{commands: commands0 ++ commands1}

  @doc """
      simply concats list of paths into one path.
  """
  def concat_path(list) when is_list(list),
    do: %__MODULE__{commands: Enum.reduce(list, [], fn l, acc -> acc ++ l end)}

  @doc """
  rescales Path by given multiplier x,y or simply r
  """

  def rescale(%__MODULE__{commands: commands}, %{x: x, y: y}) do
    # default_relorabs = extract_abs_or_rel(%__MODULE__{commands: commands})
    # path = to_absolute(path)
    commands = Enum.map(commands, fn command -> Command.multiply_position(command, x, y) end)
    %__MODULE__{commands: commands}
  end

  def rescale(%__MODULE__{} = path, r), do: rescale(path, %{x: r, y: r})
  def rescale(%__MODULE__{} = path, x, y), do: rescale(path, %{x: x, y: y})
end
