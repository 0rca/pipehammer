defmodule Pipehammer do
  @moduledoc """
  Pipehammer, the simplest pipeline management.

  You may now declare regular functions, and Pipehammer will write boilerplate
  for you.

  Example:

  ```
  defpipe safe_div(x, 0) do
    {:error, :division_by_zero}
  end

  defpipe safe_div(x, y) do
    {:ok, x / y}
  end
  ```

  This will define a function having this type signature:
  ```
  @spec safe_div(any | {:ok, any} | {:error, any} ::
    {:ok, any} |
    {:error, :division_by_zero} |
    {:error, any }
  ```

  ```
  12 |> safe_div(6) # => {:ok, 2.0}
  12 |> safe_div(0) # => {:error, :division_by_zero}
  {:ok, 12} |> safe_div(6) # => {:ok, 2.0}
  {:error, :not_a_number} |> safe_div(6) # => {:error, :not_a_number}
  ```

  This has immediate application in building pipelines:

  ```
  defp issue_referral_voucher(account_id, referrer_reference) do
    find_account(account_id)
    |> set_account_referrer(referrer_reference)
    |> issue_referral_voucher()
    |> create_activity()
    |> publish_event()
    |> handle_error(fn e ->
      {:error, "bad error"}
    end)
  end
  ```

  You can still use `with` macro if you wish:
  ```

  defp issue_referral_voucher(account_id, referrer_reference) do
    with {:ok, acc} <- find_account(account_id),
         {:ok, acc} <- set_account_referrer(acc, referrer_reference),
         {:ok, vou} <- issue_referral_voucher(acc),
         {:ok, act} <- create_activity(vou) do

      publish_event(act)
    else
      {:error, e} -> {:error, "bad error"}
    end
  end
  ```

  You can still compose the functions as usual:
  ```
  set_account_referrer(find_account(account_id), referrer_reference)
  ```

  ## Error handling

  Pipe functions are expected to return `{:error, e}` tuples in error cases.

  If additional information is required, consider wrapping it into a tuple:
  `{:error, {:foo, :bar}}`

  If pipe function returns anything other than `{:ok, any} | {:error, any}`
  the behaviour of Pipehammer is undefined (means, the pipeline will crash in production))

  ## What boilerplate to expect:

  ```
  defpipe partial(x, y) when is_integer(x) do
    {:ok, x + y}
  end
  ```

  Will create these functions, in order:

  ```
  def partial({:error, e}, _) do
    {:error, e}
  end

  def partial({:ok, x}, y) when is_integer(x) do
    partial(x, y)
  end

  def partial(x, y) when is_integer(x) do
    {:ok, x + y}
  end
  ```

  Note that error case intentionally does not have guards, as it does not care
  what you pass into the function, as long as 1st argument was an error. This
  logic is essential to chaining the steps.

  Pipehammer is smart to eliminate duplicate error declarations:

  ```
  defpipe foo(x, 0) do
    {:ok, x}
  end

  defpipe foo(x, 1) do
    {:ok, x}
  end
  ```

  This will still write one error clause:
  ```
  def foo({:error, e}, _) do
    {:error, e}
  end
  ```
  """

  @doc """
  Handles errors, but leaves ok tuples intact
  """
  def handle_error(exp, handler) when is_function(handler, 1) do
    case exp do
      :ok -> :ok
      {:ok, _} = ok -> ok
      {:error, e} -> handler.(e)
    end
  end

  @doc """
  Declares function clauses that will handle `nil`, `{:ok, _}`, `{:error, _}`
  in addition to its main clause.
  """
  defmacro defpipe(decl, do: body) do
    # Split declaration into a function declaration without guards, and a function
    # to reconstruct it (or something else) into full declaration again.
    #
    # AST for declaration with guards looks like this:
    # {:when, [], [
    #   {:partial, [], [{x, [], nil}]},
    #   {:is_list, [], [{x, [], nil}]}
    # ]}
    #
    # This block will turn it into a pair of:
    #
    # {:partial, [], [{x, [], nil}]}
    #
    # and
    #
    # fn fun_decl ->
    #   {:when, [], [
    #     fun_decl,
    #     {:is_list, [], [{x, [], nil}]}
    #   ]}
    #
    # This pair is enough to reconstruct the full declaration intact, or
    # make a modified declaration having the same guards
    {{fun_name, ctx, args} = fun_decl, with_guards} =
      case decl do
        {:when, ctx, [fun_decl | guards]} ->
          {fun_decl,
           fn decl ->
             {:when, ctx, [decl | guards]}
           end}

        _ ->
          {decl, fn x -> x end}
      end

    function_name = function_name(fun_decl)

    Module.register_attribute(__CALLER__.module, :default_cases, accumulate: true)
    Module.register_attribute(__CALLER__.module, :error_cases, accumulate: true)
    Module.register_attribute(__CALLER__.module, :ok_cases, accumulate: true)

    # default case, that defines:
    # def fun_name(x, y, ...) [when ...] do
    #   body
    # end
    case args do
      [_ | _] ->
        quote do
          def unquote(decl), do: unquote(body)
        end
        |> register_definition(function_name, __CALLER__.module, :default_cases)
    end

    # universal error case, that defines (without guards or patterns):
    # def fun_name({:error, e}, _, ...) do
    #   {:error, e}
    # end
    case args do
      [_ | rgs] ->
        quote do
          def unquote({fun_name, ctx, [{:error, Macro.var(:e, nil)} | ignore_all(rgs)]}) do
            {:error, unquote(Macro.var(:e, nil))}
          end
        end
        |> register_definition(function_name, __CALLER__.module, :error_cases)
    end

    # universal ok case, that delegates to the original function. It defines:
    # def fun_name({:ok, x}, y, ...) [when ...] do
    #   fun_name(x, y, ...)
    # end
    case ununderscore(args) do
      [_ | rgs] ->
        quote do
          def unquote(with_guards.({fun_name, ctx, [{:ok, Macro.var(:x, nil)} | rgs]})) do
            unquote({fun_name, ctx, [Macro.var(:x, nil) | rgs]})
          end
        end
        |> register_definition(function_name, __CALLER__.module, :ok_cases)
    end

    # nothing is declared at this point: definitions are accumulated in
    # module attributes for later compilation
    quote do
    end
  end

  defp register_definition(ast, function_name, module, attribute) do
    Module.put_attribute(module, attribute, {function_name, ast})
  end

  @doc """
  Alternative piping: it first step fails, try another one.
  """
  defmacro exp <|> r do
    quote do
      case unquote(exp) do
        :ok -> :ok
        {:ok, _} = ok -> ok
        {:error, _} -> unquote(r)
      end
    end
  end

  # replaces every argument with an '_' (this will ignore any pattern matchers too)
  defp ignore_all(args) do
    Enum.map(args, fn _ -> {:_, [], nil} end)
  end

  # replaces underscored variables with numbered ones in argument list
  defp ununderscore(args) do
    Macro.postwalk(args, 0, fn
      {name, meta, r}, i when is_atom(r) ->
        case to_string(name) do
          "_" <> _ -> {{:"x#{i}", meta, r}, i + 1}
          _ -> {{name, meta, r}, i}
        end

      ast, i ->
        {ast, i}
    end)
    |> elem(0)
  end

  defp pick_definitions(defns, fun_name) do
    Enum.flat_map(defns, fn
      {^fun_name, defn} -> [defn]
      _ -> []
    end)
  end

  defp function_name({fun_name, _, args}) do
    :"#{fun_name}/#{length(args)}"
  end

  @doc false
  # reorder function case definitions (error and ok cases go before the regular ones)
  # and injects them into the module
  # > If it's a macro, its returned value will be injected at the end of the module
  # > definition before the compilation starts.
  defmacro __before_compile__(env) do
    # extract all definitions, and sort them in order of declaration, which is reverse
    [default_cases, ok_cases, error_cases] =
      [:default_cases, :ok_cases, :error_cases]
      |> Enum.map(fn attribute ->
        Module.get_attribute(env.module, attribute)
        |> List.wrap()
        |> Enum.reverse()
        |> Enum.uniq_by(&shape/1)
      end)

    # obtain function names from default cases, and pick their definitions in
    # order of declaration, sorting error, ok, and default cases per function
    # to keep their order
    default_cases
    |> Enum.map(fn {name, _} -> name end)
    |> Enum.uniq()
    |> Enum.flat_map(fn name ->
      # concatenate definitions in that order: errors, ok's, regular declarations
      [error_cases, ok_cases, default_cases]
      |> Enum.flat_map(fn defns -> pick_definitions(defns, name) end)
    end)
    |> case do
      # wrap the definitions into a block
      defns -> {:__block__, [], defns}
    end

    # |> case do
    #   # emit AST to stdout if debug flag is set
    #   ast ->
    #     if Module.get_attribute(__CALLER__.module, :pipehammer_debug) do
    #       IO.inspect(ast)
    #     else
    #       ast
    #     end
    # end
  end

  # rename the variables and erase context. Because it does not replace bound
  # vars in body, it is only useful for identifying duplicate function implementations
  # {:def, [context: Pipehammer, import: Kernel], [
  #   {:add, [line: 31], [{:error, {:e, [], nil}}, {:_y, [line: 31], nil}]}
  # ]}}
  # =>
  # {:def, [], [{:add, [], [{:error, {:arg0, [], nil}}, {:arg1, [], nil}]}]}}
  defp shape(defn) do
    Macro.postwalk(defn, 0, fn
      {_, _, nil}, i -> {{:"x#{i}", [], nil}, i + 1}
      {a, _, b}, i -> {{a, [], b}, i}
      ast, i -> {ast, i}
    end)
    |> elem(0)
  end

  defmacro __using__(opts \\ []) do
    debug = Keyword.get(opts, :debug, false)

    quote do
      import Pipehammer
      require Pipehammer

      @pipehammer_debug unquote(debug)
      @before_compile Pipehammer
    end
  end
end
