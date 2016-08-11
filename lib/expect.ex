defmodule Expect do
  @moduledoc """
  Tiny TCL/Expect-ish interface for the excellent Porcelain library.
  """

  require Logger

  defmacro __using__(_opts) do
    quote do
      import Expect, only: :macros
    end
  end

  defmacro exp_close(proc) do
    quote do
      Expect.close(unquote(proc))
    end
  end

  defmacro exp_spawn(command) do
    quote do
      Expect.spawn(unquote(command))
    end
  end

  defmacro exp_send(proc, data) do
    quote do
      Expect.send(unquote(proc), unquote(data))
    end
  end

  defmacro expect(proc, do: block) do
    quote do
      Expect.do_expect(unquote(proc), unquote(10_000), unquote(
        for {:->, [_], [[pattern], body]} <- block do
          pattern = with {:_, _, _} <- pattern, do: ""

          fun = {:fn, [],
            [{:->, [], [[{:buffer, [], nil}], body]}]
          }

          {pattern, fun}
        end))
    end
  end

  defmacro expect(proc, do: block, after: after_block) do
    [{:->, [context], [[timeout], timeout_body]}] = after_block

    timeout_expect = {:->, [context], [[:timeout], timeout_body]}

    block = [timeout_expect | block]

    quote do
      Expect.do_expect(unquote(proc), unquote(timeout), unquote(
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

  defmacro expect(proc, timeout, pattern, fun \\ quote(do: &(&1))) do
    quote do
      Expect.do_expect(unquote(proc), unquote(timeout), unquote(
        [{with({:_, [_], _} <- pattern, do: ""), fun}]
      ))
    end
  end

  defp driver do
    Application.get_env :expect, :driver
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
        ^data when is_atom(data) ->
          true

        %Regex{} = pattern when is_binary(data) ->
          Regex.match? pattern, data

        pattern when is_binary(pattern) and is_binary(data) ->
          String.contains? data, pattern

        _ ->
          false
      end
    end
  end

  defp _expect(true, _timer, expects, _pid, queue) do
    case find_matching_expect(expects, :timeout) do
      nil ->
        {:error, :etimedout}

      {_, fun} ->
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

  def do_expect(%{pid: pid}, timeout, expects) when is_list expects do
    timer = Process.send_after :nobody, nil, timeout

    _expect timed_out?(timer), timer, expects, pid, []
  end

  def close(proc) do
    driver.stop proc
  end

  def send(proc, data) do
    driver.send proc, data
  end

  def spawn(command) do
    driver.spawn command
  end
end
