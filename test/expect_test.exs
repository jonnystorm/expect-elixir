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
    send self, {nil, :result, %{status: 1}}

    assert {:ok, :it_exited} ==
      expect(%{pid: nil}, 100, fn {:default, _} -> :it_exited end)
  end

  test "expect with fun matches :default on timeout" do
    assert {:ok, :it_timed_out} ==
      expect(%{pid: nil}, 1, fn {:default, _} -> :it_timed_out end)
  end

  test "expect with fun matches data after two messages" do
    datum1 = "this is a test\r\n"
    datum2 = "this is also a test\r\n"

    send self, {nil, :data, :out, datum1}
    send self, {nil, :data, :out, datum2}

    assert {:ok, datum1 <> datum2} ==
      expect(%{pid: nil}, 1000, fn {:data, buffer} ->
        cond do
          buffer =~ "also" ->
            buffer
        end
      end)
  end

  test "expect with fun matches any" do
    send self, {nil, :data, :out, ""}

    assert {:ok, :any} == expect(%{pid: nil}, 100, fn _ -> :any end)
  end

  test "expect with fun matches with binary pattern" do
    data = "this is a test\r\n"

    send self, {nil, :data, :out, data}

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

    send self, {nil, :data, :out, data}

    assert {:ok, data} ==
      expect(%{pid: nil}, 100, fn {_, buffer} ->
        cond do
          buffer =~ ~r/\btest\b/ ->
            buffer
        end
      end)
  end

  test "expect with fun returns error on process exit" do
    send self, {nil, :result, %{status: status = 1}}

    assert {:error, :exit, status, ""} ==
      expect(%{pid: nil}, 100, fn {_, buffer} ->
        cond do
          buffer =~ ~r/\btest\b/ ->
            buffer
        end
      end)
  end

  test "expect with binary pattern times out" do
    assert expect(%{pid: nil}, 1, "") == {:error, :etimedout}
  end

  test "expect with regex pattern times out" do
    assert expect(%{pid: nil}, 1, ~r/>$/) == {:error, :etimedout}
  end

  test "expect with binary pattern returns error on process exit" do
    send self, {nil, :result, %{status: status = 1}}

    assert expect(%{pid: nil}, 100, "") == {:error, :exit, status, ""}
  end

  test "expect with regex pattern returns error on process exit" do
    send self, {nil, :result, %{status: status = 1}}

    assert expect(%{pid: nil}, 100, ~r/>$/) == {:error, :exit, status, ""}
  end

  test "expect with pattern matches any" do
    data = "this is a test\r\n"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 100, :any) == nil
  end

  test "expect with pattern matches with binary" do
    data = "this is a test\r\n"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 100, "test") == nil
  end

  test "expect with pattern matches with regex" do
    data = "this is a test\r\n"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 100, ~r/\btest\b/) == nil
  end

  test "it spawns a process, sends data, and closes the process" do
    process = exp_spawn("true")

    assert %{pid: _} = exp_spawn("true")

    assert exp_send(process, "blarg") == :ok

    assert exp_close(process) == :ok
  end
end
