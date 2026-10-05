# SPDX-FileCopyrightText: 2019 ash_postgres contributors <https://github.com/ash-project/ash_postgres/graphs/contributors>
#
# SPDX-License-Identifier: MIT

import Config

config :ash, :bulk_actions_default_to_errors?, true

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshPostgres.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_postgres",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: [
      "README.md",
      "documentation/tutorials/get-started-with-ash-postgres.md"
    ],
    version_tag_prefix: "v"
end

if Mix.env() == :test do
  config :elixir, :time_zone_database, Tz.TimeZoneDatabase
  config :ash_postgres, AshPostgres.TestRepo, log: false
  config :ash_postgres, AshPostgres.TestNoSandboxRepo, log: false
  config :ash_postgres, AshPostgres.TemporalTestRepo, log: false

  config :ash, :validate_domain_resource_inclusion?, false
  config :ash, :validate_domain_config_inclusion?, false
  config :ash, :default_string_length_count, :codepoints

  config :ash, :policies, show_policy_breakdowns?: true

  config :ash_postgres, :ash_domains, [AshPostgres.Test.Domain]

  config :ash, :custom_expressions, [
    AshPostgres.Expressions.TrigramWordSimilarity,
    AshPostgres.Test.OperatorExpression.IntListContains
  ]

  config :ash, :known_types, [
    AshPostgres.Timestamptz,
    AshPostgres.TimestamptzUsec,
    AshPostgres.Test.OperatorExpression.IntListType
  ]

  pg_port = String.to_integer(System.get_env("PGPORT", System.get_env("PG_PORT", "5432")))

  config :ash_postgres, AshPostgres.TestRepo,
    username: System.get_env("PGUSER", "postgres"),
    database: System.get_env("PGDATABASE", "ash_postgres_test"),
    hostname: System.get_env("PGHOST", "localhost"),
    port: pg_port,
    pool: Ecto.Adapters.SQL.Sandbox,
    types: AshPostgres.Test.PostgrexTypes

  config :ash_postgres, AshPostgres.DevTestRepo,
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    database: System.get_env("PGDEV_DATABASE", "ash_postgres_dev_test"),
    hostname: System.get_env("PGHOST", "localhost"),
    port: pg_port,
    migration_primary_key: [name: :id, type: :binary_id],
    pool: Ecto.Adapters.SQL.Sandbox

  # sobelow_skip ["Config.Secrets"]
  config :ash_postgres, AshPostgres.TestRepo, password: System.get_env("PGPASSWORD", "postgres")

  config :ash_postgres, AshPostgres.TestRepo, migration_primary_key: [name: :id, type: :binary_id]

  config :ash_postgres, AshPostgres.TestNoSandboxRepo,
    username: System.get_env("PGUSER", "postgres"),
    database: System.get_env("PGDATABASE", "ash_postgres_test"),
    hostname: System.get_env("PGHOST", "localhost"),
    port: pg_port

  # sobelow_skip ["Config.Secrets"]
  config :ash_postgres, AshPostgres.TestNoSandboxRepo,
    password: System.get_env("PGPASSWORD", "postgres")

  config :ash_postgres, AshPostgres.TestNoSandboxRepo,
    migration_primary_key: [name: :id, type: :binary_id]

  config :ash_postgres, AshPostgres.TemporalTestRepo,
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    database: System.get_env("PGDATABASE", "ash_postgres_test"),
    hostname: System.get_env("PGHOST", "localhost"),
    port: pg_port,
    pool: Ecto.Adapters.SQL.Sandbox,
    types: AshPostgres.Test.PostgrexTypes

  # Temporal resources need PostgreSQL 18+, so their repo is only migrated when testing
  # against it. An unset `PG_VERSION` means the newest (see `AshPostgres.TestRepo`).
  {pg_version, _} = Integer.parse(System.get_env("PG_VERSION", "19"))
  temporal_repos = if pg_version >= 18, do: [AshPostgres.TemporalTestRepo], else: []

  config :ash_postgres,
    ecto_repos:
      [AshPostgres.TestRepo, AshPostgres.DevTestRepo, AshPostgres.TestNoSandboxRepo] ++
        temporal_repos,
    ash_domains: [
      AshPostgres.Test.Domain,
      AshPostgres.MultitenancyTest.Domain,
      AshPostgres.Test.ComplexCalculations.Domain,
      AshPostgres.Test.MultiDomainCalculations.DomainOne,
      AshPostgres.Test.MultiDomainCalculations.DomainTwo,
      AshPostgres.Test.MultiDomainCalculations.DomainThree,
      AshPostgres.Test.Temporal.Domain
    ]

  config :ash, :compatible_foreign_key_types, [
    {Ash.Type.String, Ash.Type.UUID}
  ]

  config :logger, level: :warning
end
