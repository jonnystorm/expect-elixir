# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Expect.Driver.Porcelain do
  @moduledoc false

  @behaviour Expect.Driver

  def close(process) do
    true = Porcelain.Process.stop process

    :ok
  end

  def send(process, data) do
    {:input, ^data} = Porcelain.Process.send_input process, data

    :ok
  end

  def spawn(command) do
    Porcelain.spawn_shell command, in: :receive, out: {:send, self}
  end
end
