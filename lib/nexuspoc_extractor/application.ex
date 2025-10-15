defmodule NexuspocExtractor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NexuspocExtractorWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:nexuspoc_extractor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NexuspocExtractor.PubSub},
      # Start a worker by calling: NexuspocExtractor.Worker.start_link(arg)
      # {NexuspocExtractor.Worker, arg},
      # Start to serve requests, typically the last entry
      NexuspocExtractorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NexuspocExtractor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NexuspocExtractorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
