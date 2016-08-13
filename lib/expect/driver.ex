# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Expect.Driver do
  @moduledoc """
  A behaviour for Expect drivers.
  """

  @type process :: %{pid: pid | nil}

  @doc "Close a spawned process."
  @callback close(process) :: :ok

  @doc "Send `data` to a spawned process."
  @callback send(process, data :: binary) :: :ok

  @doc "Spawn a process for `command`."
  @callback spawn(command :: String.t) :: process
end
