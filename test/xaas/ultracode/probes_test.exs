defmodule Xaas.Ultracode.ProbesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of `Xaas.Ultracode.Probes`: real git repos in
  real temp dirs (a plain repo AND a linked worktree, the shape
  `Worktrees.provision/3` produces), real clones, real file mutations. Every
  assertion is on the resulting files/git state, never on a call log.
  """

  alias Xaas.Test.DodFixture, as: Fx
  alias Xaas.Ultracode.Probes

  setup do
    parent = Fx.tmp("probes")

    {repo, head} =
      Fx.repo(parent, %{
        "answer.txt" => "ANSWER=42\nSECOND=42\n",
        "lib/greet.txt" => "hello\nkeep me\nhello again\n",
        "fixture.json" => ~s({"ok": true}\n)
      })

    %{parent: parent, repo: repo, head: head}
  end

  defp probe(kind, extra), do: Map.merge(%{"id" => "p", "kind" => kind}, extra)

  defp admit!(raw) do
    assert {:ok, [probe]} = Probes.admit([raw])
    probe
  end

  describe "admit/1" do
    test "accepts string- and atom-keyed declarations, defaults occurrence, never makes atoms from data" do
      assert {:ok,
              [%{id: "a", kind: "replace", occurrence: "first"}, %{id: "b", kind: "delete_file"}]} =
               Probes.admit([
                 %{
                   "id" => "a",
                   "kind" => "replace",
                   "file" => "f",
                   "pattern" => "x",
                   "replacement" => "y"
                 },
                 %{id: "b", kind: "delete_file", file: "g"}
               ])

      assert {:error, {:invalid_probe, "a", {:unknown_key, ~s("surprise")}}} =
               Probes.admit([
                 %{"id" => "a", "kind" => "delete_file", "file" => "f", "surprise" => 1}
               ])

      assert Probes.admit(nil) == {:ok, []}
      assert Probes.admit([]) == {:ok, []}
    end

    test "refuses bad ids, kinds, paths, patterns, commits and duplicate ids" do
      bad = fn raw -> Probes.admit([Map.merge(%{"id" => "p"}, raw)]) end

      assert {:error, {:invalid_probe, _, :bad_id}} =
               bad.(%{"id" => "has space", "kind" => "truncate", "file" => "f"})

      assert {:error, {:invalid_probe, _, {:unknown_kind, _}}} =
               bad.(%{"kind" => "rm_rf", "file" => "f"})

      assert {:error, {:invalid_probe, _, :file_escapes_repo}} =
               bad.(%{"kind" => "truncate", "file" => "../x"})

      assert {:error, {:invalid_probe, _, :file_must_be_relative}} =
               bad.(%{"kind" => "truncate", "file" => "/etc/passwd"})

      assert {:error, {:invalid_probe, _, :file_in_git_dir}} =
               bad.(%{"kind" => "truncate", "file" => ".git/HEAD"})

      assert {:error, {:invalid_probe, _, :bad_pattern}} =
               bad.(%{"kind" => "delete_line", "file" => "f", "pattern" => ""})

      assert {:error, {:invalid_probe, _, :replacement_required}} =
               bad.(%{"kind" => "replace", "file" => "f", "pattern" => "x"})

      assert {:error, {:invalid_probe, _, :bad_commit}} =
               bad.(%{"kind" => "revert_commit", "commit" => "--all"})

      assert {:error, {:invalid_probe, _, {:bad_anchor, :falsifier}}} =
               bad.(%{"kind" => "truncate", "file" => "f", "falsifier" => ""})

      dup = %{"id" => "same", "kind" => "truncate", "file" => "f"}
      assert {:error, {:duplicate_probe_ids, ["same"]}} = Probes.admit([dup, dup])

      too_many = for n <- 1..33, do: %{"id" => "p#{n}", "kind" => "truncate", "file" => "f"}
      assert {:error, {:too_many_probes, 33, 32}} = Probes.admit(too_many)

      assert {:error, :probes_must_be_a_list} = Probes.admit(%{"id" => "p"})
    end

    test "problems/1 renders registration-time strings" do
      assert Probes.problems([%{"id" => "p", "kind" => "truncate", "file" => "f"}]) == []
      assert [problem] = Probes.problems([%{"id" => "p", "kind" => "nope"}])
      assert problem =~ "unknown_kind"
    end
  end

  describe "scratch_clone/3 + apply_probe/2" do
    test "a mutation lands in the scratch clone and NEVER in the real repo", %{
      parent: parent,
      repo: repo,
      head: head
    } do
      dest = Path.join(parent, "scratch")
      assert {:ok, ^dest} = Probes.scratch_clone(repo, head, dest)
      assert Fx.head(dest) == head

      p =
        admit!(
          probe("replace", %{"file" => "answer.txt", "pattern" => "42", "replacement" => "41"})
        )

      assert :ok = Probes.apply_probe(p, dest)

      # first occurrence only (default)
      assert File.read!(Path.join(dest, "answer.txt")) == "ANSWER=41\nSECOND=42\n"
      assert File.read!(Path.join(repo, "answer.txt")) == "ANSWER=42\nSECOND=42\n"
      assert Fx.status(repo) == ""
      assert Fx.head(repo) == head
    end

    test "replace occurrence=all, delete_line, delete_file, truncate", %{
      parent: parent,
      repo: repo,
      head: head
    } do
      dest = Path.join(parent, "scratch")
      {:ok, _} = Probes.scratch_clone(repo, head, dest)

      all =
        admit!(
          probe("replace", %{
            "file" => "answer.txt",
            "pattern" => "42",
            "replacement" => "0",
            "occurrence" => "all"
          })
        )

      assert :ok = Probes.apply_probe(all, dest)
      assert File.read!(Path.join(dest, "answer.txt")) == "ANSWER=0\nSECOND=0\n"

      del_line = admit!(probe("delete_line", %{"file" => "lib/greet.txt", "pattern" => "hello"}))
      assert :ok = Probes.apply_probe(del_line, dest)
      assert File.read!(Path.join(dest, "lib/greet.txt")) == "keep me\nhello again\n"

      del_all =
        admit!(
          probe("delete_line", %{
            "file" => "lib/greet.txt",
            "pattern" => "hello",
            "occurrence" => "all"
          })
        )

      assert :ok = Probes.apply_probe(del_all, dest)
      assert File.read!(Path.join(dest, "lib/greet.txt")) == "keep me\n"

      trunc = admit!(probe("truncate", %{"file" => "fixture.json"}))
      assert :ok = Probes.apply_probe(trunc, dest)
      assert File.read!(Path.join(dest, "fixture.json")) == ""

      rm = admit!(probe("delete_file", %{"file" => "answer.txt"}))
      assert :ok = Probes.apply_probe(rm, dest)
      refute File.exists?(Path.join(dest, "answer.txt"))

      assert Fx.status(repo) == ""
    end

    test "revert_commit removes a feature commit's effect in the clone", %{
      parent: parent,
      repo: repo
    } do
      feature = Fx.commit(repo, %{"feature.txt" => "the feature\n"}, "add feature")
      dest = Path.join(parent, "scratch")
      {:ok, _} = Probes.scratch_clone(repo, feature, dest)
      assert File.exists?(Path.join(dest, "feature.txt"))

      by_sha = admit!(probe("revert_commit", %{"commit" => feature}))
      assert :ok = Probes.apply_probe(by_sha, dest)
      refute File.exists?(Path.join(dest, "feature.txt"))
      assert File.exists?(Path.join(repo, "feature.txt"))

      dest2 = Path.join(parent, "scratch2")
      {:ok, _} = Probes.scratch_clone(repo, feature, dest2)
      by_head = admit!(probe("revert_commit", %{"commit" => "HEAD"}))
      assert :ok = Probes.apply_probe(by_head, dest2)
      refute File.exists?(Path.join(dest2, "feature.txt"))
    end

    test "works from a LINKED worktree (Worktrees.provision's shape) and from an unreachable detached head",
         %{
           parent: parent,
           repo: repo
         } do
      wt = Fx.linked_worktree(repo, parent, Fx.head(repo))
      # a commit made in the linked worktree at detached HEAD: reachable from no ref
      detached = Fx.commit(wt, %{"only-here.txt" => "detached\n"}, "detached work")

      dest = Path.join(parent, "scratch")
      assert {:ok, ^dest} = Probes.scratch_clone(wt, detached, dest)
      assert File.read!(Path.join(dest, "only-here.txt")) == "detached\n"
      assert Fx.head(dest) == detached
      assert Fx.status(wt) == ""
    end

    test "an unapplicable probe is typed, not a silent no-op", %{
      parent: parent,
      repo: repo,
      head: head
    } do
      dest = Path.join(parent, "scratch")
      {:ok, _} = Probes.scratch_clone(repo, head, dest)

      absent =
        admit!(
          probe("replace", %{"file" => "answer.txt", "pattern" => "NOPE", "replacement" => "x"})
        )

      assert {:error, {:probe_unapplicable, :pattern_not_found}} =
               Probes.apply_probe(absent, dest)

      noop =
        admit!(
          probe("replace", %{"file" => "answer.txt", "pattern" => "42", "replacement" => "42"})
        )

      assert {:error, {:probe_unapplicable, :mutation_left_tree_unchanged}} =
               Probes.apply_probe(noop, dest)

      missing = admit!(probe("truncate", %{"file" => "nope.txt"}))
      assert {:error, {:probe_unapplicable, :file_not_found}} = Probes.apply_probe(missing, dest)

      bad_revert = admit!(probe("revert_commit", %{"commit" => "deadbeefdeadbeef"}))

      assert {:error, {:probe_unapplicable, {:revert_failed, _, _}}} =
               Probes.apply_probe(bad_revert, dest)

      assert Fx.status(dest) == ""
    end

    test "a committed symlink cannot aim a mutation outside the clone", %{
      parent: parent,
      repo: repo
    } do
      outside = Path.join(parent, "outside.txt")
      File.write!(outside, "secret 42\n")
      File.ln_s!(outside, Path.join(repo, "link.txt"))
      File.mkdir_p!(Path.join(repo, "real"))
      File.write!(Path.join(repo, "real/inner.txt"), "42\n")
      File.ln_s!(Path.join(repo, "real"), Path.join(repo, "dirlink"))
      head = Fx.commit(repo, %{}, "add symlinks")

      dest = Path.join(parent, "scratch")
      {:ok, _} = Probes.scratch_clone(repo, head, dest)

      file_link =
        admit!(probe("replace", %{"file" => "link.txt", "pattern" => "42", "replacement" => "0"}))

      assert {:error, {:probe_unapplicable, :symlink_refused}} =
               Probes.apply_probe(file_link, dest)

      dir_link = admit!(probe("truncate", %{"file" => "dirlink/inner.txt"}))

      assert {:error, {:probe_unapplicable, :symlink_refused}} =
               Probes.apply_probe(dir_link, dest)

      assert File.read!(outside) == "secret 42\n"
    end

    test "scratch_clone refuses a non-sha head and never removes a pre-existing dest", %{
      parent: parent,
      repo: repo,
      head: head
    } do
      dest = Path.join(parent, "already")
      File.mkdir_p!(dest)
      File.write!(Path.join(dest, "precious"), "keep")

      assert {:error, :scratch_exists} = Probes.scratch_clone(repo, head, dest)
      assert File.read!(Path.join(dest, "precious")) == "keep"

      assert {:error, :head_must_be_full_sha} =
               Probes.scratch_clone(repo, "main", Path.join(parent, "x"))

      assert {:error, {:not_a_repository, _, _}} =
               Probes.scratch_clone(parent, head, Path.join(parent, "y"))
    end
  end
end
