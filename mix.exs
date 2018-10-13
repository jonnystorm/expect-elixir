defmodule Expect.Mixfile do
  use Mix.Project

  def project do
    [
      app: :expect_ex,
      version: "0.0.4",
      name: "expect-elixir",
      source_url: "https://gitlab.com/jonnystorm/expect-elixir",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [extras: ["README.md"]],
      dialyzer: [
        add_plt_apps: [
          :logger,
          :porcelain
        ],
        ignore_warnings: "dialyzer.ignore",
        flags: [
          :unmatched_returns,
          :error_handling,
          :race_conditions,
          :underspecs
        ]
      ]
    ]
  end

  defp get_env(:test),
    do: [driver: Expect.Driver.Dummy]

  defp get_env(_),
    do: [driver: Expect.Driver.Porcelain]

  def application do
    [
      applications: [
        :logger,
        :porcelain
      ],
      env: Keyword.merge([], get_env(Mix.env()))
    ]
  end

  defp deps do
    [
      {:porcelain,
       git: "https://github.com/alco/porcelain", ref: "acfc0f0a6987aadb08f495a578e22ef624342685"},
      {:ex_doc, "~> 0.13", only: :dev}
    ]
  end
end
