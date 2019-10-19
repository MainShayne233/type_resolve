defmodule TypeResolve.MixProject do
  use Mix.Project

  @app :type_resolve

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: ">= 1.9.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def application, do: []

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/#{@app}.plt"}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false}
    ]
  end
end
