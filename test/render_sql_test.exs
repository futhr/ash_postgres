# SPDX-FileCopyrightText: 2026 ash_postgres contributors <https://github.com/ash-project/ash_postgres/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPostgres.Test.RenderSqlTest do
  @moduledoc false

  use AshPostgres.RepoCase, async: true

  import Ecto.Query

  alias AshPostgres.Merge
  alias AshPostgres.Test.Post

  describe "render_sql/3" do
    test "returns a binary rather than the adapter's iodata" do
      {sql, params} = Merge.render_sql(:all, from(p in Post, select: p.id), 0)

      assert is_binary(sql)
      assert sql =~ "SELECT"
      assert params == []
    end

    test "offsets placeholders by the given counter so spliced clauses line up" do
      query = from(p in Post, where: p.title == ^"a", select: p.id)

      {zero, [_]} = Merge.render_sql(:all, query, 0)
      {shifted, [_]} = Merge.render_sql(:all, query, 3)

      assert zero =~ "$1"
      assert shifted =~ "$4"
      refute shifted =~ "$1"
    end

    test "renders update_all without a repository, so an unstarted one cannot raise" do
      query = from(p in Post, update: [set: [title: ^"renamed"]])

      {sql, ["renamed"]} = Merge.render_sql(:update_all, query, 0)

      assert sql =~ "UPDATE"
      assert sql =~ "SET"
    end

    # A repository may be configured with an adapter that wraps
    # `Ecto.Adapters.Postgres` and rewrites the statements it prepares. Rendering
    # must not go through one: these fragments are spliced into a larger
    # statement, where an injected join or RETURNING clause would be invalid SQL.
    test "renders the canonical PostgreSQL statement, not a wrapping adapter's" do
      query = from(p in Post, update: [set: [title: ^"renamed"]])

      {sql, _params} = Merge.render_sql(:update_all, query, 0)

      refute sql =~ "FOR UPDATE"
      refute sql =~ "RETURNING"
    end
  end
end
