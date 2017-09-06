# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Expect.Driver.Porcelain do
  @moduledoc false

  @behaviour Expect.Driver

  @type data    :: binary
  @type command :: String.t
  @type process
    :: Porcelain.Process.t
     | %{pid: pid | nil}

  @spec close(process)
    :: :ok
  def close(process) do
    true = Porcelain.Process.stop process

    :ok
  end

  @spec send(process, data)
    :: :ok
  def send(process, data) do
    _ = Porcelain.Process.send_input(process, data)

    :ok
  end

  @spec spawn(command)
    :: process
  def spawn(command) do
    Porcelain.spawn_shell command,
      in: :receive,
      out: {:send, self()}
  end
end
