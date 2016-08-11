defmodule Expect.Driver.Porcelain do
  @behaviour Expect.Driver

  def stop(process) do
    true = Porcelain.Process.stop process

    :ok
  end

  def send(process, data) do
    {:input, ^data} = Porcelain.Process.send_input process, data

    :ok
  end

  def spawn(command) do
    process = Porcelain.spawn_shell command, in: :receive, out: {:send, self}

    {:ok, process}
  end
end
