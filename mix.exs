defmodule GcpSecretProvider.MixProject do
  use Mix.Project

  def project do
    [
      app: :gcp_secret_provider,
      version: "0.1.1",
      description: description(),
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/adzz/gcp_secret_provider",
      package: package(),
      deps: deps()
    ]
  end

  defp description do
    """
    A configuration provider that gets secrets from Google Secret Manager on app start
    """
  end

  defp package do
    [
      maintainers: ["Adzz"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/adzz/gcp_secret_provider"}
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:httpoison, ">0.0.0"},
      {:goth, "~> 1.1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mox, "~> 0.5", only: :test}
    ]
  end
end
