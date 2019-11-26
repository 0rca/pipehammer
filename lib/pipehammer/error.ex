defmodule Pipehammer.Error do
  @moduledoc """
  Opt-in macros for simpler error construction and matching.
  It works with Pipehammer error handler, too.

  ```
  """

  @type error(e) :: {:error, e}
  @type error(e, a) :: {:error, {e, a}}
  @type error(e, a, b) :: {:error, {e, a, b}}
  @type error(e, a, b, c) :: {:error, {e, a, b, c}}
  @type error(e, a, b, c, d) :: {:error, {e, a, b, c, d}}

  defmacro error(e) do
    quote do
      {:error, unquote(e)}
    end
  end

  defmacro error(e, a) do
    quote do
      {:error, {unquote(e), unquote(a)}}
    end
  end

  defmacro error(e, a, b) do
    quote do
      {:error, {unquote(e), unquote(a), unquote(b)}}
    end
  end

  defmacro error(e, a, b, c) do
    quote do
      {:error, {unquote(e), unquote(a), unquote(b), unquote(c)}}
    end
  end

  defmacro error(e, a, b, c, d) do
    quote do
      {:error, {unquote(e), unquote(a), unquote(b), unquote(c), unquote(d)}}
    end
  end

  defmacro __using__(_) do
    quote do
      import Pipehammer.Error
    end
  end
end
