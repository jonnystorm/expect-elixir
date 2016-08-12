defmodule Expect.Driver do
  @moduledoc """
  A behaviour for Expect drivers.
  """

  @doc "Stop a spawned process."
  @callback stop(process :: %{}) :: :ok

  @doc "Send `data` to a spawned process."
  @callback send(process :: %{}, data :: binary) :: :ok

  @doc "Spawn a process for `command`."
  @callback spawn(command :: String.t) :: {:ok, %{}}
end
