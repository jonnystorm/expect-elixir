defmodule ExpectTest do
  use ExUnit.Case
  use Expect

  test "expect with fun times out" do
    assert {:ok, :it_timed_out} ==
      expect(%{pid: nil}, 1, fn {event, buffer} ->
        cond do
          buffer =~ ~r/>$/ ->
            nil

          event == :timeout ->
            :it_timed_out
        end
      end)
  end

  test "expect with fun matches :default on exit" do
    fun = fn {:default, _} -> :it_exited end

    send self(), {nil, :result, %{status: 1}}

    assert expect(%{pid: nil}, 100, fun) ==
      {:ok, :it_exited}
  end

  test "expect with fun matches :default on timeout" do
    fun = fn {:default, _} -> :it_timed_out end

    assert expect(%{pid: nil}, 1, fun) ==
      {:ok, :it_timed_out}
  end

  test "expect with fun matches data after two messages" do
    datum1 = "this is a test\r\n"
    datum2 = "this is also a test\r\n"

    send self(), {nil, :data, :out, datum1}
    send self(), {nil, :data, :out, datum2}

    assert {:ok, datum1 <> datum2} ==
      expect(%{pid: nil}, 1000, fn {:data, buffer} ->
        cond do
          buffer =~ "also" ->
            buffer
        end
      end)
  end

  test "expect with fun matches any" do
    fun = fn _ -> :any end

    send self(), {nil, :data, :out, ""}

    assert expect(%{pid: nil}, 100, fun) ==
      {:ok, :any}
  end

  test "expect with fun matches with binary pattern" do
    data = "this is a test\r\n"

    send self(), {nil, :data, :out, data}

    assert {:ok, data} ==
      expect(%{pid: nil}, 100, fn {_, buffer} ->
        cond do
          buffer =~ "test" ->
            buffer
        end
      end)
  end

  test "expect with fun matches with regex pattern" do
    data = "this is a test\r\n"

    send self(), {nil, :data, :out, data}

    assert {:ok, data} ==
      expect(%{pid: nil}, 100, fn {_, buffer} ->
        cond do
          buffer =~ ~r/\btest\b/ ->
            buffer
        end
      end)
  end

  test "expect with fun returns error on process exit" do
    send self(), {nil, :result, %{status: status = 1}}

    assert {:error, :exit, status, ""} ==
      expect(%{pid: nil}, 100, fn {_, buffer} ->
        cond do
          buffer =~ ~r/\btest\b/ ->
            buffer
        end
      end)
  end

  test "expect with binary pattern times out" do
    assert expect(%{pid: nil}, 1, "") ==
      {:error, :etimedout}
  end

  test "expect with regex pattern times out" do
    assert expect(%{pid: nil}, 1, ~r/>$/) ==
      {:error, :etimedout}
  end

  test """
    expect with binary pattern returns error on process
    exit
  """ do
    send self(), {nil, :result, %{status: status = 1}}

    assert expect(%{pid: nil}, 100, "") ==
      {:error, :exit, status, ""}
  end

  test """
    expect with regex pattern returns error on process
    exit
  """ do
    send self(), {nil, :result, %{status: status = 1}}

    assert expect(%{pid: nil}, 100, ~r/>$/) ==
      {:error, :exit, status, ""}
  end

  test "expect with pattern matches any" do
    process = %{pid: nil}
    data    = "this is a test\r\n"

    send self(), {nil, :data, :out, data}

    assert expect(process, 100, :any) == process
  end

  test "expect with pattern matches with binary" do
    process = %{pid: nil}
    data    = "this is a test\r\n"

    send self(), {nil, :data, :out, data}

    assert expect(process, 100, "test") == process
  end

  test "expect with pattern matches with regex" do
    process = %{pid: nil}
    data    = "this is a test\r\n"

    send self(), {nil, :data, :out, data}

    assert expect(process, 100, ~r/\btest\b/) == process
  end

  test """
    it spawns a process, sends data, and closes the
    process
  """ do
    process = exp_spawn "true"

    assert %{pid: _} = process

    assert exp_send(process, "blarg") == process

    assert exp_close(process) == :ok
  end
end
