# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Expect.Driver.Dummy do
  @moduledoc false

  @behaviour Expect.Driver

  def close(_),   do: :ok

  def send(_, _), do: :ok

  def spawn(_),   do: %{pid: nil}
end
