defmodule SVG.Path do
  alias SVG.Point, as: Point

  @moduledoc """
  Documentation for `SVG.Path`.
  """
  # List of %Point{}
  defstruct points: []

  def new(points) when is_list(points) do
    %SVG.Path{points: points}
  end

  def round_values(%SVG.Path{points: points}, decimal_places)
      when is_integer(decimal_places) and decimal_places >= 0 do
    rounded_points = Enum.map(points, fn point -> Point.round_values(point, decimal_places) end)
    %SVG.Path{points: rounded_points}
  end

  def parse_string!(string) when is_binary(string) do
    case parse_string(string) do
      {:ok, path} -> path
      {:error, e} -> raise(e)
    end
  end

  # string -> path
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

    try do
      points =
        Enum.map(str_b, &to_token(&1))
        |> to_point([])

      {:ok, %SVG.Path{points: points}}
    catch
      e -> SVG.Error.message(e)
    end
  end

  defp to_token(value) do
    case Float.parse(value) do
      {num, _} ->
        num

      _ ->
        v = String.to_atom(value)

        if Point.is_legal_command?(v),
          do: v,
          else: throw("Invalid Value found: #{value}")
    end
  end

  defp to_point([], acum, _prev), do: Enum.reverse(acum)
  defp to_point([], acum), do: Enum.reverse(acum)
  defp to_point(list, acum), do: to_point(list, acum, :None)

  defp to_point(list, acum, prev) do
    [head | tail] = list

    case head do
      h when h in [:t, :T, :l, :L] ->
        [val_0, val_1 | rest] = tail
        point = %Point{command: head, x: val_0, y: val_1}
        to_point(rest, [point | acum], head)

      :m ->
        [val_0, val_1 | rest] = tail
        point = %Point{command: head, x: val_0, y: val_1}
        to_point(rest, [point | acum], :l)

      :M ->
        [val_0, val_1 | rest] = tail
        point = %Point{command: head, x: val_0, y: val_1}
        to_point(rest, [point | acum], :L)

      h when h in [:z, :Z] ->
        point = %Point{command: head}
        to_point(tail, [point | acum], :None)

      h when h in [:v, :V] ->
        [val_0 | rest] = tail
        point = %Point{command: head, y: val_0}
        to_point(rest, [point | acum], head)

      h when h in [:h, :H] ->
        [val_0 | rest] = tail
        point = %Point{command: head, x: val_0}
        to_point(rest, [point | acum], head)

      h when h in [:s, :S] ->
        [val_0, val_1, val_2, val_3 | rest] = tail
        point = %Point{command: head, x: val_2, y: val_3, x2: val_0, y2: val_1}
        to_point(rest, [point | acum], head)

      h when h in [:q, :Q] ->
        [val_0, val_1, val_2, val_3 | rest] = tail
        point = %Point{command: head, x: val_2, y: val_3, x1: val_0, y1: val_1}
        to_point(rest, [point | acum], head)

      h when h in [:c, :C] ->
        [val_0, val_1, val_2, val_3, val_4, val_5 | rest] = tail

        point = %Point{
          command: head,
          x: val_4,
          y: val_5,
          x1: val_0,
          y1: val_1,
          x2: val_2,
          y2: val_3
        }

        to_point(rest, [point | acum], head)

      h when h in [:a, :A] ->
        [val_0, val_1, val_2, val_3, val_4, val_5, val_6 | rest] = tail

        point = %Point{
          command: head,
          x: val_5,
          y: val_6,
          rx: val_0,
          ry: val_1,
          angle: val_2,
          laf: val_3,
          sf: val_4
        }

        to_point(rest, [point | acum], head)

      _ ->
        if prev != :None and is_number(head),
          do: to_point([prev | list], acum, :None),
          else: throw("Invalid command found: #{head}")
    end
  end

  # クソ長path用
  def export_as_string_mass!(%SVG.Path{points: points}) do
    points
    |> Task.async_stream(&Point.export_as_string!/1, ordered: true)
    |> Enum.map(fn {:ok, s} -> s end)
    |> Enum.join(" ")
  end

  def export_as_string_mass(%SVG.Path{points: points}) do
    points
    |> Task.async_stream(&Point.export_as_string/1, ordered: true)
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

  def export_as_string!(arg) do
    case export_as_string(arg) do
      {:ok, str} -> str
      {:error, msg} -> raise msg
    end
  end

  # path -> string
  def export_as_string(%SVG.Path{points: points}) do
    try do
      {:ok,
       Enum.map(points, &Point.export_as_string!(&1))
       |> Enum.join(" ")}
    catch
      e -> {:error, e}
    end
  end

  def export_as_string(obj), do: SVG.Error.message("Invalid object found: #{obj}")

  # 重複mの処理
  def defragment_m(%SVG.Path{points: points}) do
    points
    |> Enum.reduce([], fn point, acc ->
      case acc do
        [%{command: c, x: x, y: y} = _prev | rest]
        when c == point.command and c in [:m, :M] ->
          # 連続する m / M を合算
          [Point.add_position(point, x, y) | rest]

        _ ->
          [point | acc]
      end
    end)
    |> Enum.reverse()
    |> new()
  end

  def to_relative(%SVG.Path{points: points} = path),
    do: gather_sub(path, [], List.duplicate(:rel, length(points)))

  def to_absolute(%SVG.Path{points: points} = path),
    do: gather_sub(path, [], List.duplicate(:abs, length(points)))

  def get_border(%SVG.Path{points: points} = path),
    do: gather_sub(path, nil, List.duplicate(:border, length(points)))

  defp gather_sub(%SVG.Path{points: points}, acum, mode),
    do:
      gather_sub(
        points,
        acum,
        mode,
        %{left: :inf, top: :inf, right: :neg_inf, bottom: :neg_inf},
        %{x: 0.0, y: 0.0},
        %{x: nil, y: nil}
      )

  defp gather_sub(%SVG.Path{points: points}, mode),
    do:
      gather_sub(
        points,
        if(mode == :border, do: nil, else: []),
        List.duplicate(mode, length(points)),
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

  defp gather_sub([], acum, [], _, _, _), do: %SVG.Path{points: Enum.reverse(acum)}

  defp gather_sub(
         points,
         acum,
         mode,
         %{left: _l, top: _t, right: _r, bottom: _b} = border,
         %{x: x0, y: y0} = _current_pos,
         %{x: x1, y: y1} = _subpath_start_pos
       ) do
    [head | rest] = points
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

      :abs ->
        gather_sub(
          rest,
          [Point.to_absolute!(head, x0, y0) | acum],
          mode_rest,
          border,
          current_pos,
          subpath_start_pos
        )

      :rel ->
        gather_sub(
          rest,
          [Point.to_relative!(head, x0, y0) | acum],
          mode_rest,
          border,
          current_pos,
          subpath_start_pos
        )
    end
  end

  defp calc_next_coord(command, curr, next),
    do: if(Point.is_relative_command?(command), do: add(curr, next), else: next || curr)

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

  # extract abs or rel.
  def extract_abs_or_rel(%SVG.Path{points: points}) do
    points
    |> Enum.map(fn point ->
      case Point.is_relative_command?(point.command) do
        true -> :rel
        false -> :abs
      end
    end)
  end

  def set_start_position(%SVG.Path{points: points}, x, y) do
    %SVG.Path{
      points: [
        Point.new_m_absolute(x, y)
        | Enum.map(points, fn point ->
            case Point.is_relative_command?(point.command) do
              true -> point
              false -> Point.add_position(point, x, y)
            end
          end)
      ]
    }
  end

  def merge_path_3(%SVG.Path{} = path1, %SVG.Path{} = path2, %SVG.Path{} = path3, x0, y0, x1, y1),
    do:
      merge_path_2(path1, path2, x0, y0)
      |> merge_path_2(path3, x1, y1)

  def merge_path_2(%SVG.Path{} = path1, %SVG.Path{} = path2, x0, y0),
    do: concat_path(path1, set_start_position(path2, x0, y0))

  def concat_path(%SVG.Path{points: points1}, %SVG.Path{points: points2}),
    do: %SVG.Path{points: points1 ++ points2}

  def rescale(%SVG.Path{points: points}, x, y) do
    # default_relorabs = extract_abs_or_rel(%SVG.Path{points: points})
    # path = to_absolute(path)
    points = Enum.map(points, fn point -> Point.multiply_position(point, x, y) end)
    %SVG.Path{points: points}
  end
end
