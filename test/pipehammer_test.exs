defmodule PipehammerTest do
  use ExUnit.Case

  use Pipehammer
  use Pipehammer.Error
  use Pipehammer.Maybe

  alias Pipehammer.Examples.Circle
  alias Pipehammer.Examples.Square

  import Pipehammer.Examples

  test "add/2" do
    assert add(2, 2) == {:ok, 4}
    assert add({:ok, 2}, 2) == {:ok, 4}
    assert add({:error, :foo}, 2) == {:error, :foo}
    assert_raise ArithmeticError, fn -> add(nil, 2) end
  end

  test "add/3" do
    assert add(1, 1, 1) == {:ok, 3}
    assert add({:ok, 1}, 1, 1) == {:ok, 3}
    assert add({:error, :foo}, 1, 1) == {:error, :foo}
    assert_raise ArithmeticError, fn -> add(nil, 1, 1) end
  end

  test "safe_div/2" do
    assert safe_div({:error, :not_a_number}, 0) == {:error, :not_a_number}
    assert safe_div(4, 2) == {:ok, 2}
    assert safe_div(4, 0) == {:error, :division_by_zero}
    assert {:ok, 2} = safe_div(1, 0) <|> safe_div(2, 0) <|> safe_div(3, 0) <|> add(1, 1)
    # it still crashes if an argument is invalid
    assert_raise ArithmeticError, fn ->
      safe_div(nil, 16)
    end
  end

  test "mul/2" do
    assert mul(2, 2) |> safe_div(0) |> add(2) == {:error, :division_by_zero}
    assert mul(2, 2) |> safe_div(2) |> add(40) == {:ok, 42}
  end

  test "strange_minus/2" do
    assert strange_minus(2, 1) == {:ok, 1}
    assert strange_minus(1, 1) == {:error, :x_equals_y}
    assert strange_minus({:ok, 1}, 2) == {:ok, -1}
    assert strange_minus({:error, :foo}, 2) == {:error, :foo}
  end

  test "exotic_errors/2" do
    assert exotic_errors(10, 1) == {:error, {10, "x > y error"}}
    assert exotic_errors(1, 10) == {:error, {{1, 10}, "x < y error"}}
    assert exotic_errors(1, 1) == {:error, "x = y error"}
  end

  test "handle_error/2" do
    {:error, "some error"}
    |> handle_error(fn msg ->
      assert msg == "some error"
    end)

    {:error, {:foo, :bar}}
    |> handle_error(fn {a, b} ->
      assert a == :foo
      assert b == :bar
    end)

    # it destructures the error, macro style
    {:error, {:foo, :bar}}
    |> case do
      error(foo, bar) ->
        assert foo == :foo
        assert bar == :bar
    end

    # it matches the whole tuple, too
    {:error, {:foo, :bar}}
    |> case do
      error({foo, bar}) ->
        assert foo == :foo
        assert bar == :bar
    end

    # full-macro variant
    error(:foo, :bar)
    |> case do
      error(foo, bar) ->
        assert foo == :foo
        assert bar == :bar
    end
  end

  test "foo/2" do
    assert foo(%Square{w: 1, h: 2}, 3) == {:ok, 6}
    assert foo({:ok, %Square{w: 1, h: 2}}, 3) == {:ok, 6}

    assert foo(%Circle{r: 1}, 4) == {:ok, 5}

    assert_raise FunctionClauseError, fn ->
      foo(%{x: 1, y: 2}, 3)
    end
  end

  test "bar/2" do
    assert bar(%{a: 1, b: 2}, 20) == {:ok, %{a: 1, b: 20}}
    assert bar({:ok, %{a: 1, b: 2}}, 20) == {:ok, %{a: 1, b: 20}}
    assert bar({:error, :foo}, 3) == {:error, :foo}
  end

  test "from_maybe/2" do
    assert from_maybe(nil, :null_pointer_exception) == {:error, :null_pointer_exception}
    assert from_maybe(42, :null_pointer_exception) == {:ok, 42}
  end

  test "assert_struct/3" do
    assert assert_struct(Circle, %Square{}, :not_a_circle_exception) ==
             {:error, :not_a_circle_exception}

    assert assert_struct(Circle, %Circle{}, :not_a_circle_exception) == {:ok, %Circle{}}
  end

  test "destructure/1" do
    assert destructure_1(%{a: 1, b: 1}, 1) == {:ok, 3}
    assert destructure_1({:ok, %{a: 1, b: 1}}, 1) == {:ok, 3}
    assert destructure_1({:error, :foo}, 1) == {:error, :foo}
  end

  test "destructure/2" do
    assert destructure_2(1, %{a: 1, b: 1}) == {:ok, 3}
    assert destructure_2({:ok, 1}, %{a: 1, b: 1}) == {:ok, 3}
    assert destructure_2({:error, :foo}, %{a: 1, b: 2}) == {:error, :foo}
    # it does not care if 2nd parameter doesn't match if 1st one is an error
    assert destructure_2({:error, :foo}, 42) == {:error, :foo}
  end

  test "baz/2" do
    assert baz(%Square{w: 2, h: 2}, %Circle{r: 1}) == {:ok, 1}
  end

  test "partial/1" do
    assert partial([1, 2, 3]) == {:ok, [1, 2, 3]}

    # 'partial' only works on lists
    assert_raise FunctionClauseError, fn ->
      partial(123)
    end

    assert partial({:ok, [1, 2, 3]}) == {:ok, [1, 2, 3]}

    # 'partial' still works on lists even when tuple is there
    assert_raise FunctionClauseError, fn ->
      partial({:ok, 123})
    end

    assert partial({:error, :foo}) == {:error, :foo}
  end

  test "partial2/2" do
    assert partial2(1, 2) == {:ok, 3}

    # 'partial2' only works on integers
    assert_raise FunctionClauseError, fn ->
      partial2("1", 2)
    end

    # 'partial2' only works on integers
    assert_raise FunctionClauseError, fn ->
      partial2(1, "2")
    end

    assert partial2({:ok, 1}, 2) == {:ok, 3}

    # 'partial' still works on lists even when tuple is there
    assert_raise FunctionClauseError, fn ->
      partial2({:ok, "1"}, 2)
    end

    assert partial2({:error, :foo}, 1) == {:error, :foo}
    # NB: error case does not care that 2nd parameter violates the guards
    assert partial2({:error, :foo}, "2") == {:error, :foo}
  end

  test "rec_length/1" do
    assert rec_length([1, 2, 3, 4]) == {:ok, 4}
    assert rec_length({:ok, [1]}) == {:ok, 1}
    assert rec_length({:error, :foo}) == {:error, :foo}
  end
end
