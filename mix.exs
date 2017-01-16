defmodule Xandra.Mixfile do
  use Mix.Project

  def project() do
    [app: :xandra,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application() do
    [applications: [:logger, :db_connection]]
  end

  defp deps() do
    [{:db_connection, "~> 1.0.0"},
     {:ex_doc, "~> 0.14", only: :dev}]
  end
end
