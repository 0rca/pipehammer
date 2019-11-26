defmodule Pipehammer.Maybe do
  @moduledoc """
  Wrappers for turning `nil` and structs to result tuples.
  """

  def from_maybe(nil, e), do: {:error, e}
  def from_maybe(x, _), do: {:ok, x}

  def assert_struct(module, %module{} = r, _), do: {:ok, r}
  def assert_struct(_, _, e), do: {:error, e}

  defmacro __using__(_) do
    quote do
      import Pipehammer.Maybe
    end
  end
end
