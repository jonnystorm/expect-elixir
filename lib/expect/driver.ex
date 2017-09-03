# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Expect.Driver do
  @moduledoc """
  A behaviour for Expect drivers.
  """

  @type process
    :: Porcelain.Process.t
     | %{pid: any}

  @doc "Close a spawned process."
  @callback close(process) :: :ok

  @doc "Send `data` to a spawned process."
  @callback send(process, data :: binary) :: :ok

  @doc "Spawn a process for `command`."
  @callback spawn(command :: String.t) :: process
end
