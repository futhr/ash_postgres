# SPDX-FileCopyrightText: 2019 ash_postgres contributors <https://github.com/ash-project/ash_postgres/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPostgres.Verifiers.VerifyTemporalTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias AshPostgres.Verifiers.VerifyTemporal

  defmodule BoundResource do
    @moduledoc false

    use Ash.Resource,
      otp_app: :ash_postgres,
      domain: nil,
      validate_domain_inclusion?: false,
      data_layer: AshPostgres.DataLayer

    postgres do
      table("operation_bound_records")
      repo(&__MODULE__.repo/2)
    end

    attributes do
      uuid_primary_key(:id)
    end

    def repo(_, _), do: raise(ArgumentError, "storage is not bound to this operation")
  end

  defmodule CurrentRepo do
    @moduledoc false

    def min_pg_version, do: Version.parse!("18.0.0")
    def installed_extensions, do: ["btree_gist"]
  end

  defmodule OldRepo do
    @moduledoc false

    def min_pg_version, do: Version.parse!("17.0.0")
    def installed_extensions, do: ["btree_gist"]
  end

  defmodule MissingExtensionRepo do
    @moduledoc false

    def min_pg_version, do: Version.parse!("18.0.0")
    def installed_extensions, do: []
  end

  test "non-temporal verification never resolves an operation-bound repository" do
    assert :ok = VerifyTemporal.verify(BoundResource.spark_dsl_config())
  end

  test "temporal verification still resolves the mutation repository" do
    test_process = self()

    repo = fn _, operation ->
      send(test_process, {:resolved, operation})
      CurrentRepo
    end

    assert :ok = VerifyTemporal.verify(dsl(repo, :context))
    assert_received {:resolved, :mutate}
  end

  test "temporal resources still require PostgreSQL 18" do
    assert_raise Spark.Error.DslError, ~r/requires PostgreSQL 18 or later/, fn ->
      VerifyTemporal.verify(dsl(OldRepo, :context))
    end
  end

  test "temporal resources still require btree_gist" do
    assert_raise Spark.Error.DslError, ~r/requires the `btree_gist` extension/, fn ->
      VerifyTemporal.verify(dsl(MissingExtensionRepo, :context))
    end
  end

  defp dsl(repo, strategy) do
    BoundResource.spark_dsl_config()
    |> Map.put([:postgres], %{opts: [repo: repo]})
    |> Map.put([:temporal], %{opts: [strategy: strategy]})
  end
end
