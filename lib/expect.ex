defmodule Expect do
  @moduledoc """
  Tiny TCL/Expect-ish interface for the excellent Porcelain library.
  """

  @type pattern :: binary | Regex.t

  require Logger

  defmacro __using__(_opts) do
    quote do
      import Expect, only: :macros
    end
  end

  @doc """
  An alias for `Expect.close/1`.
  """
  defmacro exp_close(process) do
    quote do
      Expect.close(unquote(process))
    end
  end

  @doc """
  An alias for `Expect.spawn/1`.
  """
  defmacro exp_spawn(command) do
    quote do
      Expect.spawn(unquote(command))
    end
  end

  @doc """
  An alias for `Expect.send/2`.
  """
  defmacro exp_send(process, data) do
    quote do
      Expect.send(unquote(process), unquote(data))
    end
  end

  @doc """
  Match incoming data and execute the corresponding block. Times out after 10
  seconds.

  Matched data is accessed from within the block via the `buffer` variable.

  If no more specific match is found, the first block matching `_` is executed.
  If no data is received within the timeout period, no block matching `_` will
  be executed.

  If no match is found within the timeout period, the first block matching
  `:timeout` is executed, or else the first block matching `:default` is
  executed. Otherwise, `{:error, :etimedout}` is returned.

  ## Examples

    iex> expect spawned_process do
      ~r/>$/ ->
        :match

      "a string data may contain" ->
        buffer
    end
    {:ok, :match}
    
    iex> expect spawned_process do
      _ ->
        buffer
    end
    {:ok, ["some data\n\r", "some more data\n\r"]}
    
    iex> expect process_without_data do
      _ ->
        buffer
    end
    {:error, :etimedout}
    
    iex> expect spawned_process do
      "non-matching pattern" ->
        buffer
    end
    {:error, :etimedout}
    
    iex> expect spawned_process do
      :timeout ->
        :it_timed_out
    end
    {:ok, :it_timed_out}

  """
  defmacro expect(process, do: block) do
    quote do
      Expect.do_expect(unquote(process), unquote(10_000), unquote(
        for {:->, [_], [[pattern], body]} <- block do
          pattern = with {:_, _, _} <- pattern, do: ""

          fun = {:fn, [],
            [{:->, [], [[{:buffer, [], nil}], body]}]
          }

          {pattern, fun}
        end))
    end
  end

  @doc """
  Match incoming data and execute the corresponding block.

  Matched data is accessed from within a block via the `buffer` variable.

  If no more specific match is found, the first block matching `_` is executed.
  If no data is received within the timeout period, no block matching `_` will
  be executed.

  If no match is found within the timeout period, the first block matching
  `:timeout` is executed, or else the first block matching `:default` is
  executed. Otherwise, `{:error, :etimedout}` is returned.

  ## Examples

      iex> expect spawned_process do
        ~r/>$/ ->
          :match

        "a string data may contain" ->
          buffer

      after
        2_000 ->
          :not_what_i_expected
      end
      {:ok, :match}

  """
  defmacro expect(process, do: block, after: after_block) do
    [{:->, [context], [[timeout], timeout_body]}] = after_block

    timeout_expect = {:->, [context], [[:timeout], timeout_body]}

    block = [timeout_expect | block]

    quote do
      Expect.do_expect(unquote(process), unquote(timeout), unquote(
        for {:->, [_], [[pattern], body]} <- block do
          pattern =
            with {:_, _, _} <- pattern do
              raise "expect macro with 'after' will never time out; remove 'after' section."
            end

          fun = {:fn, [],
            [{:->, [], [[{:buffer, [], nil}], body]}]
          }

          {pattern, fun}
        end))
    end
  end

  @doc """
  Match incoming data on `pattern` and execute `fun/1`.

  Matched data is accessed from within `fun/1` with `buffer`.

  If `pattern` is `_` and data is received, `fun` is executed. If `pattern` is
  `_` and no data is received within the timeout period, `{:error, :etimedout}`
  is returned.

  If no match is found within the timeout period and `pattern` is `:timeout`,
  `fun` is executed. If no match is found within the timeout period and
  `pattern` is `:default`, `fun` is executed. Otherwise, `{:error, :etimedout}`
  is returned.

  ## Examples

      iex> expect(spawned_process, 2_000, ~r/>$/)
      {:ok, ["some data\n\r", "some more data>"]}

      iex> expect(spawned_process, 2_000, _, fn _ -> :got_something end)
      {:ok, :got_something}

  """
  defmacro expect(process, timeout, pattern, fun \\ quote(do: &(&1))) do
    quote do
      Expect.do_expect(unquote(process), unquote(timeout), unquote(
        [{with({:_, [_], _} <- pattern, do: ""), fun}]
      ))
    end
  end

  defp driver do
    Application.get_env :expect_ex, :driver
  end

  defp timed_out?(timer) do
    case Process.read_timer timer do
      false ->
        true

      _ ->
        false
    end
  end

  defp find_matching_expect(expects, data) do
    Enum.find expects, fn {pattern, _} ->
      case pattern do
        %Regex{} = pattern when is_binary(data) ->
          Regex.match? pattern, data

        pattern when is_binary(pattern) and is_binary(data) ->
          String.contains? data, pattern

        _ ->
          false
      end
    end
  end

  defp get_timeout_fun_or_error(expects) do
    with nil <- Keyword.get(expects, :timeout),
         nil <- Keyword.get(expects, :default)
    do
      {:error, :etimedout}
    end
  end

  defp _expect(true, _timer, expects, _pid, queue) do
    with fun when is_function(fun) <- get_timeout_fun_or_error(expects)
    do
      {:ok, fun.(queue)}
    end
  end
  defp _expect(false, timer, expects, pid, queue) do
    receive do
      {^pid, :data, :out, data} ->
        case find_matching_expect(expects, data) do
          nil ->
            _expect timed_out?(timer), timer, expects, pid, queue ++ [data]

          {_, fun} ->
            {:ok, fun.(queue ++ [data])}
        end

      {^pid, :result, %{status: status}} ->
        :ok = Logger.info "Spawned process exited with status '#{status}'."

        case Keyword.get(expects, :default) do
          nil ->
            {:error, :exit, status, queue}

          fun ->
            {:ok, fun.(queue)}
        end

    after
      100 ->
        _expect timed_out?(timer), timer, expects, pid, queue
    end
  end

  @doc """
  Called by the `expect/2`, `expect/3`, and `expect/4` macros.
  """
  @spec do_expect(%{}, pos_integer, [{pattern, function}])
        :: {:ok, any}
         | {:error, :exit, non_neg_integer, list}
         | {:error, :etimedout}

  def do_expect(%{pid: pid}, timeout, expects) when is_list expects do
    timer = Process.send_after :nobody, nil, timeout

    _expect timed_out?(timer), timer, expects, pid, []
  end

  @doc """
  Close a spawned process.
  """
  @spec close(%{}) :: :ok

  def close(process) do
    driver.stop process
  end

  @doc """
  Send `data` to a spawned process.
  """
  @spec send(%{}, binary) :: :ok

  def send(process, data) do
    driver.send process, data
  end

  @doc """
  Spawn a process for `command`.
  """
  @spec spawn(String.t) :: {:ok, %{}}

  def spawn(command) do
    driver.spawn command
  end
end
