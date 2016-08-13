# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Expect do
  @moduledoc """
  Tiny TCL/Expect-ish interface for the excellent Porcelain library.
  """

  @type process :: %{pid: pid}
  @type pattern :: binary | Regex.t
  @type expect_error :: {:error, :etimedout}
                      | {:error, :exit, non_neg_integer, binary}

  require Logger

  defmacro __using__(_opts) do
    quote do
      import Expect, only: [
        exp_close: 1,
        exp_spawn: 1,
        exp_send: 2,
        expect: 2,
        expect: 3
      ]
    end
  end

  @doc """
  Calls `Expect.close/1`. Imported with `use Expect`.
  """
  def exp_close(process), do: Expect.close process

  @doc """
  Calls `Expect.send/1`. Imported with `use Expect`.
  """
  def exp_send(process, data), do: Expect.send process, data

  @doc """
  Calls `Expect.spawn/1`. Imported with `use Expect`.
  """
  def exp_spawn(command), do: Expect.spawn command

  defp driver do
    Application.get_env :expect_ex, :driver
  end

  @doc """
  Close a spawned process.
  """
  @spec close(process) :: :ok

  def close(process) do
    driver.close process
  end

  defp timed_out?(timer) do
    ! Process.read_timer(timer)
  end

  defp get_expect_value(fun, result) do
    try do
      case fun.(result) do
        true ->
          nil

        false ->
          :error

        value ->
          {:ok, value}
      end

    rescue
      _ in [CondClauseError, FunctionClauseError, MatchError] ->
        :error
    end
  end

  defp _expect(true, _timer, fun, _pid, buffer) do
    with :error <- get_expect_value(fun, {:timeout, buffer}),
         :error <- get_expect_value(fun, {:default, buffer}),
         do: {:error, :etimedout}
  end
  defp _expect(false, timer, fun, pid, buffer) do
    timeout = Process.read_timer(timer) || 100

    receive do
      {^pid, :data, :out, data} ->
        next_buffer = buffer <> data

        with :error <- get_expect_value(fun, {:data, next_buffer}),
             do: _expect timed_out?(timer), timer, fun, pid, next_buffer

      {^pid, :result, %{status: status}} ->
        :ok = Logger.info "Spawned process exited with status '#{status}'."

        with :error <- get_expect_value(fun, {:default, buffer}),
             do: {:error, :exit, status, buffer}

    after
      timeout ->
        _expect true, timer, fun, pid, buffer
    end
  end

  @doc """
  Match and process incoming data from spawned process.

  `expect` behaves differently contingent on whether it is given a function or a
  bare pattern.

  When a bare binary or regex pattern is provided, `expect` returns one of the
  following.

    | on match   | nil                                             |
    | on timeout | `{:timeout, buffer}` or `{:default, buffer}`    |
    | on exit    | `{:default, buffer}`                            |

  This behavior is useful for when you don't care about the incoming data so
  much as the fact that it arrived (and matched your pattern).

  When a function is provided, `expect` keeps a buffer of unmatched data which
  is passed to `fun` when: new data arrives; the timeout period expires; the
  spawned process exits. In each case, the value(s) passed to `fun` take(s) one
  of the following forms.

    | on match   | `{:data, buffer}`                               |
    | on timeout | `{:timeout, buffer}`, then `{:default, buffer}` |
    | on exit    | `{:default, buffer}`                            |

  ## Examples

      iex> expect spawned_process, "# "
      nil

      iex> expect spawned_process, fn {event, buffer} ->
        cond do
          buffer =~ ~r/>$/ ->
            :match

          buffer =~ "a string" ->
            buffer

          event == :timeout ->
            :it_timed_out
        end
      end
      {:ok, :match}
      
      iex> expect spawned_process, fn {_, buffer} -> buffer end
      {:ok, ["some data\r\n", "some more data\r\n"]}
      
      iex> expect process_without_data, fn {:data, buffer} -> buffer end
      {:error, :etimedout}
      
      iex> expect spawned_process, fn buffer ->
        cond do
          buffer =~ "non-matching pattern" ->
            buffer
        end
      end
      {:error, :etimedout}
      
      iex> expect spawned_process, fn {:timeout, _} -> :it_timed_out end
      {:ok, :it_timed_out}

  """
  @spec expect(process,  pattern)              ::        nil | expect_error
  @spec expect(process, function)              :: {:ok, any} | expect_error
  @spec expect(process, pos_integer,  pattern) ::        nil | expect_error
  @spec expect(process, pos_integer, function) :: {:ok, any} | expect_error

  def expect(%{pid: pid}, timeout \\ 10_000, pattern_or_fun) do
    fun = get_expect_fun pattern_or_fun
    timer = Process.send_after :nobody, nil, timeout

    _expect timed_out?(timer), timer, fun, pid, ""
  end

  defp get_expect_fun(pattern_or_fun) do
    case pattern_or_fun do
      fun when is_function(fun) ->
        fun

      :any ->
        wrap_pattern ""

      %Regex{} = pattern ->
        wrap_pattern pattern

      pattern when is_binary(pattern) ->
        wrap_pattern pattern
    end
  end

  defp wrap_pattern(pattern) do
    fn {:data, buffer} -> buffer =~ pattern end
  end

  @doc """
  Send `data` to a spawned process.
  """
  @spec send(process, binary) :: :ok

  def send(process, data) do
    driver.send process, data
  end

  @doc """
  Spawn a process for `command`.
  """
  @spec spawn(String.t) :: {:ok, process}

  def spawn(command) do
    driver.spawn command
  end
end
