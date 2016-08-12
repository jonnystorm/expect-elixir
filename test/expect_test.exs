defmodule ExpectTest do
  use ExUnit.Case
  use Expect

  test "expect block macro times out" do
    assert {:ok, :it_timed_out} ==
      (expect %{pid: nil} do
        ~r/>$/ ->
          nil

      after
        1 ->
          :it_timed_out
      end)
  end

  test "expect block macro matches :default on exit" do
    send self, {nil, :result, %{status: 1}}

    assert {:ok, :it_exited} ==
      (expect %{pid: nil} do
        :default ->
          :it_exited
      end)
  end

  test "expect block macro matches any" do
    send self, {nil, :data, :out, ""}

    assert {:ok, :any} ==
      (expect %{pid: nil} do
        _ ->
          :any
      end)
  end

  test "expect block macro matches with binary pattern" do
    data = "this is a test\n\r"

    send self, {nil, :data, :out, data}

    assert {:ok, [data]} ==
      (expect %{pid: nil} do
        "test" ->
          buffer
      end)
  end

  test "expect block macro matches with regex pattern" do
    data = "this is a test\n\r"

    send self, {nil, :data, :out, data}

    assert {:ok, [data]} ==
      (expect %{pid: nil} do
        ~r/\btest\b/ ->
          buffer
      end)
  end

  test "expect block macro returns error on process exit" do
    send self, {nil, :result, %{status: status = 1}}

    assert {:error, :exit, status, []} ==
      (expect %{pid: nil} do
        ~r/\btest\b/ ->
          buffer
      end)
  end

  test "expect line macro times out" do
    assert expect(%{pid: nil}, 1, ~r/>$/) == {:error, :etimedout}
  end

  test "expect line macro matches :timeout" do
    assert expect(%{pid: nil}, 1, :timeout) == {:ok, []}
  end

  test "expect line macro matches :default on timeout" do
    assert expect(%{pid: nil}, 1, :default) == {:ok, []}
  end

  test "expect line macro matches :default on exit" do
    send self, {nil, :result, %{status: 1}}

    assert expect(%{pid: nil}, 1, :default) == {:ok, []}
  end

  test "expect line macro matches any" do
    data = "this is a test\n\r"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 60_000, _) == {:ok, [data]}
  end

  test "expect line macro matches with binary pattern" do
    data = "this is a test\n\r"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 60_000, "test") == {:ok, [data]}
  end

  test "expect line macro matches with regex pattern" do
    data = "this is a test\n\r"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 60_000, ~r/\btest\b/) == {:ok, [data]}
  end

  test "expect line macro returns error on process exit" do
    send self, {nil, :result, %{status: status = 1}}

    assert expect(%{pid: nil}, 100, ~r/>$/) == {:error, :exit, status, []}
  end

  test "expect line macro with fun times out" do
    assert expect(%{pid: nil}, 1, ~r/>$/, &(&1)) == {:error, :etimedout}
  end

  test "expect line macro with fun matches any" do
    data = "this is a test\n\r"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 1, _, &(&1)) == {:ok, [data]}
  end

  test "expect line macro with fun matches with binary pattern" do
    data = "this is a test\r\r"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 1, "test", &(&1)) == {:ok, [data]}
  end

  test "expect line macro with fun matches with regex pattern" do
    data = "this is a test\r\r"

    send self, {nil, :data, :out, data}

    assert expect(%{pid: nil}, 1, ~r/\btest\b/, &(&1)) == {:ok, [data]}
  end

  test "expect line macro with fun returns error on process exit" do
    send self, {nil, :result, %{status: status = 1}}

    assert expect(%{pid: nil}, 100, ~r/>$/, &(&1)) == {:error, :exit, status, []}
  end

  test "exp_send sends a message" do
    assert exp_send(%{pid: nil}, "blarg") == :ok
  end

  test "exp_spawn returns a process" do
    assert {:ok, %{pid: _}} = exp_spawn("true")
  end
end
