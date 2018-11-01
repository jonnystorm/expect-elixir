# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Expect do
  @moduledoc """
  Tiny TCL/Expect-ish interface for the excellent Porcelain
  library.
  """

  @type process
    :: Porcelain.Process.t
     | %{pid: any}
     | {:ok, %{pid: any}}

  @type data    :: binary
  @type command :: String.t
  @type pattern
    :: binary
     | Regex.t

  @type buffer         :: binary
  @type exit_status    :: non_neg_integer

  @type expect_error
    :: {:error, :etimedout}
     | {:error, :exit, exit_status, buffer}

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
  @spec exp_close(process)
    :: :ok
  def exp_close(process),
    do: Expect.close(process)

  @doc """
  Calls `Expect.send/2`. Imported with `use Expect`.
  """
  @spec exp_send(process, data)
    :: process
  @spec exp_send(expect_error, data)
    :: expect_error
  def exp_send(process, data),
    do: Expect.send(process, data)

  @doc """
  Calls `Expect.spawn/1`. Imported with `use Expect`.
  """
  @spec exp_spawn(command)
    :: process
  def exp_spawn(command),
    do: Expect.spawn(command)

  defp driver,
    do: Application.get_env(:expect_ex, :driver)

  @doc """
  Close a spawned process.
  """
  @spec close(process)
    :: :ok
  def close(process),
    do: driver().close(process)

  @doc """
  Send `data` to a spawned process.
  """
  @spec send(process, data)
    :: process
  @spec send(expect_error, data)
    :: expect_error
  def send(%{pid: _} = process, data) do
    driver().send(process, data)

    process
  end

  def send({:ok, %{pid: _} = process}, data) do
    # Facilitate piping between `exp_send` and `expect`
    #
    Expect.send(process, data)
  end

  def send({:error, _} = error, data) do
    # Facilitate piping between `exp_send` and `expect`
    #
    :ok = Logger.info "Will not send #{inspect data}: got #{inspect error}"

    error
  end

  def send({:error, _, _, _} = error, data) do
    # Facilitate piping between `exp_send` and `expect`
    #
    :ok = Logger.info "Will not send #{inspect data}: got #{inspect error}"

    error
  end

  @doc """
  Spawn a process for `command`.
  """
  @spec spawn(String.t)
    :: process
  def spawn(command),
    do: driver().spawn(command)

  defp get_expect_value(process, fun, result) do
    try do
      case fun.(result) do
        true ->
          process

        false ->
          :error

        value ->
          {:ok, value}
      end

    rescue
      _ in [
          CondClauseError,
          FunctionClauseError,
          MatchError,
      ] ->
        :error
    end
  end

  defp timed_out?(timer),
    do: ! Process.read_timer(timer)

  defp _expect(
    true = _timed_out,
    _timer,
    fun,
    proc = _process,
    buffer
  ) do
    with :error <-
           get_expect_value(proc, fun, {:timeout, buffer}),

         :error <-
           get_expect_value(proc, fun, {:default, buffer}),

    do: {:error, :etimedout}
  end

  defp _expect(
    false = _timed_out,
    timer,
    fun,
    %{pid: pid} = proc = _process,
    buffer
  ) do
    timeout = Process.read_timer(timer) || 100

    receive do
      {^pid, :data, :out, data} ->
        next_buffer = buffer <> data

        with :error <-
           get_expect_value(proc, fun, {:data, next_buffer})
        do
          _expect(
            timed_out?(timer),
            timer,
            fun,
            proc,
            next_buffer
          )
        end

      {^pid, :result, %{status: status}} ->
        :ok = Logger.info "Spawned process exited with status '#{status}'."

        with :error <-
           get_expect_value(proc, fun, {:default, buffer}),

        do: {:error, :exit, status, buffer}

    after
      timeout ->
        _expect(true, timer, fun, proc, buffer)
    end
  end

  @doc ~S"""
  Match and process incoming data from spawned process.

  `expect` behaves differently contingent on whether it is
  given a function or a bare pattern.

  When a bare binary or regex pattern is provided, `expect`
  returns one of the following.

    | on match   | `process`                              |
    | on timeout | `{:error, :etimedout}`                 |
    | on exit    | `{:error, :exit, exit_status, buffer}` |

  This behavior is useful for when you don't care about the
  incoming data so much as the fact that it arrived (and
  matched your pattern).

  When a function is provided, `expect` keeps a buffer of
  unmatched data which is passed to `fun` when: new data
  arrives; the timeout period expires; the spawned process
  exits. In each case, the value passed to `fun` take(s)
  one of the following forms.

    | on match   | `{:data, buffer}`                               |
    | on timeout | `{:timeout, buffer}`, then `{:default, buffer}` |
    | on exit    | `{:default, buffer}`                            |

  ## Examples

      iex> expect spawned_process, "# "
      %Porcelain.Process{}

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
      
      iex> expect spawned_process, fn {_, buffer} ->
        buffer
      end
      {:ok, ["some data\r\n", "some more data\r\n"]}
      
      iex> expect process_without_data, fn {:data, buffer} ->
        buffer
      end
      {:error, :etimedout}
      
      iex> expect spawned_process, fn {_, buffer} ->
        cond do
          buffer =~ "non-matching pattern" ->
            buffer
        end
      end
      {:error, :etimedout}
      
      iex> expect spawned_process, fn {:timeout, _} ->
        :it_timed_out
      end
      {:ok, :it_timed_out}
  """
  @spec expect(process, timeout, pattern)
    :: process
     | expect_error
  @spec expect(process, timeout, function)
    :: {:ok, any}
     | expect_error
  def expect(process, timeout \\ 10_000, pattern_or_fun)

  def expect(%{pid: _} = process, timeout, fun)
      when is_function(fun)
  do
    timer = Process.send_after(:nobody, nil, timeout)

    _expect(timed_out?(timer), timer, fun, process, "")
  end

  def expect(%{pid: _} = process, timeout, pattern)
      when is_binary(pattern)
  do
    fun = wrap_pattern_in_function(pattern)

    expect(process, timeout, fun)
  end

  def expect(
    %{pid: _} = process,
    timeout,
    %Regex{} = pattern
  ) do
    fun = wrap_pattern_in_function(pattern)

    expect(process, timeout, fun)
  end

  def expect(%{pid: _} = process, timeout, :any) do
    fun = wrap_pattern_in_function("")

    expect(process, timeout, fun)
  end

  def expect(%{pid: _} = _process, _timeout, term) do
    message = "Unrecognized pattern or function: #{inspect term}"

    :ok = Logger.error message

    raise message
  end

  def expect({:error, _} = error, _timeout, term) do
    # Facilitate piping between `exp_send` and `expect`
    #
    :ok = Logger.info "Will not expect #{inspect term}: got #{inspect error}"

    error
  end

  def expect({:error, _, _, _} = error, _timeout, term) do
    # Facilitate piping between `exp_send` and `expect`
    #
    :ok = Logger.info "Will not expect #{inspect term}: got #{inspect error}"

    error
  end

  defp wrap_pattern_in_function(pattern) do
    fn {:data, buffer} -> buffer =~ pattern end
  end
end
