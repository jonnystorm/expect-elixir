defmodule Expect.Mixfile do
  use Mix.Project

  def project do
    [ app: :expect_ex,
      version: "0.0.4",
      name: "expect-elixir",
      source_url: "https://github.com/jonnystorm/expect-elixir",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      docs: [
        extras: ["README.md"]
      ]
    ]
  end

  defp get_env(:test) do
    [driver: Expect.Driver.Dummy]
  end
  defp get_env(_) do
    [driver: Expect.Driver.Porcelain]
  end

  def application do
    [ applications: [
        :logger,
        :porcelain
      ],
      env: [] |> Keyword.merge(get_env Mix.env)
    ]
  end

  defp deps do
    [ {:porcelain, "~> 2.0"},
      {:ex_doc, "~> 0.13", only: :dev},
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:excoveralls, "~> 0.5", only: :test}
    ]
  end
end
