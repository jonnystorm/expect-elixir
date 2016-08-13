defmodule Expect.Driver.PorcelainTest do
  use ExUnit.Case

  @moduletag :integrated

  alias Expect.Driver.Porcelain, as: Driver
  alias Porcelain.Process, as: ExpProcess

  test "it spawns a process, sends data, receives data, and closes the process" do
    process = Driver.spawn "cat"

    assert %ExpProcess{pid: _} = process

    assert Driver.send(process, "test data") == :ok

    assert_receive {_, :data, :out, "test data"}

    assert Driver.close(process) == :ok
  end
end
