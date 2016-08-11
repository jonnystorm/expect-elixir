defmodule Expect.Driver.Dummy do
  @behaviour Expect.Driver

  def stop(_),    do: :ok
  def send(_, _), do: :ok
  def spawn(_),   do: {:ok, %{pid: nil}}
end
