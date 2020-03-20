defmodule GaeSecretProvider.MixProject do
  use Mix.Project

  def project do
    [
      app: :gcp_secret_provider,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:httpoison, ">0.0.0"},
      {:goth, "~> 1.1.0"},
      {:mox, "~> 0.5", only: :test}
    ]
  end
end
