import Config

config :seiko,
  port: 3131

import_config "config.#{config_env()}.exs"
