# SPDX-FileCopyrightText: 2026 ash_postgres contributors <https://github.com/ash-project/ash_postgres/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPostgres.Test.DynamicRepoSqlTest do
  @moduledoc false

  use AshPostgres.RepoCase, async: false

  alias AshPostgres.Test.Post

  defmodule EmbeddedRepo do
    @moduledoc false

    use Ecto.Repo,
      otp_app: :ash_postgres,
      adapter: Ecto.Adapters.Postgres,
      default_dynamic_repo: AshPostgres.TestRepo

    use AshPostgres.Repo, define_ecto_repo?: false, warn_on_missing_ash_functions?: false

    def min_pg_version, do: AshPostgres.TestRepo.min_pg_version()
    def installed_extensions, do: AshPostgres.TestRepo.installed_extensions()
  end

  test "upsert planning uses an unstarted library Repo's selected host pool" do
    refute Process.whereis(EmbeddedRepo)
    id = Ash.UUID.generate()

    created = create!(%{id: id, title: "first"}, :create_with_atomic_set)
    updated = create!(%{id: id, title: "second"}, :create_with_atomic_set)

    assert created.score == 100
    assert updated.id == id
    assert updated.title == "second"
    assert updated.score == 100
    assert Ash.Resource.get_metadata(created, :upsert_action) == :insert
    assert Ash.Resource.get_metadata(updated, :upsert_action) == :update
    assert TestRepo.get!(Post, id).title == "second"
  end

  @tag :postgres_17
  test "MERGE planning uses a selected host pool PID for each clause" do
    previous = EmbeddedRepo.put_dynamic_repo(Process.whereis(TestRepo))
    on_exit(fn -> EmbeddedRepo.put_dynamic_repo(previous) end)
    refute Process.whereis(EmbeddedRepo)
    a = create!(%{title: "a", score: 1})
    b = create!(%{title: "b", score: 2})

    assert %Ash.BulkResult{status: :success, records: records} =
             Ash.update_many([{a, %{title: "updated"}}, {b, %{score: 99}}], Post, :update,
               context: %{data_layer: %{repo: EmbeddedRepo}},
               return_records?: true,
               return_errors?: true
             )

    by_id = Map.new(records, &{&1.id, &1})
    assert by_id[a.id].title == "updated"
    assert by_id[a.id].score == 1
    assert by_id[b.id].title == "b"
    assert by_id[b.id].score == 99
  end

  defp create!(attrs, action \\ :create) do
    Post
    |> Ash.Changeset.for_create(action, attrs)
    |> Ash.Changeset.set_context(%{data_layer: %{repo: EmbeddedRepo}})
    |> Ash.create!(upsert?: true, upsert_fields: [:title, :score])
  end
end
