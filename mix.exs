defmodule NexuspocExtractor.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexuspoc_extractor,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      releases: releases()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {NexuspocExtractor.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  # Release configuration
  defp releases do
    [
      nexuspoc_extractor: [
        include_executables_for: [:windows],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, &copy_bin_files/1]
      ]
    ]
  end

  defp copy_bin_files(release) do
    File.mkdir_p!(Path.join(release.path, "bin"))

    # Copy PowerShell script from controllers to release bin
    source = "lib/nexuspoc_extractor_web/controllers/pi_data_fetcher.ps1"
    dest = Path.join([release.path, "bin", "pi_data_fetcher.ps1"])

    if File.exists?(source) do
      File.cp!(source, dest)
      IO.puts("Copied PowerShell script to #{dest}")
    end

    # Copy server.bat if it exists
    server_bat_source = "rel/overlays/bin/server.bat"
    server_bat_dest = Path.join([release.path, "bin", "server.bat"])

    if File.exists?(server_bat_source) do
      File.cp!(server_bat_source, server_bat_dest)
      IO.puts("Copied server.bat to #{server_bat_dest}")
    end

    release
  end
end
