defmodule SVG.Command do
  @moduledoc """
  En
  Documentation for `SVG.Command`.
  ## Structure Definition

      %SVG.Command{
  command: (Atom:CommandType) x: float? y: float? x1: float? y1: float?
  x2: float? y2: float?
  rx: float? ry: float? angle: float? laf: bool sf: bool
  }
  x,y is always the endSVG.Command.

  CommandType contains:
    :m :M :l :L :h :H :v :V :c :C :s :S :q :Q :t :T :a :A :z :Z :None(used for null data).
  otherwize throws error.

  use new_*/1 functions to create SVG.Command.

  　日
  SVG.Commandの作成、操作、文字列出力を行うモジュール。
  %SVG.Command{
  command: (Atom:CommandType) x: float? y: float? x1: float? y1: float?
  x2: float? y2: float?
  rx: float? ry: float? angle: float? laf: bool sf: bool
  }
  x,yは常に終点を示す。（計算の都合が良い）

  CommandTypeは
    :m :M :l :L :h :H :v :V :c :C :s :S :q :Q :t :T :a :A :z :Z :None(空データ用).
  他の値であった場合はエラーを投げる。
  """

  defstruct command: :None,
            x: nil,
            y: nil,
            x1: nil,
            y1: nil,
            x2: nil,
            y2: nil,
            rx: nil,
            ry: nil,
            angle: nil,
            laf: nil,
            sf: nil

  # SVG.Commandを作る関数群

  @doc """
  Returns Null Command
  """
  def new_null(), do: %__MODULE__{command: :None}

  @doc """
  Creates m Command
  """
  def new_m_relative(x, y), do: %__MODULE__{command: :m, x: x, y: y}

  @doc """
  Creates M Command
  """
  def new_m_absolute(x, y), do: %__MODULE__{command: :M, x: x, y: y}

  @doc """
  Creates l Command
  """
  def new_l_relative(x, y), do: %__MODULE__{command: :l, x: x, y: y}

  @doc """
  Creates L Command
  """
  def new_l_absolute(x, y), do: %__MODULE__{command: :L, x: x, y: y}

  @doc """
  Creates h Command
  """
  def new_h_relative(x), do: %__MODULE__{command: :h, x: x}

  @doc """
  Creates H Command
  """
  def new_h_absolute(x), do: %__MODULE__{command: :H, x: x}

  @doc """
  Creates v Command
  """
  def new_v_relative(y), do: %__MODULE__{command: :v, y: y}

  @doc """
  Creates V Command
  """
  def new_v_absolute(y), do: %__MODULE__{command: :V, y: y}

  @doc """
  Creates c Command
  """
  def new_c_relative(x, y, x1, y1, x2, y2),
    do: %__MODULE__{command: :c, x: x, y: y, x1: x1, y1: y1, x2: x2, y2: y2}

  @doc """
  Creates C Command
  """
  def new_c_absolute(x, y, x1, y1, x2, y2),
    do: %__MODULE__{command: :C, x: x, y: y, x1: x1, y1: y1, x2: x2, y2: y2}

  @doc """
  Creates s Command
  """
  def new_s_relative(x, y, x2, y2), do: %__MODULE__{command: :s, x: x, y: y, x2: x2, y2: y2}

  @doc """
  Creates S Command
  """
  def new_s_absolute(x, y, x2, y2), do: %__MODULE__{command: :S, x: x, y: y, x2: x2, y2: y2}

  @doc """
  Creates q Command
  """
  def new_q_relative(x, y, x1, y1), do: %__MODULE__{command: :q, x: x, y: y, x1: x1, y1: y1}

  @doc """
  Creates Q Command
  """
  def new_q_absolute(x, y, x1, y1), do: %__MODULE__{command: :Q, x: x, y: y, x1: x1, y1: y1}

  @doc """
  Creates t Command
  """
  def new_t_relative(x, y), do: %__MODULE__{command: :t, x: x, y: y}

  @doc """
  Creates T Command
  """
  def new_t_absolute(x, y), do: %__MODULE__{command: :T, x: x, y: y}

  @doc """
  Creates a Command
  """
  def new_a_relative(x, y, rx, ry, angle, laf, sf),
    do: %__MODULE__{command: :a, x: x, y: y, rx: rx, ry: ry, angle: angle, laf: laf, sf: sf}

  @doc """
  Creates A Command
  """
  def new_a_absolute(x, y, rx, ry, angle, laf, sf),
    do: %__MODULE__{command: :A, x: x, y: y, rx: rx, ry: ry, angle: angle, laf: laf, sf: sf}

  @doc """
  Returns z Command
  """
  def new_z_relative(), do: %__MODULE__{command: :z}

  @doc """
  Returns Z Command
  """
  def new_z_absolute(), do: %__MODULE__{command: :Z}

  # Commandチェック用の関数群
  @doc """
  Returns the Command has legal command or not
  """
  def has_legal_command?(%__MODULE__{command: command}), do: is_legal_command?(command)

  @doc """
  Returns legal command or not
  """
  def is_legal_command?(command) do
    Enum.member?(
      [:m, :M, :l, :L, :h, :H, :v, :V, :c, :C, :s, :S, :q, :Q, :t, :T, :a, :A, :z, :Z, :None],
      command
    )
  end

  @doc """
  Returns the Command has none command or not
  """
  def has_none?(%__MODULE__{command: command}), do: is_none?(command)

  @doc """
  Returns the Command has z command or not
  """
  def has_z_command?(%__MODULE__{command: command}), do: is_z_command?(command)

  @doc """
  Returns the Command has relative command or not
  """
  def has_relative_command?(%__MODULE__{command: command}), do: is_relative_command?(command)

  @doc """
  Returns the Command has absolute command or not
  """
  def has_absolute_command?(%__MODULE__{command: command}), do: is_absolute_command?(command)

  @doc """
  Returns none command or not
  """
  def is_none?(command), do: command == :None

  @doc """
  Returns z command or not
  """
  def is_z_command?(command), do: Enum.member?([:z, :Z], command)

  @doc """
  Returns relative command or not
  """
  def is_relative_command?(command),
    do: Enum.member?([:m, :l, :h, :v, :c, :s, :q, :t, :a, :z], command)

  @doc """
  Returns absolute command or not
  """
  def is_absolute_command?(command),
    do: Enum.member?([:M, :L, :H, :V, :C, :S, :Q, :T, :A, :Z], command)

  # 絶対値と相対値の交換用
  @doc """
  Convert relative command to absolute one according to specified position.
  If error occurs,  it raises message
  """
  def to_absolute!(%__MODULE__{} = p0, x, y), do: to_absolute!(p0, %{x: x, y: y})

  def to_absolute!(%__MODULE__{} = p0, %{x: _x, y: _y} = coord) do
    case to_absolute(p0, coord) do
      {:ok, point} -> point
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Convert relative command to absolute one according to specified position
  Returns {:ok,val} or {:error,msg}
  """
  def to_absolute(%__MODULE__{} = p0, x, y), do: to_absolute(p0, %{x: x, y: y})

  def to_absolute(%__MODULE__{command: command} = p0, %{x: x, y: y}) do
    if is_legal_command?(command) do
      if is_relative_command?(command),
        do: {:ok, %__MODULE__{add_position(p0, x, y) | command: to_absolute_command(command)}},
        else: {:ok, p0}
    else
      SVG.Error.invalid_command(command)
    end
  end

  @doc """
  Convert absolute command to relative one according to specified position
  If error occurs, it raises message
  """
  def to_relative!(%__MODULE__{} = p0, x, y), do: to_relative!(p0, %{x: x, y: y})

  def to_relative!(%__MODULE__{} = p0, %{x: _x, y: _y} = coord) do
    case to_relative(p0, coord) do
      {:ok, point} -> point
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Convert absolute command to relative one according to specified position
  Returns {:ok,val} or {:error,msg}
  """
  def to_relative(%__MODULE__{} = p0, x, y), do: to_relative(p0, %{x: x, y: y})

  def to_relative(%__MODULE__{command: command} = p0, %{x: x, y: y}) do
    if is_legal_command?(command) do
      if is_absolute_command?(command),
        do: {:ok, %__MODULE__{add_position(p0, -x, -y) | command: to_relative_command(command)}},
        else: {:ok, p0}
    else
      SVG.Error.invalid_command(command)
    end
  end

  defp to_absolute_command(command),
    do: to_string(command) |> String.upcase() |> String.to_atom()

  defp to_relative_command(command),
    do: to_string(command) |> String.downcase() |> String.to_atom()

  # 値を操作する場合に用いる関数群
  @doc """
  adds values of position with null exception handling
  """
  def add_position(%__MODULE__{} = point, dx, dy) do
    %__MODULE__{
      point
      | x: add(point.x, dx),
        y: add(point.y, dy),
        x1: add(point.x1, dx),
        y1: add(point.y1, dy),
        x2: add(point.x2, dx),
        y2: add(point.y2, dy),
        rx: add(point.rx, dx),
        ry: add(point.ry, dy)
    }
  end

  defp add(nil, _d), do: nil
  defp add(v, d), do: v + d

  # 値を操作する場合に用いる関数群
  @doc """
  multiplies values of position with null exception handling
  """
  def multiply_position(%__MODULE__{} = point, dx, dy) do
    %__MODULE__{
      point
      | x: mul(point.x, dx),
        y: mul(point.y, dy),
        x1: mul(point.x1, dx),
        y1: mul(point.y1, dy),
        x2: mul(point.x2, dx),
        y2: mul(point.y2, dy),
        rx: mul(point.rx, dx),
        ry: mul(point.ry, dy)
    }
  end

  defp mul(nil, _d), do: nil
  defp mul(v, d), do: v * d

  def round_values(%__MODULE__{} = point, precision) do
    factor = :math.pow(10, precision)

    fn_round = fn val ->
      if val != nil do
        Float.round(val * factor) / factor
      else
        nil
      end
    end

    %__MODULE__{
      point
      | x: fn_round.(point.x),
        y: fn_round.(point.y),
        x1: fn_round.(point.x1),
        y1: fn_round.(point.y1),
        x2: fn_round.(point.x2),
        y2: fn_round.(point.y2),
        rx: fn_round.(point.rx),
        ry: fn_round.(point.ry)
    }
  end

  @doc """
  Converts Command to binary.
  If error occurs, it raises message
  """
  def export_as_string!(%__MODULE__{} = point) do
    case export_as_string(point) do
      {:ok, str} -> str
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Converts Command to binary.
  Returns {:ok,val} or {:error,msg}
  """

  def export_as_string(%__MODULE__{command: command} = point) do
    if is_legal_command?(command),
      do: {:ok, export_as_string_internal(point)},
      else: SVG.Error.invalid_command(command)
  end

  def export_as_string(_ = object),
    do: SVG.Error.invalid_object(object)

  defp export_as_string_internal(%__MODULE__{command: :m, x: x, y: y}), do: "m #{x},#{y}"
  defp export_as_string_internal(%__MODULE__{command: :M, x: x, y: y}), do: "M #{x},#{y}"
  defp export_as_string_internal(%__MODULE__{command: :l, x: x, y: y}), do: "l #{x},#{y}"
  defp export_as_string_internal(%__MODULE__{command: :L, x: x, y: y}), do: "L #{x},#{y}"
  defp export_as_string_internal(%__MODULE__{command: :h, x: x}), do: "h #{x}"
  defp export_as_string_internal(%__MODULE__{command: :H, x: x}), do: "H #{x}"
  defp export_as_string_internal(%__MODULE__{command: :v, y: y}), do: "v #{y}"
  defp export_as_string_internal(%__MODULE__{command: :V, y: y}), do: "V #{y}"
  defp export_as_string_internal(%__MODULE__{command: :z}), do: "z"
  defp export_as_string_internal(%__MODULE__{command: :Z}), do: "Z"

  defp export_as_string_internal(%__MODULE__{
         command: :c,
         x1: x1,
         y1: y1,
         x2: x2,
         y2: y2,
         x: x,
         y: y
       }),
       do: "c #{x1},#{y1} #{x2},#{y2} #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{
         command: :C,
         x1: x1,
         y1: y1,
         x2: x2,
         y2: y2,
         x: x,
         y: y
       }),
       do: "C #{x1},#{y1} #{x2},#{y2} #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{command: :s, x2: x2, y2: y2, x: x, y: y}),
    do: "s #{x2},#{y2} #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{command: :S, x2: x2, y2: y2, x: x, y: y}),
    do: "S #{x2},#{y2} #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{command: :q, x1: x1, y1: y1, x: x, y: y}),
    do: "q #{x1},#{y1} #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{command: :Q, x1: x1, y1: y1, x: x, y: y}),
    do: "Q #{x1},#{y1} #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{command: :t, x: x, y: y}), do: "t #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{command: :T, x: x, y: y}), do: "T #{x},#{y}"

  defp export_as_string_internal(%__MODULE__{
         command: :a,
         x: x,
         y: y,
         rx: rx,
         ry: ry,
         angle: angle,
         laf: laf,
         sf: sf
       }),
       do: "a #{rx} #{ry} #{angle} #{laf} #{sf} #{x} #{y}"

  defp export_as_string_internal(%__MODULE__{
         command: :A,
         x: x,
         y: y,
         rx: rx,
         ry: ry,
         angle: angle,
         laf: laf,
         sf: sf
       }),
       do: "A #{rx} #{ry} #{angle} #{laf} #{sf} #{x} #{y}"

  @doc """
  list of relative commands
  """

  defmacro list_relative(), do: [:m, :l, :h, :v, :c, :s, :q, :t, :a, :z]

  @doc """
  list of absolute commands
  """
  defmacro list_absolute(), do: [:M, :L, :H, :V, :C, :S, :Q, :T, :A, :Z]
end

defimpl Inspect, for: SVG.Command do
  import Inspect.Algebra

  def inspect(point, opts), do: concat([to_string(point.command), "<", coords(point), ">"])

  defp coords(%{command: command, x: x, y: y, rx: rx, ry: ry, angle: angle, laf: laf, sf: sf})
       when command == :a or command == :A,
       do:
         "x=#{x}, y=#{y} rx=#{rx}, ry=#{ry} angle=#{angle}, large-arc-flag=#{laf}, sweep-flag=#{sf}"

  defp coords(%{command: command, x: x, y: y, x1: x1, y1: y1, x2: x2, y2: y2})
       when command == :c or command == :C,
       do: "x=#{x}, y=#{y} x1=#{x1}, y1=#{y1} x2=#{x2}, y2=#{y2}"

  defp coords(%{command: command, x: x, y: y, x2: x2, y2: y2})
       when command == :s or command == :S,
       do: "x=#{x}, y=#{y} x2=#{x2}, y2=#{y2}"

  defp coords(%{command: command, x: x, y: y, x1: x1, y1: y1})
       when command == :q or command == :Q,
       do: "x=#{x}, y=#{y} x1=#{x1}, y1=#{y1}"

  defp coords(%{command: command}) when command == :z or command == :Z, do: ""

  defp coords(%{command: command, x: x}) when command == :h or command == :H, do: "x=#{x}}"
  defp coords(%{command: command, y: y}) when command == :v or command == :V, do: "y=#{y}"

  defp coords(%{x: x, y: y}), do: "x=#{x}, y=#{y}"
end
