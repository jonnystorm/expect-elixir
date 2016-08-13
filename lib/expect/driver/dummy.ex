# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Expect.Driver.Dummy do
  @moduledoc false

  @behaviour Expect.Driver

  def close(_),   do: :ok

  def send(_, _), do: :ok

  def spawn(_),   do: %{pid: nil}
end
