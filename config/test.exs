import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :nexuspoc_extractor, NexuspocExtractorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "loAO3oK+67QPlBswyn/lGfa4teMy7CPK2YEciF7Lckd4/Dc1RCnRsMTtBb01abh8",
  server: false

# In test we don't send emails
config :nexuspoc_extractor, NexuspocExtractor.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
