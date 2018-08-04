# Expect-elixir

[![Build Status](https://travis-ci.org/jonnystorm/expect-elixir.svg?branch=master)](https://travis-ci.org/jonnystorm/expect-elixir)

Tiny TCL/Expect-ish interface for the excellent [Porcelain](https://github.com/alco/porcelain) library.

See the [API documentation](https://jonnystorm.github.io/expect-elixir).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `expect_ex` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:expect_ex, git: "https://github.com/jonnystorm/expect-elixir.git"}]
  end
  ```

  2. Ensure `expect_ex` is started before your application:

  ```elixir
  def application do
    [applications: [:expect_ex]]
  end
  ```

## Example

  ```elixir
  iex> use Expect
  Expect

  iex> process = exp_spawn "telnet 192.0.2.3"
  %Porcelain.Process{err: nil, out: {:send, #PID<0.143.0>}, pid: #PID<0.146.0>}

  iex> expect process, "Password: "
  %Porcelain.Process{err: nil, out: {:send, #PID<0.143.0>}, pid: #PID<0.146.0>}

  iex> exp_send process, "admin\r"
  %Porcelain.Process{err: nil, out: {:send, #PID<0.143.0>}, pid: #PID<0.146.0>}

  iex> expect process, 1_000, ~r/>$/
  %Porcelain.Process{err: nil, out: {:send, #PID<0.143.0>}, pid: #PID<0.146.0>}

  iex> exp_send process, "sho ip route\r"
  %Porcelain.Process{err: nil, out: {:send, #PID<0.143.0>}, pid: #PID<0.146.0>}

  iex> expect process, 1_000, fn {event, buffer} ->
    cond do
      buffer =~ ~r/>$/ ->
        buffer

      event == :timeout ->
        :not_what_i_expected  # Ha!
    end
  end
  {:ok, ["sho ip route\r\n", "Codes: C - connected, S - static, R - RIP, M - mobile, B - BGP\r\n       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area \r\n       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2\r\n       E1 - OSPF external type 1, E2 - OSPF external type 2\r\n       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2\r\n       ia - IS-IS inter area, * - candidate default, U - per-user static route\r\n       o - ODR, P - periodic downloaded static route\r\n\r\nGateway of last resort is 192.0.2.2 to network 0.0.0.0\r\n\r\n     198.51.100.0/32 is subnetted, 5 subnets\r\nC       198.51.100.1 is directly connected, Loopback0\r\ni L2    198.51.100.3 [115/100000] via 198.51.100.3, FastEthernet0/1.1\r\ni L2    198.51.100.2 [115/100000] via 198.51.100.2, FastEthernet0/0.1\r\ni L2    198.51.100.5 [115/300000] via 198.51.100.3, FastEthernet0/1.1\r\n                     [115/300000] via 198.51.100.2, FastEthernet0/0.1\r\ni L2    198.51.100.4 [115/200000] via 198.51.100.3, FastEthernet0/1.1\r\n     192.0.2.0/31 is subnetted, 1 subnets\r\nC       192.0.2.2 is directly connected, FastEthernet1/0\r\nS*   0.0.0.0/0 [1/0] via 192.0.2.2\r\nR1>"]}

  iex> exp_send process, "exit\r"
  %Porcelain.Process{err: nil, out: {:send, #PID<0.143.0>}, pid: #PID<0.146.0>}
  ```

