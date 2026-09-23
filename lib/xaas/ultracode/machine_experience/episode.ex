defmodule Xaas.Ultracode.MachineExperience.Episode do
  @moduledoc """
  The two-episode MachineExperience ratchet (GC-26.9.23 GC23-9; PRD PR-014,
  PR-016; ARD sections 13 and 15; lane V23-M).

  `prepare/1` makes an UNKNOWN-class episode: the deterministic format-drift
  subject and two-order work graph of `Xaas.Ultracode.SemanticDrive.Episode`
  (lane V23-D), with every order's `requires_capability` REMOVED and a
  `failure_class` added -- the orders say what is wrong, not how to fix it.

  `run/1` routes the episode's order through `Xaas.Ultracode.MachineExperience.route/2`
  over the admitted-experience graph it is given, then:

    * KNOWN (an admitted MachineExperience applies) -- drives the order
      through the no-LLM `Xaas.Ultracode.SemanticDrive` with the
      experience's capability and the route's provenance (the experience
      IRI), no exploration: Episode 2;
    * UNKNOWN with no exploration artifact -- executes nothing; writes the
      route and a fleet-R-shaped `unknown.json` (standing UNKNOWN) and
      returns `{:unknown, typed}`: the order stays UNKNOWN until an
      exploration is recorded (or an experience is admitted);
    * UNKNOWN with `exploration.json` -- admits the artifact and its budget
      (`Xaas.Ultracode.MachineExperience.Exploration`), drives each
      admissible candidate through the same no-LLM drive while the budget
      lasts, and on the first candidate whose evidence meets the budget's
      requirement manufactures the MachineExperience (ggen_igniter's real
      `SemanticJira.machine_experience/1` via `scripts/machine_experience.exs`),
      admits it (`MachineExperience.admit/4`), has ggen_igniter's SHACL court
      judge the Turtle against the pack's `sj:MachineExperienceShape`, and
      records it: Episode 1. An exhausted budget is the receipted UNKNOWN
      `exploration_budget_exhausted`.

  Every run writes `route.json` and `order.ttl` (the order's RDF the
  predicate was evaluated on) and, when it reaches a drive, the composed
  OCEL log (`ocel.json` court vocabulary, `ocel2.json` OCEL 2.0 standard):
  the router's `RouteDecided`, the exploration's `ExplorationStarted` /
  `ExplorationCompleted` (at the artifact's own recorded times, related to
  the proposer as a non-deterministic `Provider`), the drive's own recorded
  events, and `MachineExperienceAdmitted` -- sorted by observed time --
  plus `episode.json` (standing, route, steps, event counts by class, LLM
  provider events, exploration events). An episode whose `episode.json`
  exists is refused (`episode_already_driven`).

  Nothing here runs a model: the exploration artifact is read, never made.
  """

  alias Xaas.Ultracode.{MachineExperience, SemanticDrive, Worktrees}
  alias Xaas.Ultracode.MachineExperience.Exploration
  alias Xaas.Ultracode.Ocel.Validator
  alias Xaas.Ultracode.SemanticDrive.{Episode, Ocel}

  @schema "xaas/machine-experience-episode/v1"
  @route_schema "xaas/machine-experience-route/v1"
  @failure_class "format_drift"
  @checkpoint_obj "checkpoint:GC-26.9.23"
  @checkpoint_iri "https://ggen-igniter.dev/sjira/v26.9.23#GC-26.9.23"
  @exploration_classes ~w(ExplorationStarted ExplorationCompleted)

  @doc "The default failure class of a prepared episode (`format_drift`)."
  @spec failure_class() :: String.t()
  def failure_class, do: @failure_class

  # ---------------------------------------------------------------------------
  # prepare
  # ---------------------------------------------------------------------------

  @doc """
  Prepares UNKNOWN-class episode `:name` in `:out_dir`: `SemanticDrive.Episode.prepare/1`
  (options `:repo`, `:name`, `:base`, `:drift`, `:repository`) into a
  scratch dir, then `work.json` with every order's `requires_capability`
  removed and `failure_class` (`:failure_class`, default `format_drift`)
  added, an empty `ledger.ndjson` and `prepare.json`. `{:ok, facts}` or the
  prepare refusal.
  """
  @spec prepare(keyword()) :: {:ok, map()} | {:refused, map()}
  def prepare(opts) do
    name = Keyword.fetch!(opts, :name)
    out_dir = Keyword.fetch!(opts, :out_dir)
    failure_class = Keyword.get(opts, :failure_class, @failure_class)
    scratch = scratch_dir("me-prepare")

    try do
      prepare_opts =
        opts
        |> Keyword.take([:repo, :name, :base, :drift, :repository])
        |> Keyword.put(:out_dir, scratch)

      with {:ok, facts} <- Episode.prepare(prepare_opts) do
        graph = scratch |> Path.join("work.json") |> File.read!() |> Jason.decode!()

        rows =
          Enum.map(graph["work_orders"], fn row ->
            row
            |> Map.delete("requires_capability")
            |> Map.put("failure_class", failure_class)
            |> Map.put(
              "title",
              "#{row["identity"]} of MachineExperience episode #{name}: repair the #{failure_class} of #{facts["drift"]["path"]}"
            )
            |> Map.put(
              "description",
              "Failure class #{failure_class} on subject #{facts["branch"]} (drift commit #{facts["subject_sha"]} changes #{facts["drift"]["path"]}). The order declares no capability: it routes KNOWN only from an admitted MachineExperience, else UNKNOWN (PRD PR-014, PR-016)."
            )
          end)

        graph = Map.put(graph, "work_orders", rows)
        File.mkdir_p!(out_dir)
        write_json(Path.join(out_dir, "work.json"), graph)
        File.write!(Path.join(out_dir, "ledger.ndjson"), "")

        facts =
          facts
          |> Map.merge(%{
            "schema" => "xaas/machine-experience-prepare/v1",
            "failure_class" => failure_class,
            "requires_capability" => "removed from every order",
            "work_graph" => Path.join(out_dir, "work.json"),
            "ledger" => Path.join(out_dir, "ledger.ndjson")
          })

        write_json(Path.join(out_dir, "prepare.json"), facts)
        {:ok, facts}
      end
    after
      File.rm_rf(scratch)
    end
  end

  # ---------------------------------------------------------------------------
  # route only (the court's falsifier surface)
  # ---------------------------------------------------------------------------

  @doc """
  Routes order `:order` (default `"EP-A"`) of the work graph `:work` over the
  Turtle files `:experience`. `{:known, route}` / `{:unknown, typed}` /
  `{:refused, typed}`; nothing is written and nothing executes.
  """
  @spec route(keyword()) :: {:known, map()} | {:unknown, map()} | {:refused, map()}
  def route(opts) do
    with {:ok, row} <- order_row(Keyword.fetch!(opts, :work), Keyword.get(opts, :order, "EP-A")),
         {:ok, store} <- MachineExperience.load(Keyword.get(opts, :experience, [])) do
      MachineExperience.route(row, store)
    end
  end

  # ---------------------------------------------------------------------------
  # run
  # ---------------------------------------------------------------------------

  @doc """
  Runs episode `:name` in `:out_dir` (see the moduledoc). Options:
  `:ggen_igniter_dir` (the graph side), `:experience` (Turtle paths, the
  admitted-experience graph; default none), `:exploration` (default
  `<out_dir>/exploration.json`), `:order` (`"EP-A"`), `:env` (what the
  no-LLM guard judges; default `System.get_env()`), `:ggen_build_path`,
  `:pin_ref`, `:repo_path` (the subject repository; default the registered
  `ggen_igniter` alias), `:command` (the invocation recorded in receipts).

  `{:ok, summary}` (standing ALIVE), `{:unknown, typed}` (standing UNKNOWN,
  receipted in `unknown.json`) or `{:refused, typed}`.
  """
  @spec run(keyword()) :: {:ok, map()} | {:unknown, map()} | {:refused, map()}
  def run(opts) do
    out_dir = Keyword.fetch!(opts, :out_dir)
    env = Keyword.get(opts, :env) || System.get_env()
    started = now()

    with :ok <- not_driven(out_dir),
         :ok <- SemanticDrive.no_llm_guard(env),
         {:ok, row} <-
           order_row(Path.join(out_dir, "work.json"), Keyword.get(opts, :order, "EP-A")),
         {:ok, sources} <- sources(Keyword.get(opts, :experience, [])),
         {:ok, store} <- MachineExperience.load(Enum.map(sources, & &1["path"])) do
      ctx = %{
        opts: opts,
        name: Keyword.fetch!(opts, :name),
        out_dir: out_dir,
        env: env,
        row: row,
        sources: sources,
        started: started,
        steps: ["guard", "route"],
        events: [],
        objects: %{},
        command: Keyword.get(opts, :command, "Xaas.Ultracode.MachineExperience.Episode.run/1")
      }

      decided_at = now()
      decision = MachineExperience.route(row, store)
      exploration = Keyword.get(opts, :exploration) || Path.join(out_dir, "exploration.json")

      # An UNKNOWN with no exploration executes nothing; its record goes to
      # <out_dir>/unknown/ so a later run (with an exploration, or with an
      # admitted experience) never overwrites the evidence of that UNKNOWN.
      record_dir =
        case decision do
          {:unknown, _} ->
            if File.regular?(exploration), do: out_dir, else: Path.join(out_dir, "unknown")

          _ ->
            out_dir
        end

      File.mkdir_p!(record_dir)
      File.write!(Path.join(record_dir, "order.ttl"), MachineExperience.order_turtle(row))

      ctx =
        ctx
        |> Map.merge(%{record_dir: record_dir, exploration: exploration})
        |> order_objects()
        |> route_event(decision, decided_at)

      case decision do
        {:known, route} ->
          write_route(ctx, "KNOWN", route, decided_at)
          known(ctx, route)

        {:unknown, typed} ->
          write_route(ctx, "UNKNOWN", typed, decided_at)
          unknown(ctx, typed)

        {:refused, typed} ->
          write_route(ctx, "REFUSED", typed, decided_at)
          {:refused, typed}
      end
    end
  end

  # -- KNOWN: drive the admitted route --------------------------------------------

  defp known(ctx, route) do
    case attempt(ctx, route, "drive") do
      {:ok, evidence, ctx} ->
        conclude(ctx, route, evidence, nil, nil)

      {:refused, typed, _ctx} ->
        {:refused, typed}
    end
  end

  # -- UNKNOWN: exploration or a receipted UNKNOWN -----------------------------------

  defp unknown(ctx, typed) do
    if File.regular?(ctx.exploration) do
      explore(ctx, ctx.exploration)
    else
      typed =
        typed
        |> Map.put("next", "bounded exploration (PRD PR-016) or an admitted MachineExperience")
        |> put_in(["detail", "exploration"], "absent: #{ctx.exploration}")

      write_unknown(ctx, typed)
    end
  end

  defp explore(ctx, path) do
    bytes = File.read!(path)
    digest = MachineExperience.sha256(bytes)

    with {:ok, exploration} <- decode_exploration(bytes),
         {:ok, plan} <- Exploration.admit(exploration, ctx.row, digest) do
      ctx =
        ctx
        |> Map.update!(:steps, &(&1 ++ ["explore"]))
        |> exploration_events(exploration, plan)

      used = %{
        "drive_runs" => 0,
        "elapsed_s" => plan["proposal_elapsed_s"],
        "candidates" => 0
      }

      try_candidates(ctx, plan, plan["candidates"], used, [])
    end
  end

  defp try_candidates(ctx, plan, [], used, attempts) do
    which = if plan["truncated"] != [], do: "candidates", else: "candidates_exhausted"
    write_unknown(ctx, Exploration.exhausted(plan, which, used, attempts))
  end

  defp try_candidates(ctx, plan, [candidate | rest], used, attempts) do
    case Exploration.next(plan, used) do
      {:exhausted, which} ->
        write_unknown(ctx, Exploration.exhausted(plan, which, used, attempts))

      :ok ->
        n = used["drive_runs"] + 1
        dir = if n == 1, do: "drive", else: "drive-#{n}"

        route = %{
          "source" => "exploration",
          "capability" => candidate["capability"],
          "order" => ctx.row["identity"],
          "producer" => plan["producer"],
          "producer_class" => plan["producer_class"],
          "exploration_digest" => plan["digest"]
        }

        t0 = System.monotonic_time(:millisecond)
        result = attempt(ctx, route, dir)
        seconds = div(System.monotonic_time(:millisecond) - t0 + 999, 1000)

        used = %{
          used
          | "drive_runs" => n,
            "elapsed_s" => used["elapsed_s"] + seconds,
            "candidates" => used["candidates"] + 1
        }

        case result do
          {:ok, evidence, attempt_ctx} ->
            shown = Exploration.evidence(evidence)

            entry = %{
              "capability" => candidate["capability"],
              "dir" => dir,
              "evidence" => shown,
              "seconds" => seconds
            }

            if Exploration.resolved?(plan, shown) do
              conclude(
                attempt_ctx,
                route,
                evidence,
                plan,
                Map.put(used, "attempts", attempts ++ [entry])
              )
            else
              try_candidates(
                ctx,
                plan,
                rest,
                used,
                attempts ++ [Map.put(entry, "resolved", false)]
              )
            end

          {:refused, typed, _ctx} ->
            entry = %{
              "capability" => candidate["capability"],
              "dir" => dir,
              "refused" => typed,
              "seconds" => seconds
            }

            try_candidates(ctx, plan, rest, used, attempts ++ [entry])
        end
    end
  end

  # One drive of the order with `route`'s capability: the routed work graph
  # (the episode graph with the capability set on the routed order) in
  # `<out_dir>/<dir>/work.json`, the episode ledger, the drive's artifacts in
  # `<out_dir>/<dir>/`.
  defp attempt(ctx, route, dir) do
    attempt_dir = Path.join(ctx.out_dir, dir)
    File.mkdir_p!(attempt_dir)

    graph = ctx.out_dir |> Path.join("work.json") |> File.read!() |> Jason.decode!()

    routed =
      Map.update!(graph, "work_orders", fn rows ->
        Enum.map(rows, fn row ->
          if row["identity"] == ctx.row["identity"],
            do: Map.put(row, "requires_capability", route["capability"]),
            else: row
        end)
      end)

    write_json(Path.join(attempt_dir, "work.json"), routed)

    drive_opts =
      [
        ggen_igniter_dir: Keyword.fetch!(ctx.opts, :ggen_igniter_dir),
        work_graph: Path.expand(Path.join(attempt_dir, "work.json")),
        ledger: Path.expand(Path.join(ctx.out_dir, "ledger.ndjson")),
        order: ctx.row["identity"],
        out_dir: attempt_dir,
        env: ctx.env,
        route: route,
        ggen_build_path: Keyword.get(ctx.opts, :ggen_build_path),
        pin_ref: Keyword.get(ctx.opts, :pin_ref)
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    ctx =
      Map.update!(ctx, :steps, &(&1 ++ Enum.map(SemanticDrive.steps(), fn s -> "drive:#{s}" end)))

    case SemanticDrive.drive(drive_opts) do
      {:ok, _summary} ->
        evidence =
          Map.new(
            [
              {"drive", "drive.json"},
              {"verification", "verification.json"},
              {"receipt", "receipt.json"},
              {"r", "receipt.r.json"},
              {"hops", "hops.json"},
              {"ocel", "ocel.json"}
            ],
            fn {key, file} ->
              {key, attempt_dir |> Path.join(file) |> File.read!() |> Jason.decode!()}
            end
          )
          |> Map.put("dir", attempt_dir)

        {:ok, evidence, ctx}

      {:refused, typed} ->
        {:refused, typed, ctx}
    end
  end

  # -- conclusion ---------------------------------------------------------------------

  defp conclude(ctx, route, evidence, plan, used) do
    with {:ok, ctx, experience_record} <- maybe_manufacture(ctx, route, evidence, plan),
         {:ok, drive_obs} <- Ocel.from_court_form(evidence["ocel"]) do
      {drive_events, drive_objects} = drive_obs
      event_types = Ocel.event_classes() ++ Ocel.extension_classes()

      objects =
        Map.merge(ctx.objects, drive_objects, fn _id, mine, theirs ->
          %{
            theirs
            | attributes: Map.merge(mine.attributes, theirs.attributes),
              relationships: Enum.uniq(mine.relationships ++ theirs.relationships)
          }
        end)
        |> Map.merge(experience_record[:objects] || %{})

      events =
        (ctx.events ++ drive_events ++ (experience_record[:events] || []))
        |> Enum.with_index()
        |> Enum.sort_by(fn {event, index} ->
          {DateTime.to_unix(event.time, :microsecond), index}
        end)
        |> Enum.map(&elem(&1, 0))

      observations = {events, objects}
      court = Ocel.court_form(observations, event_types)
      standard = Ocel.standard_form(observations, event_types)

      case Validator.validate(court) do
        {:ok, _report} ->
          write_json(Path.join(ctx.out_dir, "ocel.json"), court)
          write_json(Path.join(ctx.out_dir, "ocel2.json"), standard)
          summary = summary(ctx, route, evidence, plan, used, experience_record, court)
          write_json(Path.join(ctx.out_dir, "episode.json"), summary)
          {:ok, summary}

        {:error, violations} ->
          {:refused,
           typed(
             "REFUSED(ocel_nonconformant)",
             "ocel_nonconformant",
             "R_missing_consequence",
             "ocel",
             %{
               "violations" => Enum.take(violations, 10)
             }
           )}
      end
    end
  end

  defp maybe_manufacture(ctx, %{"source" => "exploration"} = route, evidence, plan) do
    source = %{
      "episode" => ctx.name,
      "order" => ctx.row["replay_identity"],
      "exploration_digest" => plan["digest"]
    }

    refs =
      ~w(receipt.json receipt.r.json verification.json hops.json ocel.json)
      |> Enum.map(&Path.join(evidence["dir"], &1))

    routed_row = Map.put(ctx.row, "requires_capability", route["capability"])
    gctx = graph_ctx(ctx)

    try do
      with {:ok, fields} <- MachineExperience.generalize(ctx.row, evidence, source),
           {:ok, experience} <-
             manufacture(gctx, MachineExperience.experience_attrs(routed_row, evidence, refs)),
           {:ok, admission} <- MachineExperience.admit(experience, fields, ctx.row, evidence),
           ttl = MachineExperience.to_turtle(experience, admission),
           {:ok, report} <- validate_shape(gctx, ttl) do
        iri = MachineExperience.iri(experience)
        ttl_path = Path.join(ctx.out_dir, "machine_experience.ttl")
        File.write!(ttl_path, ttl)

        record = %{
          "schema" => "xaas/machine-experience-record/v1",
          "machine_experience" => iri,
          "admission_node" => iri <> "-admission",
          "experience" => experience,
          "admission" => admission,
          "shape_report" => report,
          "ttl" => ttl_path,
          "ttl_sha256" => MachineExperience.sha256(ttl)
        }

        write_json(Path.join(ctx.out_dir, "machine_experience.json"), record)
        me_obj = "machine-experience:" <> iri

        objects = %{
          me_obj => %{
            type: "MachineExperience",
            attributes: %{
              "iri" => iri,
              "experience_digest" => experience["experience_digest"],
              "admission_digest" => admission["admission_digest"],
              "problem_class" => admission["problem_class"],
              "standing" => experience["standing"],
              "authority" => experience["authority"],
              "admission" => admission["admission"]
            },
            relationships: [
              {"capability:" <> admission["admitted_capability"], "admitted-capability"}
            ]
          }
        }

        event = %{
          type: "MachineExperienceAdmitted",
          time: now(),
          attributes: %{
            "machine_experience" => iri,
            "experience_digest" => experience["experience_digest"],
            "admission_digest" => admission["admission_digest"],
            "problem_class" => admission["problem_class"],
            "capability" => admission["admitted_capability"],
            "shape" => "conforms"
          },
          relationships: [
            {me_obj, "machine-experience"},
            {"workorder:" <> ctx.row["identity"], "work-order"},
            {"receipt:" <> evidence["receipt"]["receipt_id"], "source-receipt"},
            {"capability:" <> admission["admitted_capability"], "capability"}
          ]
        }

        ctx = Map.update!(ctx, :steps, &(&1 ++ ["manufacture", "admit", "validate"]))
        {:ok, ctx, %{objects: objects, events: [event], record: record}}
      end
    after
      File.rm_rf(gctx.scratch)
    end
  end

  defp maybe_manufacture(ctx, _route, _evidence, _plan), do: {:ok, ctx, %{}}

  defp manufacture(gctx, attrs) do
    attrs_path = Path.join(gctx.scratch, "attrs.json")
    out = Path.join(gctx.scratch, "experience.json")
    write_json(attrs_path, attrs)

    case SemanticDrive.graph_side(gctx, "run", [
           "--no-start",
           script(),
           "manufacture",
           attrs_path,
           out
         ]) do
      {0, %{"ok" => true}, _out} ->
        {:ok, out |> File.read!() |> Jason.decode!()}

      {code, json, out} ->
        {:refused,
         typed(
           "REFUSED(experience_refused)",
           "experience_refused",
           "admission_vacuous",
           "manufacture",
           %{"exit" => code, "reason" => brief(json, out)}
         )}
    end
  end

  defp validate_shape(gctx, ttl) do
    path = Path.join(gctx.scratch, "machine_experience.ttl")
    File.write!(path, ttl)

    case SemanticDrive.graph_side(gctx, "run", ["--no-start", script(), "validate", path]) do
      {0, %{"ok" => true, "shapes_checked" => checked} = report, _out} ->
        if "machine_experience_shape" in checked,
          do: {:ok, Map.drop(report, ["ok"])},
          else:
            {:refused,
             typed(
               "REFUSED(experience_shape_absent)",
               "experience_shape_absent",
               "admission_vacuous",
               "validate",
               %{"shapes_checked" => checked}
             )}

      {code, json, out} ->
        {:refused,
         typed(
           "REFUSED(experience_shape_refused)",
           "experience_shape_refused",
           "admission_vacuous",
           "validate",
           %{"exit" => code, "report" => json || String.slice(out, -600, 600)}
         )}
    end
  end

  defp graph_ctx(ctx) do
    ggen_dir = Keyword.fetch!(ctx.opts, :ggen_igniter_dir)
    build = Keyword.get(ctx.opts, :ggen_build_path) || Path.join([ggen_dir, "_build", "test"])
    {:ok, toolchain} = SemanticDrive.graph_toolchain(ggen_dir, build)

    %{
      ggen_dir: ggen_dir,
      scratch: scratch_dir("me-graph"),
      mix_env: "test",
      toolchain: toolchain,
      ggen_build_path: Keyword.get(ctx.opts, :ggen_build_path),
      timeout_s: 900
    }
  end

  @doc "The graph-side script (`scripts/machine_experience.exs`) of this checkout."
  @spec script() :: String.t()
  def script, do: Path.expand("scripts/machine_experience.exs", File.cwd!())

  # -- summary ------------------------------------------------------------------------

  defp summary(ctx, route, evidence, plan, used, experience_record, court) do
    events = court["ocel:events"]
    objects = court["ocel:objects"]

    nondeterministic =
      objects
      |> Enum.filter(&(&1["type"] == "Provider" and &1["attributes"]["deterministic"] == "false"))
      |> MapSet.new(& &1["id"])

    llm_events =
      Enum.count(events, fn e ->
        Enum.any?(e["relationships"], &MapSet.member?(nondeterministic, &1["objectId"]))
      end)

    drive = evidence["drive"]

    %{
      "schema" => @schema,
      "episode" => ctx.name,
      "order" => ctx.row["identity"],
      "checkpoint" => @checkpoint_iri,
      "standing" => "ALIVE",
      "decision" => if(route["source"] == "exploration", do: "UNKNOWN", else: "KNOWN"),
      "route" => route,
      "failure_class" => ctx.row["failure_class"],
      "experience_sources" => ctx.sources,
      "exploration" =>
        plan &&
          %{
            "digest" => plan["digest"],
            "producer" => plan["producer"],
            "producer_class" => plan["producer_class"],
            "budget" => plan["budget"],
            "used" => used,
            "rejected" => plan["rejected"],
            "truncated" => plan["truncated"]
          },
      "machine_experience" =>
        experience_record[:record] &&
          Map.take(
            experience_record[:record],
            ~w(machine_experience admission_node ttl ttl_sha256)
          )
          |> Map.put(
            "experience_digest",
            experience_record[:record]["experience"]["experience_digest"]
          )
          |> Map.put(
            "admission_digest",
            experience_record[:record]["admission"]["admission_digest"]
          ),
      "drive" => %{
        "dir" => evidence["dir"],
        "standing" => drive["standing"],
        "head" => drive["subject"]["head"],
        "tuple_digest" => drive["tuple_digest"],
        "provider" => drive["provider"]
      },
      "steps" => ctx.steps,
      "step_count" => length(ctx.steps),
      "ocel" => %{
        "events" => length(events),
        "objects" => length(objects),
        "by_class" => Enum.frequencies_by(events, & &1["type"]),
        "llm_provider_events" => llm_events,
        "exploration_events" => Enum.count(events, &(&1["type"] in @exploration_classes)),
        "equivalent" => true
      },
      "no_llm_guard" => "passed",
      "started_at" => DateTime.to_iso8601(ctx.started),
      "finished_at" => DateTime.to_iso8601(now())
    }
  end

  # -- UNKNOWN receipt ----------------------------------------------------------------

  defp write_unknown(ctx, typed) do
    repo = repo_path(ctx)
    path = Path.join(ctx.record_dir, "unknown.json")

    receipt = %{
      "identity" => %{
        "subject" => "episode #{ctx.name} #{ctx.row["identity"]}",
        "repo" => repo,
        "subject_sha" => ctx.row["base_sha"],
        "base_sha" => ctx.row["base_sha"],
        "work_order" => ctx.row["identity"],
        "failure_class" => ctx.row["failure_class"]
      },
      "authority" => %{
        "ceiling" => ctx.row["authority_ceiling"] || "CONSTRUCT",
        "grant" => "NONE (routing only: nothing executed)",
        "actor" => "xaas-machine-experience-router"
      },
      "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
      "replay" => %{
        "commands" => [
          %{
            "cmd" => ctx.command,
            "cwd" => File.cwd!(),
            "exit" => 4,
            "summary" => "UNKNOWN(#{typed["reason"]})"
          }
        ],
        "durable_location" => path
      },
      "standing" => %{
        "value" => "UNKNOWN",
        "derived_from" =>
          "route #{typed["reason"]} of order #{ctx.row["identity"]} at subject #{ctx.row["base_sha"]} (route.json)",
        "reason" => typed["reason"]
      },
      "unknown" => typed,
      "steps" => ctx.steps
    }

    write_json(path, receipt)
    {:unknown, Map.put(typed, "receipt", path)}
  end

  # -- route record + OCEL prelude -------------------------------------------------------

  defp write_route(ctx, decision, value, decided_at) do
    write_json(Path.join(ctx.record_dir, "route.json"), %{
      "schema" => @route_schema,
      "episode" => ctx.name,
      "order" => ctx.row["identity"],
      "order_iri" => MachineExperience.order_iri(ctx.row),
      "order_turtle_sha256" => MachineExperience.sha256(MachineExperience.order_turtle(ctx.row)),
      "failure_class" => ctx.row["failure_class"],
      "declared_capability" => ctx.row["requires_capability"],
      "decision" => decision,
      "route" => value,
      "experience_sources" => ctx.sources,
      "decided_at" => DateTime.to_iso8601(decided_at)
    })
  end

  defp order_objects(ctx) do
    row = ctx.row

    objects = %{
      @checkpoint_obj => %{
        type: "GoalCheckpoint",
        attributes: %{"iri" => @checkpoint_iri},
        relationships: []
      },
      ("workorder:" <> row["identity"]) => %{
        type: "WorkOrder",
        attributes: %{
          "identity" => row["identity"],
          "standing" => row["standing"],
          "failure_class" => row["failure_class"]
        },
        relationships: [{@checkpoint_obj, "checkpoint"}]
      }
    }

    %{ctx | objects: objects}
  end

  defp route_event(ctx, decision, time) do
    {attributes, relationships, objects} =
      case decision do
        {:known, %{"source" => "machine_experience"} = route} ->
          id = "machine-experience:" <> route["machine_experience"]

          {%{
             "decision" => "KNOWN",
             "source" => "machine_experience",
             "capability" => route["capability"],
             "machine_experience" => route["machine_experience"],
             "experience_digest" => route["experience_digest"]
           }, [{id, "machine-experience"}],
           %{
             id => %{
               type: "MachineExperience",
               attributes: %{
                 "iri" => route["machine_experience"],
                 "experience_digest" => route["experience_digest"],
                 "admission" => route["admission"],
                 "problem_class" => route["problem_class"]
               },
               relationships: []
             }
           }}

        {:known, route} ->
          {%{
             "decision" => "KNOWN",
             "source" => route["source"],
             "capability" => route["capability"]
           }, [], %{}}

        {:unknown, typed} ->
          {%{
             "decision" => "UNKNOWN",
             "reason" => typed["reason"],
             "experiences_considered" => length(typed["detail"]["experiences_considered"] || [])
           }, [], %{}}

        {:refused, typed} ->
          {%{"decision" => "REFUSED", "reason" => typed["reason"]}, [], %{}}
      end

    event = %{
      type: "RouteDecided",
      time: time,
      attributes: Map.put(attributes, "failure_class", ctx.row["failure_class"]),
      relationships: [{"workorder:" <> ctx.row["identity"], "work-order"} | relationships]
    }

    %{ctx | events: ctx.events ++ [event], objects: Map.merge(ctx.objects, objects)}
  end

  defp exploration_events(ctx, exploration, plan) do
    producer = "provider:" <> plan["producer"]
    {:ok, started, 0} = DateTime.from_iso8601(exploration["started_at"])
    {:ok, finished, 0} = DateTime.from_iso8601(exploration["finished_at"])
    wo = {"workorder:" <> ctx.row["identity"], "work-order"}

    candidate_objects =
      Map.new(plan["candidates"], fn c ->
        {"capability:" <> c["capability"],
         %{
           type: "Capability",
           attributes: %{"capability_id" => c["capability"], "standing" => "CANDIDATE"},
           relationships: []
         }}
      end)

    objects =
      ctx.objects
      |> Map.merge(candidate_objects)
      |> Map.put(producer, %{
        type: "Provider",
        attributes: %{
          "provider" => plan["producer"],
          "provider_class" => plan["producer_class"],
          "deterministic" => false,
          "role" => "exploration candidate proposer"
        },
        relationships: []
      })

    events = [
      %{
        type: "ExplorationStarted",
        time: started,
        attributes: %{
          "producer" => plan["producer"],
          "problem_class" => exploration["problem_class"],
          "budget" => plan["budget"]
        },
        relationships: [wo, {producer, "proposer"}]
      },
      %{
        type: "ExplorationCompleted",
        time: finished,
        attributes: %{
          "producer" => plan["producer"],
          "outcome" => "CANDIDATE",
          "candidates" => Enum.map(plan["candidates"], & &1["capability"]),
          "exploration_digest" => plan["digest"],
          "elapsed_s" => plan["proposal_elapsed_s"]
        },
        relationships:
          [wo, {producer, "proposer"}] ++
            Enum.map(plan["candidates"], &{"capability:" <> &1["capability"], "candidate"})
      }
    ]

    %{ctx | objects: objects, events: ctx.events ++ events}
  end

  # -- helpers ------------------------------------------------------------------------

  defp not_driven(out_dir) do
    if File.exists?(Path.join(out_dir, "episode.json")),
      do:
        {:refused,
         typed(
           "REFUSED(episode_already_driven)",
           "episode_already_driven",
           "mu_on_O",
           "episode",
           %{
             "out_dir" => out_dir
           }
         )},
      else: :ok
  end

  defp order_row(work, order) do
    with {:ok, bytes} <- File.read(work),
         {:ok, %{"work_orders" => rows}} when is_list(rows) <- Jason.decode(bytes),
         %{} = row <- Enum.find(rows, &(&1["identity"] == order)) do
      {:ok, row}
    else
      _ ->
        {:refused,
         typed(
           "REFUSED(order_not_in_work_graph)",
           "order_not_in_work_graph",
           "mu_on_O",
           "route",
           %{
             "work" => work,
             "order" => order
           }
         )}
    end
  end

  defp sources(paths) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, acc} ->
      case File.read(path) do
        {:ok, bytes} ->
          {:cont, {:ok, acc ++ [%{"path" => path, "sha256" => MachineExperience.sha256(bytes)}]}}

        {:error, reason} ->
          {:halt,
           {:refused,
            typed(
              "REFUSED(experience_graph_unreadable)",
              "experience_graph_unreadable",
              "mu_on_O",
              "route",
              %{"path" => path, "error" => inspect(reason)}
            )}}
      end
    end)
  end

  defp decode_exploration(bytes) do
    case Jason.decode(bytes) do
      {:ok, %{} = exploration} ->
        {:ok, exploration}

      _ ->
        {:refused,
         typed(
           "REFUSED(exploration_inadmissible)",
           "exploration_inadmissible",
           "mu_on_O",
           "explore",
           %{
             "field" => "json"
           }
         )}
    end
  end

  defp repo_path(ctx) do
    Keyword.get(ctx.opts, :repo_path) ||
      case Worktrees.registry_entry("ggen_igniter") do
        {:ok, entry} -> entry.path
        _ -> Keyword.get(ctx.opts, :ggen_igniter_dir)
      end
  end

  defp brief(%{"reason" => reason}, _out), do: reason
  defp brief(%{} = json, _out), do: json
  defp brief(_nil, out), do: String.slice(out, -600, 600)

  defp typed(standing, reason, broken_term, hop, detail) do
    %{
      "standing" => standing,
      "reason" => reason,
      "broken_term" => broken_term,
      "hop" => hop,
      "detail" => detail
    }
  end

  defp write_json(path, value), do: File.write!(path, Jason.encode!(value, pretty: true) <> "\n")

  defp scratch_dir(label) do
    dir = Path.join(System.tmp_dir!(), "xaas-#{label}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp now, do: DateTime.utc_now()
end
