defmodule Pipehammer.Examples do
  @moduledoc """
  Examples for Pipehammer.
  """

  use Pipehammer

  defmodule Square do
    @moduledoc false
    defstruct w: 0, h: 0
  end

  defmodule Circle do
    @moduledoc false
    defstruct r: 0
  end

  defpipe foo(%Square{} = square, z) do
    {:ok, square.w + square.h + z}
  end

  defpipe foo(%Circle{} = circle, z) do
    {:ok, circle.r + z}
  end

  defpipe bar(%{} = a, b) do
    {:ok, Map.merge(a, %{b: b})}
  end

  defpipe baz(%Square{w: w, h: h}, %Circle{r: r}) do
    {:ok, w * h - 3 * r}
  end

  defpipe add(0, y) do
    {:ok, y}
  end

  defpipe add(x, y) do
    {:ok, x + y}
  end

  defpipe add(x, y, 0) do
    add(x, y)
  end

  defpipe add(x, y, z) do
    {:ok, x + y + z}
  end

  defpipe mul(x, y) do
    {:ok, x * y}
  end

  defpipe safe_div(_x, 0) do
    {:error, :division_by_zero}
  end

  defpipe safe_div(x, y) do
    {:ok, x / y}
  end

  defpipe strange_minus(x, y) do
    if x == y do
      {:error, :x_equals_y}
    else
      {:ok, x - y}
    end
  end

  defpipe exotic_errors(x, y) do
    cond do
      x > y ->
        {:error, {x, "x > y error"}}

      x < y ->
        {:error, {{x, y}, "x < y error"}}

      true ->
        {:error, "x = y error"}
    end
  end

  defpipe ignore_x(_x, y) do
    {:ok, y}
  end

  defpipe ignore_y(x, _y) do
    {:ok, x}
  end

  defpipe destructure_1(%{a: a, b: b}, c) do
    {:ok, a + b + c}
  end

  defpipe destructure_2(x, %{a: a, b: b}) do
    {:ok, x + a + b}
  end

  defpipe partial(x) when is_list(x) do
    {:ok, x}
  end

  defpipe partial2(x, y) when is_number(x) and is_number(y) do
    {:ok, x + y}
  end

  defpipe rec_length([]) do
    {:ok, 0}
  end

  defpipe rec_length([_ | xs]) do
    with {:ok, n} <- rec_length(xs) do
      {:ok, n + 1}
    end
  end
end
