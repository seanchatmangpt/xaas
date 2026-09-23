defmodule Xaas.Receipt.RProjectionTest do
  @moduledoc """
  Chicago-style: a real sealed receipt (real Postgres sandbox, real git repo
  and worktree, real lease, the real fabric verifier running a real
  `exit_status` court step), exported by the real `SemanticReceipt.export/1`,
  written to disk, projected (the seal re-read from the same real fabric),
  and ADMITTED or REFUSED by the REAL fleet validator
  (`python3 ~/.claude/dfcm/validate_receipt.py`) -- never by a
  re-implementation of its schema.
  """

  use ExUnit.Case, async: false

  alias Xaas.Receipt.RProjection
  alias Xaas.Ultracode.{Lease, SemanticReceipt, SemanticWork}

  @provider "zcode-r-projection"
  @validator Path.expand("~/.claude/dfcm/validate_receipt.py")

  if not File.regular?(@validator) do
    @moduletag skip: "needs ~/.claude/dfcm/validate_receipt.py (the fleet R-schema validator)"
  end

  @acc "https://ggen-igniter.dev/ontology/semantic-jira#r-projection-acceptance"
  @court "https://ggen-igniter.dev/ontology/semantic-jira#r-projection-court"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      tickets: Application.get_env(:xaas, :ultracode_ticket_dir)
    }

    base = mktmp("r")
    repo = Path.join(base, "repo")
    File.mkdir_p!(repo)
    sha = init_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{"rdemo" => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "r-court" => court_suite("test -f hello.txt"),
      "r-fail" => court_suite("test -f no-such-file.txt")
    })

    on_exit(fn ->
      restore_env(:ultracode_repos, original.repos)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_ticket_dir, original.tickets)
    end)

    %{sha: sha, base: base, repo: repo}
  end

  test "a sealed ALIVE receipt projects to an R the real validator ADMITS",
       %{sha: sha, base: base, repo: repo} do
    {native_path, head} = sealed_native(sha, base, "r-court")

    assert {:ok, r_path, r} = RProjection.write(native_path, repo: repo)
    assert r_path == Path.join(base, "native-r-court.r.json")
    assert File.read!(r_path) |> Jason.decode!() == r

    assert r["identity"] == %{
             "subject" => "RP-1",
             "repo" => repo,
             "subject_sha" => head,
             "base_sha" => sha
           }

    assert r["authority"]["ceiling"] == "CONSTRUCT"
    assert "xaas-lease:epoch:" <> _ = r["authority"]["grant"]
    assert r["consequence"]["commits"] == [head]
    assert r["consequence"]["files_changed"] == ["worker-note.txt"]
    assert r["consequence"]["remote_effects"] == []

    assert [%{"cmd" => "/bin/sh -c 'test -f hello.txt'", "exit" => 0, "cwd" => ^repo}] =
             r["replay"]["commands"]

    assert r["replay"]["durable_location"] == native_path
    assert r["standing"]["value"] == "ALIVE"
    assert r["court"]["acceptance_results"] == %{@acc => true}

    assert {out, 0} = validate(r_path)
    assert out =~ "ADMITTED " <> r_path
  end

  test "a projection with a missing subject_sha is REFUSED by the real validator",
       %{sha: sha, base: base, repo: repo} do
    {native_path, _head} = sealed_native(sha, base, "r-court")
    headless = native_path |> File.read!() |> Jason.decode!() |> Map.delete("final_head")
    headless_path = Path.join(base, "headless.json")
    File.write!(headless_path, Jason.encode!(headless))

    assert {:ok, r_path, r} = RProjection.write(headless_path, repo: repo)
    refute Map.has_key?(r["identity"], "subject_sha")
    assert r["standing"]["value"] == "REFUSED(R_missing_identity)"
    assert r["standing"]["broken_term"] == "R_missing_identity"

    assert {out, 1} = validate(r_path)
    assert out =~ "REFUSED " <> r_path
    assert out =~ "subject_sha"
  end

  test "a subject_sha that is not a commit in the local repo is REFUSED by the real validator",
       %{sha: sha, base: base, repo: repo} do
    {native_path, _head} = sealed_native(sha, base, "r-court")

    {:ok, r_path, _r} =
      RProjection.write(native_path, repo: repo)

    foreign =
      r_path
      |> File.read!()
      |> Jason.decode!()
      |> put_in(["identity", "subject_sha"], sha_of("f"))

    foreign_path = Path.join(base, "foreign.r.json")
    File.write!(foreign_path, Jason.encode!(foreign))

    assert {out, 1} = validate(foreign_path)
    assert out =~ "R_missing_identity"
  end

  test "a court-refuted close projects BUILD_BROKEN with its broken term, still a valid R",
       %{sha: sha, base: base, repo: repo} do
    {native_path, _head} = sealed_native(sha, base, "r-fail")

    assert {:ok, r_path, r} = RProjection.write(native_path, repo: repo)
    assert r["standing"]["value"] == "BUILD_BROKEN"
    assert r["standing"]["broken_term"] == "mu_unlawful"
    # The exit is the verifier's observed exit from the sealed closing
    # evidence (`test -f` of a missing file exits 1), not derived from status.
    assert [%{"exit" => 1, "summary" => summary}] = r["replay"]["commands"]
    assert summary == "r-fail/court: status=fail"
    assert r["court"]["acceptance_results"] == %{@acc => false}

    assert {out, 0} = validate(r_path)
    assert out =~ "ADMITTED"
  end

  test "a native receipt altered after sealing is refused: its digest no longer recomputes",
       %{sha: sha, base: base, repo: repo} do
    {native_path, _head} = sealed_native(sha, base, "r-fail")
    sealed = native_path |> File.read!() |> Jason.decode!()

    # A build_broken close edited to claim ALIVE with a passing verifier.
    forged =
      sealed
      |> Map.put("outcome", "alive")
      |> put_in(["fabric_verifier", "status"], "pass")
      |> put_in(["fabric_verifier", "steps"], [%{"id" => "court", "status" => "pass"}])

    assert {:ok, %{"standing" => %{"value" => "BUILD_BROKEN"}}} =
             RProjection.project(sealed, repo: repo)

    assert {:ok, r} = RProjection.project(forged, repo: repo)
    assert r["standing"]["value"] == "REFUSED(receipt_digest_mismatch)"
    assert r["standing"]["broken_term"] == "R_missing_identity"
  end

  test "a native receipt with its digest stripped is refused, never defaulted to sealed",
       %{sha: sha, base: base, repo: repo} do
    {native_path, _head} = sealed_native(sha, base, "r-fail")
    sealed = native_path |> File.read!() |> Jason.decode!()

    # The DOCTRINE-court path: a build_broken close with `receipt_digest`
    # deleted, then edited to claim ALIVE with a passing verifier step.
    stripped =
      sealed
      |> Map.delete("receipt_digest")
      |> Map.put("outcome", "alive")
      |> put_in(["fabric_verifier", "status"], "pass")
      |> put_in(["fabric_verifier", "steps"], [%{"id" => "court", "status" => "pass"}])

    stripped_path = Path.join(base, "stripped.json")
    File.write!(stripped_path, Jason.encode!(stripped))

    assert {:ok, r_path, r} = RProjection.write(stripped_path, repo: repo)
    assert r["standing"]["value"] == "REFUSED(receipt_digest_absent)"
    assert r["standing"]["broken_term"] == "R_missing_identity"
    assert r["standing"]["derived_from"] =~ "unsealed: receipt_digest_absent"

    # No exit is manufactured from the forged status.
    assert [%{"exit" => -1, "summary" => summary}] = r["replay"]["commands"]
    assert summary =~ "exit not observed"

    # Still a well-formed R: the real validator admits the REFUSED record.
    assert {out, 0} = validate(r_path)
    assert out =~ "ADMITTED " <> r_path
  end

  test "a forged receipt whose digest the forger recomputed is refused: the fabric never sealed it",
       %{sha: sha, base: base, repo: repo} do
    {native_path, _head} = sealed_native(sha, base, "r-fail")
    sealed = native_path |> File.read!() |> Jason.decode!()

    forged =
      sealed
      |> Map.put("outcome", "alive")
      |> put_in(["fabric_verifier", "status"], "pass")
      |> put_in(["fabric_verifier", "steps"], [%{"id" => "court", "status" => "pass"}])

    # The digest is unkeyed: a forger can make it recompute.
    reforged = Map.put(forged, "receipt_digest", SemanticReceipt.receipt_digest(forged))
    assert SemanticReceipt.receipt_digest(reforged) == reforged["receipt_digest"]

    assert {:ok, r} = RProjection.project(reforged, repo: repo)
    assert r["standing"]["value"] == "REFUSED(receipt_not_fabric_sealed)"
    assert r["standing"]["broken_term"] == "R_missing_identity"
    assert [%{"exit" => -1}] = r["replay"]["commands"]

    # Same forgery pointed at an epoch the fabric does not hold.
    elsewhere = Map.put(forged, "epoch_id", Ecto.UUID.generate())
    elsewhere = Map.put(elsewhere, "receipt_digest", SemanticReceipt.receipt_digest(elsewhere))

    assert {:ok, %{"standing" => %{"value" => "REFUSED(receipt_not_fabric_sealed)"}}} =
             RProjection.project(elsewhere, repo: repo)
  end

  test "non-map native input and unreadable paths are typed refusals", %{base: base} do
    assert {:error, {:r_projection_refused, :not_a_map}} = RProjection.project("x")

    assert {:error, {:r_projection_refused, {:unreadable, :enoent}}} =
             RProjection.write(Path.join(base, "absent.json"))

    list_path = Path.join(base, "list.json")
    File.write!(list_path, "[1,2]")
    assert {:error, {:r_projection_refused, :not_a_map}} = RProjection.write(list_path)
  end

  # -- fixtures ---------------------------------------------------------------

  defp sealed_native(sha, base, suite) do
    {:ok, %{epoch: epoch, worktree: worktree}} =
      SemanticWork.materialize(descriptor(sha, suite), binding: :graph)

    {:ok, _claimed, token, _run} =
      Lease.claim_next(@provider, "worker-#{suite}", epoch_id: epoch.id)

    File.write!(Path.join(worktree, "worker-note.txt"), "done\n")
    git!(worktree, ["add", "worker-note.txt"])
    git!(worktree, ["commit", "-q", "-m", "worker"], commit_env())
    head = git!(worktree, ["rev-parse", "HEAD"])
    {:ok, _epoch, _receipt} = Lease.close(token, head, :alive, %{})

    {:ok, export} = SemanticReceipt.export(epoch.id)
    path = Path.join(base, "native-#{suite}.json")
    File.write!(path, Jason.encode!(export, pretty: true))
    {path, head}
  end

  defp descriptor(sha, suite) do
    %{
      "work_order_iri" => "urn:t:rp:#{suite}:#{System.unique_integer([:positive])}",
      "checkpoint_iri" => "urn:t:checkpoint:rp",
      "graph_digest" => "sha256:" <> String.duplicate("e", 64),
      "repository_identity" => "seanchatmangpt/rdemo",
      "execution_repo_alias" => "rdemo",
      "base_sha" => sha,
      "goal" => "Add a file.",
      "provider" => @provider,
      "verifier_suite" => suite,
      "execution_policy" => "autonomic_wave_attempt",
      "dependencies" => [],
      "court_map" => %{"acceptance" => %{@acc => %{"test" => "court"}}, "courts" => [@court]},
      "bridge" => %{
        "identity" => "RP-1",
        "repository" => "seanchatmangpt/rdemo",
        "base_sha" => sha,
        "subject" => "semantic-jira:rp:1",
        "requires" => %{"courts" => [@court], "acceptance" => [@acc], "falsifiers" => []}
      }
    }
  end

  defp court_suite(script) do
    %{
      env: %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
      max_output_bytes: 4096,
      result_format: "exit_status",
      steps: [
        %{id: "court", receipt: true, argv: ["/bin/sh", "-c", script], timeout_ms: 20_000}
      ]
    }
  end

  defp validate(path),
    do: System.cmd("python3", [@validator, path], stderr_to_stdout: true)

  defp sha_of(char), do: String.duplicate(char, 40)

  defp mktmp(label) do
    dir =
      Path.join(System.tmp_dir!(), "xaas-r-proj-#{label}-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", dir])
    String.trim(out)
  end

  defp commit_env do
    [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]
  end

  defp init_repo(repo) do
    {_, 0} =
      System.cmd("git", ["-C", repo, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    git!(repo, ["add", "hello.txt"])
    git!(repo, ["commit", "-m", "init", "--quiet"], commit_env())
    git!(repo, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args, env \\ []) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: env)
    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)
end
