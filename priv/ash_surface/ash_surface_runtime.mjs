import { z } from "zod";

/**
 * JavaScript projection of an AshSurface contract.
 *
 * This file is ordinary executable JavaScript. JSDoc is the static/editor typing
 * surface and Zod is the executable boundary schema. TypeScript is not required,
 * emitted, or consumed.
 */

export const SURFACE_RUNTIME_VERSION = "26.10.7";
const SUPPORTED_SURFACE_MAJORS = [0, 26];
const KNOWN_TRANSPORTS = Object.freeze(["http", "phoenix_channel"]);
const REFUSAL_PREFIX = "REFUSED_";
const RECONCILE_STATUSES = Object.freeze(["COMPLETED", "NOT_OBSERVED", "STILL_UNKNOWN"]);
const DISPATCH_STATES = Object.freeze(["not_dispatched", "completed", "unknown_after_dispatch"]);
const DISPATCH_OUTCOMES = Object.freeze(["SUCCESS", "UNKNOWN_AFTER_DISPATCH"]);
// SHA-256 rendered as lowercase hex (request digests, derived idempotency keys).
const DIGEST_HEX_LENGTH = 64;
export const IDEMPOTENCY_PROTOCOL = "ash_surface.idempotency/1";
// v26.10.7 F6 selection-frontier vocabulary: delegated per-transport dimension
// facts (cost/latency lower is better; privacy higher is better). Twin of
// lib/ash_surface/transport.ex (@dimensions / @dimension_classes).
const KNOWN_DIMENSIONS = Object.freeze(["cost", "latency", "privacy"]);
const KNOWN_DIMENSION_CLASSES = Object.freeze(["low", "medium", "high"]);
const DIMENSION_PRIORITY = KNOWN_DIMENSIONS;
// A refusal code is the prefix plus a reason TOKEN ([A-Za-z0-9_]+). Codes flow
// into logs, events and receipts, so line terminators and other free text are
// not admitted (mirrors AshSurface.Vocabulary.refusal_code?/1 exactly).
const REFUSAL_CODE_PATTERN = new RegExp(`^${REFUSAL_PREFIX}[A-Za-z0-9_]+$`);

/**
 * The runtime's closed vocabularies, exported as one frozen record so other
 * languages can pin drift tests against the runtime's own single definitions
 * (each field is built from the constant the runtime actually uses).
 */
export const VOCABULARY = Object.freeze({
  refusalPrefix: REFUSAL_PREFIX,
  reconcileStatuses: RECONCILE_STATUSES,
  knownTransports: KNOWN_TRANSPORTS,
  dimensionClasses: KNOWN_DIMENSION_CLASSES,
  dimensions: KNOWN_DIMENSIONS,
  digestHexLength: DIGEST_HEX_LENGTH,
  dispatchStates: DISPATCH_STATES,
  dispatchOutcomes: DISPATCH_OUTCOMES,
  idempotencyProtocol: IDEMPOTENCY_PROTOCOL,
});

const jsonRecordSchema = z.record(z.string(), z.unknown());

// F3 (tightened by chicago-standing-table-029): one canonical standing
// vocabulary, owned lib-side by AshSurface.Standing
// (lib/ash_surface/standing.ex). The five base standings are the closed
// z.enum() core; the open REFUSED class ("REFUSED_"-prefixed refusal
// standings, e.g. "REFUSED_NO_AUTHORITY") is the regex branch. Bare "REFUSED"
// is NOT a standing — a refusal must name its reason — and "UNKNOWN" is
// deliberately not a standing: it is a post-dispatch outcome.
export const STANDING_VALUES = Object.freeze([
  "ALIVE",
  "PARTIAL_ALIVE",
  "BLOCKED",
  "BUILD_BROKEN",
  "UNSUPPORTED",
]);

const standingSchema = z.union([
  z.enum(STANDING_VALUES),
  // The open REFUSED class: at least one reason char beyond the prefix —
  // bare "REFUSED" and the empty reason "REFUSED_" are not refusals (mirrors
  // lib/ash_surface/standing.ex "REFUSED_" <> _ rest law).
  z.string().regex(REFUSAL_CODE_PATTERN),
]);

// F3 refusal guard: every declared possible refusal is a "REFUSED_"-prefixed
// code with a named reason (mirrors the Elixir REFUSED_* refusal vocabulary,
// e.g. "REFUSED_UNKNOWN_ACTION"). Off-vocabulary names and the unnamed
// "REFUSED"/"REFUSED_" are refused at the boundary.
const refusalCodeSchema = z.string().regex(REFUSAL_CODE_PATTERN);

export const surfaceActionSchema = z
  .object({
    id: z.string().min(1),
    // v26.10.7 delegation: semanticId, authorityBoundary, doAuthority, and
    // receiptRequired are delegated facts. They arrive from the manifest's
    // custom.ash_surface metadata or are null — an absent key means "not
    // delegated" and surfaces as null; values are never defaulted or
    // re-derived client-side.
    semanticId: z.string().min(1).nullable().default(null),
    resource: z.string().min(1),
    action: z.string().min(1),
    authorityBoundary: z
      .enum(["OBSERVE", "SELECT", "CONSTRUCT", "DO"])
      .nullable()
      .default(null),
    doAuthority: z.boolean().nullable().default(null),
    receiptRequired: z.boolean().nullable().default(null),
    evidenceRequired: z.boolean().default(false),
    possibleRefusals: z.array(refusalCodeSchema).default([]),
    profile: jsonRecordSchema.default({}),
  })
  .passthrough();

export const observationProjectionSchema = z
  .object({
    observationId: z.string().min(1),
    exactSubject: z.string().min(1),
    observedAt: z.string().min(1),
    stateDigest: z.string().min(1),
    facts: jsonRecordSchema,
    evidenceRefs: z.array(z.string()).default([]),
    standing: standingSchema.default("ALIVE"),
    projectionPurpose: z.string().default("consumer_state_observation"),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
  })
  .passthrough();

export const planningEpisodeSchema = z
  .object({
    episodeId: z.string().min(1),
    worldStateRef: z.string().min(1),
    taskNetworkRef: z.string().nullable().optional(),
    plannerIdentity: z.string().min(1),
    policyIdentity: z.string().min(1),
    policyStanding: z.enum(["VALID_STRONG", "VALID_STRONG_CYCLIC", "REFUSED"]).default("VALID_STRONG"),
    candidateActions: z.array(z.unknown()).default([]),
    authorityCeiling: z.enum(["SELECT", "CONSTRUCT"]).default("SELECT"),
  })
  .passthrough();

export const eventProjectionSchema = z
  .object({
    eventId: z.string().min(1),
    sequence: z.number().int().nonnegative(),
    subjectRef: z.string().min(1),
    eventType: z.string().min(1),
    stateDigest: z.string().min(1),
    evidenceRef: z.string().nullable().optional(),
    receiptRef: z.string().nullable().optional(),
    payload: jsonRecordSchema.nullable().optional(),
    occurredAt: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
  })
  .passthrough();

export const ashSurfaceContractSchema = z
  .object({
    surfaceSchemaVersion: z.string().min(1),
    ashManifestSchemaVersion: z.string().min(1),
    generatorIdentity: z.string().optional(),
    manifestDigest: z.string().optional(),
    // Delegated IR-era envelope extensions (gapfix-test-surface-015 ledger;
    // re-adjudicated by chicago-ontology-producer-039 on the post-F4 tree):
    // ontologyDigest / applicationReleaseIdentity have NO live producer in
    // the Elixir surface pipeline (AshSurface.contract/2 never emits them);
    // their witnessed producer is upstream generation (the frozen F5 fixture
    // in digest_cross_language_v2.test.mjs). 039 verdict: the honest-producer
    // side is refused BY LAW — F4's MXEpisode binds surface.digest and the
    // subject repo/head at the episode layer from operator-supplied inputs
    // (no surface input); surface.digest would be circular (it digests the
    // contract that would carry the field); generator identity already has
    // its own field, and environment reads would break the frozen digest
    // goldens. The absence is now ENFORCED: presence of either field in
    // contract/2 output is RED at the tripwire
    // test/ash_surface/from_manifest_test.exs. Kept as typed optional rows —
    // present (upstream-witnessed) values are validated, absent values stay
    // absent (never defaulted).
    ontologyDigest: z.string().optional(),
    marketplaceIdentity: z.string().optional(),
    applicationReleaseIdentity: z.string().optional(),
    manifest: jsonRecordSchema,
    surface: z
      .object({
        profile: jsonRecordSchema.default({}),
        actions: z.array(surfaceActionSchema),
      })
      .passthrough(),
  })
  .passthrough();

/**
 * @typedef {Object} SurfaceAction
 * @property {string} id Stable Ash action identity.
 * @property {string|null} semanticId Delegated semantic URI; null when not delegated (v26.10.7 delegation).
 * @property {string} resource Fully-qualified Ash resource module name.
 * @property {string} action Ash action name.
 * @property {"OBSERVE"|"SELECT"|"CONSTRUCT"|"DO"|null} authorityBoundary Delegated; null when not delegated.
 * @property {boolean|null} doAuthority Delegated; null when not delegated.
 * @property {boolean|null} receiptRequired Delegated; null when not delegated.
 * @property {boolean} evidenceRequired
 * @property {string[]} possibleRefusals "REFUSED_"-prefixed refusal codes (F3 guard).
 * @property {Record<string, unknown>} profile Projection-only metadata.
 */

/**
 * @typedef {("ALIVE"|"PARTIAL_ALIVE"|"BLOCKED"|"BUILD_BROKEN"|"UNSUPPORTED"|string)} Standing
 * A canonical standing: one of `STANDING_VALUES` or a "REFUSED_"-prefixed
 * refusal standing (bare "REFUSED" is not a standing — a refusal must name
 * its reason). Mirrors `AshSurface.Standing` (lib/ash_surface/standing.ex).
 */

/**
 * @typedef {Object} TransportAdapter
 * @property {(context: {action: SurfaceAction, input: unknown, contract: AshSurfaceContract, signal?: AbortSignal}) => Promise<unknown>} invoke
 * @property {((action: SurfaceAction, contract: AshSurfaceContract) => boolean) | boolean} [available]
 * @property {((commandId: string) => Promise<{status: "COMPLETED"|"NOT_OBSERVED"|"STILL_UNKNOWN", receipt?: unknown}>)} [reconcile]
 */

/**
 * @typedef {Object} InvokeOptions
 * @property {string} [commandId] Caller-supplied command identity (a non-empty
 *   string, else INVALID_OPTIONS before dispatch); defaults to `cmd_<uuid>`
 *   (crypto.randomUUID, else getRandomValues v4, else a Math.random id; never throws).
 * @property {AbortSignal} [signal] Passed to the adapter. A signal already
 *   aborted before dispatch is a typed PRE-dispatch refusal
 *   (SurfaceRuntimeError DISPATCH_ABORTED_PRE_DISPATCH, no adapter call, no
 *   receipt, dispatchState "not_dispatched"). An abort AFTER dispatch settles
 *   the call as TRANSPORT_OUTCOME_UNKNOWN / UNKNOWN_AFTER_DISPATCH (cause code
 *   DISPATCH_ABORTED); the action is never replayed over another transport.
 *   `invoke(input, null)` is treated as `invoke(input, {})`.
 * @property {number} [timeoutMs] Opt-in dispatch deadline (positive finite
 *   milliseconds). An adapter that has not settled by then yields
 *   TRANSPORT_OUTCOME_UNKNOWN / UNKNOWN_AFTER_DISPATCH (cause code
 *   DISPATCH_TIMEOUT); no cross-transport retry. The timer is always cleared.
 * @property {string} [idempotencyKey] Only for actions whose profile admits
 *   `ash_surface.idempotency/1` (else IDEMPOTENCY_NOT_ADMITTED before dispatch).
 *   8..128 chars of [A-Za-z0-9_.:-], alphanumeric first (else
 *   INVALID_IDEMPOTENCY_KEY). Defaults to a key derived from (actionId, commandId).
 *   The key and the canonical request digest are bound into the receipt's
 *   `idempotency` member and passed to the adapter as `context.idempotency`.
 */

/**
 * @typedef {Object} RuntimeEvent
 * A structured, payload-free observability event delivered to `onEvent`:
 * `{type, ...ids/codes/transports/durations}` (never input or output values).
 * Types: transport.selected, dispatch.started, dispatch.completed,
 * dispatch.unknown_after_dispatch, dispatch.refused_pre_dispatch,
 * reconcile.result, reconcile.invalid_result, retry.requested, retry.skipped,
 * retry.replaying, retry.refused.
 * @property {string} type
 */

// Reconciliation verdict boundary: the documented TransportAdapter.reconcile
// reply. Only the status vocabulary is closed; every other key (receipt,
// commandId, ...) passes through untouched and the adapter's own object is
// returned (source refs preserved, never rebuilt).
export const reconcileResultSchema = z
  .object({
    status: z.enum(RECONCILE_STATUSES),
  })
  .passthrough();

/**
 * @typedef {Object} ActionSchemas
 * @property {{parse(value: unknown): unknown}} [input] Zod-compatible input schema.
 * @property {{parse(value: unknown): unknown}} [output] Zod-compatible output schema.
 */

/**
 * @typedef {Object} AshSurfaceContract
 * @property {string} surfaceSchemaVersion
 * @property {string} ashManifestSchemaVersion
 * @property {string} [generatorIdentity]
 * @property {Record<string, unknown>} manifest Canonical serialized Ash semantics.
 * @property {{profile: Record<string, unknown>, actions: SurfaceAction[]}} surface
 */

/**
 * @typedef {Object} SurfaceDecision
 * @property {string} actionId
 * @property {string[]} declared
 * @property {string[]} available
 * @property {"http"|"phoenix_channel"} selected
 * @property {"http"|"phoenix_channel"} preferred
 * @property {"preferred_available"|"preferred_unavailable"|"dimension_weighed"|"retry_pinned_transport"} reason
 * @property {"pre_dispatch_only"} fallback
 * @property {"not_dispatched"|"completed"|"unknown_after_dispatch"} dispatchState
 * @property {"undelegated"|"declared"} dimensions Typed presence of delegated dimension facts.
 * @property {Array<"http"|"phoenix_channel">} frontier Non-dominated available transports, declared order.
 */

export class SurfaceRuntimeError extends Error {
  constructor(code, message, options = {}) {
    super(message, options.cause ? { cause: options.cause } : undefined);
    this.name = "SurfaceRuntimeError";
    this.code = code;
    this.receipt = options.receipt ?? null;
    this.issues = options.issues ?? null;
  }
}

/**
 * Creates the JavaScript application-facing client directly from an AshSurface
 * contract.
 *
 * @param {Object} options
 * @param {unknown} options.contract Untrusted AshSurface JSON contract.
 * @param {Partial<Record<"http"|"phoenix_channel", TransportAdapter>>} options.transports
 * @param {"http"|"phoenix_channel"} [options.prefer="http"]
 * @param {Record<string, ActionSchemas>} [options.schemas] Zod schemas keyed by stable action id.
 * @param {(event: RuntimeEvent) => void} [options.onEvent] Opt-in observability
 * hook, called synchronously with frozen payload-free events; a throwing or
 * rejecting hook is swallowed and never affects dispatch.
 * Each action client exposes `invoke(input, callOptions)` and
 * `invokeWithReceipt(input, callOptions)` where `callOptions` is an
 * {@link InvokeOptions}. `actions` and each `resources[Resource]` record are
 * null-prototype objects: lookups never resolve inherited Object.prototype
 * names, and contract ids such as "__proto__" are ordinary keys.
 * `reconcile` validates the adapter reply against `reconcileResultSchema` and
 * rejects a malformed reply with INVALID_RECONCILE_RESULT.
 * `retryUnknown(receiptOrError, {input, signal?, timeoutMs?})` is the explicit,
 * never-automatic retry of an UNKNOWN_AFTER_DISPATCH receipt (or the
 * TRANSPORT_OUTCOME_UNKNOWN error carrying it) for an action admitting
 * `ash_surface.idempotency/1`: it reconciles on the original transport first
 * and replays (same commandId, same key, same transport unless the profile
 * admits `crossTransport`) ONLY on NOT_OBSERVED. Resolves
 * `{status: "COMPLETED"|"STILL_UNKNOWN", replayed: false, reconcile}` or
 * `{status: "REPLAYED", replayed: true, result, receipt}`.
 * @returns {{runtimeVersion: string, contract: AshSurfaceContract, actions: Record<string, Object>, resources: Record<string, Record<string, Object>>, events: Object, reconcile(commandId: string, transportName?: "http"|"phoenix_channel"): Promise<Object>, retryUnknown(receiptOrError: Object, options: {input: unknown, signal?: AbortSignal, timeoutMs?: number}): Promise<Object>, get(id: string): Object|null, inspect(id: string): Object}}
 */
export function createClient(options) {
  if (!options || typeof options !== "object") {
    throw new SurfaceRuntimeError("INVALID_OPTIONS", "createClient options must be an object");
  }

  const contract = parseContract(options.contract);
  const transports = options.transports ?? {};
  const prefer = options.prefer ?? "http";
  const schemas = options.schemas ?? {};
  const emit = makeEmitter(options.onEvent);

  assertPreferred(prefer);
  assertTransportAdapters(transports);

  // Null-prototype records keyed by contract-supplied ids: a resource or
  // action named "__proto__"/"constructor"/"toString" is an ordinary key and
  // can never reach Object.prototype.
  const actions = Object.create(null);
  const resources = Object.create(null);
  const eventListeners = new Map();
  const bindings = Object.create(null); // action id -> {action, actionSchemas}
  const env = { contract, transports, prefer, emit, actions, bindings };

  for (const action of contract.surface.actions) {
    if (Object.hasOwn(actions, action.id)) {
      throw new SurfaceRuntimeError(
        "DUPLICATE_ACTION_ID",
        `duplicate action id: ${action.id}`,
      );
    }

    const actionSchemas = Object.hasOwn(schemas, action.id) ? schemas[action.id] : undefined;
    bindings[action.id] = { action, actionSchemas };
    const actionClient = Object.freeze({
      id: action.id,
      semanticId: action.semanticId,
      authorityBoundary: action.authorityBoundary,
      doAuthority: action.doAuthority,
      possibleRefusals: Object.freeze([...(action.possibleRefusals || [])]),
      resource: action.resource,
      action: action.action,
      profile: Object.freeze({ ...action.profile }),
      invoke(input, callOptions) {
        return invokeWithReceipt(env, action, input, callOptions ?? {}, actionSchemas).then(
          ({ result }) => result,
        );
      },
      invokeWithReceipt(input, callOptions) {
        return invokeWithReceipt(env, action, input, callOptions ?? {}, actionSchemas);
      },
      inspect() {
        return inspectAction(action, contract, transports, prefer);
      },
    });

    actions[action.id] = actionClient;

    if (!Object.hasOwn(resources, action.resource)) resources[action.resource] = Object.create(null);
    resources[action.resource][action.action] = actionClient;
  }

  freezeRecordValues(actions);
  freezeRecordValues(resources);

  const events = Object.freeze({
    subscribe(subjectRef, callback) {
      if (!eventListeners.has(subjectRef)) eventListeners.set(subjectRef, new Set());
      eventListeners.get(subjectRef).add(callback);
      return () => {
        eventListeners.get(subjectRef)?.delete(callback);
      };
    },
    emit(eventData) {
      const parsed = eventProjectionSchema.parse(eventData);
      const listeners = eventListeners.get(parsed.subjectRef);
      if (listeners) {
        for (const cb of listeners) cb(parsed);
      }
    },
  });

  return Object.freeze({
    runtimeVersion: SURFACE_RUNTIME_VERSION,
    contract,
    actions,
    resources,
    events,
    reconcile(commandId, transportName = prefer) {
      return reconcileCommand(env, commandId, transportName);
    },
    /**
     * Explicit, never-automatic retry of an UNKNOWN_AFTER_DISPATCH outcome
     * under the admitted ash_surface.idempotency/1 protocol. See
     * docs/IDEMPOTENCY.md.
     */
    retryUnknown(receiptOrError, callOptions) {
      return retryUnknown(env, receiptOrError, callOptions ?? {});
    },
    get(id) {
      return Object.hasOwn(actions, id) ? actions[id] : null;
    },
    inspect(id) {
      const action = Object.hasOwn(actions, id) ? actions[id] : undefined;
      if (!action) throw new SurfaceRuntimeError("UNKNOWN_ACTION", `unknown action: ${id}`);
      return action.inspect();
    },
  });
}

async function reconcileCommand(env, commandId, transportName) {
  const { transports, emit } = env;
  const adapter = Object.hasOwn(transports, transportName) ? transports[transportName] : undefined;
  if (!adapter || typeof adapter.reconcile !== "function") {
    const unsupported = {
      commandId,
      status: "STILL_UNKNOWN",
      reason: "transport_reconciliation_unsupported",
    };
    emit("reconcile.result", {
      commandId,
      transport: transportName,
      status: unsupported.status,
      reason: unsupported.reason,
    });
    return unsupported;
  }
  const verdict = await adapter.reconcile(commandId);
  const parsed = reconcileResultSchema.safeParse(verdict);
  if (!parsed.success) {
    emit("reconcile.invalid_result", { commandId, transport: transportName });
    throw new SurfaceRuntimeError(
      "INVALID_RECONCILE_RESULT",
      `${transportName} reconcile reply for ${commandId} failed Zod validation`,
      { issues: parsed.error.issues },
    );
  }
  emit("reconcile.result", { commandId, transport: transportName, status: parsed.data.status });
  return verdict;
}

// Explicit retry of an UNKNOWN_AFTER_DISPATCH outcome. Order is law:
//   1. admit the receipt + action profile + input digest (all pre-dispatch);
//   2. reconcile on the transport that dispatched originally;
//   3. replay ONLY on NOT_OBSERVED (COMPLETED / STILL_UNKNOWN never replay),
//      pinned to the original transport unless the profile admits crossTransport.
async function retryUnknown(env, receiptOrError, options) {
  const { emit } = env;
  let commandId = null;
  let actionId = null;
  let plan;

  try {
    if (options.commandId !== undefined || options.idempotencyKey !== undefined) {
      throw new SurfaceRuntimeError(
        "INVALID_OPTIONS",
        "retryUnknown reuses the receipt's commandId and idempotency key; they cannot be overridden",
      );
    }
    if (!Object.hasOwn(options, "input")) {
      throw new SurfaceRuntimeError(
        "INVALID_OPTIONS",
        "retryUnknown requires options.input (receipts never carry input values)",
      );
    }

    const { action, retry } = admitRetryReceipt(env, receiptOrError);
    actionId = action.id;
    commandId = retry.commandId;
    emit("retry.requested", {
      actionId,
      commandId,
      transport: retry.transport,
      attempt: retry.attempt,
    });
    const binding = env.bindings[action.id];
    plan = prepareDispatch(env, binding.action, options.input, options, binding.actionSchemas, retry);

    const verdict = await reconcileCommand(env, commandId, retry.transport);

    if (verdict.status !== "NOT_OBSERVED") {
      emit("retry.skipped", { actionId, commandId, reason: verdict.status });
      return Object.freeze({ status: verdict.status, replayed: false, reconcile: verdict });
    }
  } catch (error) {
    emit("retry.refused", {
      actionId,
      commandId,
      code: errorCode(error),
    });
    throw error;
  }

  emit("retry.replaying", {
    actionId,
    commandId,
    transport: plan.decision.selected,
    attempt: plan.idempotency.attempt,
  });
  const { result, receipt } = await executeDispatch(env, plan);
  return Object.freeze({ status: "REPLAYED", replayed: true, reconcile: null, result, receipt });
}

function parseContract(contract) {
  const parsed = ashSurfaceContractSchema.safeParse(contract);

  if (!parsed.success) {
    throw new SurfaceRuntimeError("INVALID_SURFACE_CONTRACT", "AshSurface contract failed Zod validation", {
      issues: parsed.error.issues,
    });
  }

  const [major] = parsed.data.surfaceSchemaVersion.split(".").map(Number);
  if (!SUPPORTED_SURFACE_MAJORS.includes(major)) {
    throw new SurfaceRuntimeError(
      "UNSUPPORTED_SURFACE_VERSION",
      `AshSurface contract major ${parsed.data.surfaceSchemaVersion} is unsupported`,
    );
  }

  return parsed.data;
}

function inspectAction(action, contract, transports, prefer) {
  const declared = declaredTransports(action);
  const available = availableTransports(action, contract, transports, declared);
  const decision = selectTransport(
    action.id,
    declared,
    available,
    prefer,
    factsFromProfile(action),
  );

  return Object.freeze({
    id: action.id,
    semanticId: action.semanticId,
    authorityBoundary: action.authorityBoundary,
    doAuthority: action.doAuthority,
    declared: Object.freeze([...declared]),
    available: Object.freeze([...available]),
    decision: Object.freeze({ ...decision }),
  });
}

// Pre-dispatch admission plus the emitted refusal event. Every SurfaceRuntimeError
// thrown here happens BEFORE dispatch: nothing was sent, no receipt exists.
function prepareDispatch(env, action, input, options, actionSchemas, retry) {
  try {
    let admittedInput = input;

    if (actionSchemas?.input) {
      try {
        admittedInput = actionSchemas.input.parse(input);
      } catch (cause) {
        throw new SurfaceRuntimeError(
          "INPUT_VALIDATION_FAILED",
          `input failed Zod validation for ${action.id}`,
          { cause },
        );
      }
    }

    const { contract, transports, prefer } = env;
    const declared = declaredTransports(action);
    const available = availableTransports(action, contract, transports, declared);
    let decision = selectTransport(action.id, declared, available, prefer, factsFromProfile(action));

    // A replay is pinned to the transport that dispatched originally unless
    // the admitted protocol explicitly admits cross-transport replay.
    if (retry && !retry.crossTransport) {
      if (!available.includes(retry.transport)) {
        throw new SurfaceRuntimeError(
          "RETRY_TRANSPORT_UNAVAILABLE",
          `${retry.transport} dispatched ${action.id} originally and is not available; cross-transport replay is not admitted`,
        );
      }
      decision = {
        ...decision,
        selected: retry.transport,
        preferred: retry.transport,
        reason: "retry_pinned_transport",
      };
    }

    const adapter = Object.hasOwn(transports, decision.selected)
      ? transports[decision.selected]
      : undefined;
    const timeoutMs = admitTimeout(options.timeoutMs, action.id);
    const commandId = retry ? retry.commandId : admitCommandId(options.commandId, action.id);

    // Abort-before-dispatch is a typed PRE-dispatch refusal: nothing was sent,
    // so there is no unknown-after-dispatch receipt and no adapter call.
    if (options.signal && options.signal.aborted === true) {
      throw new SurfaceRuntimeError(
        "DISPATCH_ABORTED_PRE_DISPATCH",
        `signal was already aborted before dispatch for ${action.id}; nothing was dispatched (dispatchState not_dispatched)`,
        { cause: options.signal.reason },
      );
    }

    const idempotency = admitIdempotencyForCall(action, admittedInput, options, commandId, retry);

    return {
      action,
      admittedInput,
      decision,
      adapter,
      timeoutMs,
      commandId,
      signal: options.signal,
      idempotency,
      actionSchemas,
    };
  } catch (error) {
    if (!retry) {
      env.emit("dispatch.refused_pre_dispatch", {
        actionId: action.id,
        code: errorCode(error),
      });
    }
    throw error;
  }
}

async function invokeWithReceipt(env, action, input, options, actionSchemas) {
  return executeDispatch(env, prepareDispatch(env, action, input, options, actionSchemas, null));
}

async function executeDispatch(env, plan) {
  const { action, decision, commandId, idempotency, actionSchemas } = plan;
  const emit = env.emit;
  const started = monotonicNow();
  const duration = () => Math.max(0, Math.round(monotonicNow() - started));

  emit("transport.selected", {
    actionId: action.id,
    commandId,
    declared: [...decision.declared],
    available: [...decision.available],
    selected: decision.selected,
    preferred: decision.preferred,
    reason: decision.reason,
    dimensions: decision.dimensions,
  });
  emit("dispatch.started", {
    actionId: action.id,
    commandId,
    transport: decision.selected,
    ...(idempotency ? { attempt: idempotency.attempt } : {}),
  });

  try {
    // Dispatch happens here; from this line on every failure (including a
    // timeout or abort) is UNKNOWN_AFTER_DISPATCH, never a replay.
    const response = await raceDispatch(
      plan.adapter.invoke({
        action,
        input: plan.admittedInput,
        commandId,
        contract: env.contract,
        signal: plan.signal,
        ...(idempotency ? { idempotency: publicIdempotency(idempotency) } : {}),
      }),
      plan.timeoutMs,
      plan.signal,
      action.id,
    );

    let admittedOutput = response;
    if (actionSchemas?.output) {
      try {
        admittedOutput = actionSchemas.output.parse(response);
      } catch (cause) {
        emit("dispatch.completed", {
          actionId: action.id,
          commandId,
          transport: decision.selected,
          durationMs: duration(),
          outputValid: false,
        });
        throw new SurfaceRuntimeError(
          "OUTPUT_VALIDATION_FAILED",
          `output failed Zod validation for ${action.id}`,
          {
            cause,
            receipt: buildMXReceipt(decision, action, commandId, "completed", response, idempotency),
          },
        );
      }
    }

    const receipt = buildMXReceipt(decision, action, commandId, "completed", admittedOutput, idempotency);
    emit("dispatch.completed", {
      actionId: action.id,
      commandId,
      transport: decision.selected,
      durationMs: duration(),
      outputValid: true,
    });
    return { result: admittedOutput, receipt };
  } catch (cause) {
    if (cause instanceof SurfaceRuntimeError && cause.code === "OUTPUT_VALIDATION_FAILED") {
      throw cause;
    }

    emit("dispatch.unknown_after_dispatch", {
      actionId: action.id,
      commandId,
      transport: decision.selected,
      durationMs: duration(),
      cause: errorCode(cause),
    });
    throw new SurfaceRuntimeError(
      "TRANSPORT_OUTCOME_UNKNOWN",
      `${decision.selected} transport failed after dispatch for ${action.id}; no automatic cross-transport retry was attempted`,
      {
        cause,
        receipt: buildMXReceipt(decision, action, commandId, "unknown_after_dispatch", null, idempotency),
      },
    );
  }
}

// Event-safe failure classification: a code or class name only, never a
// message (messages can carry payload values).
function errorCode(error) {
  if (error instanceof SurfaceRuntimeError) return error.code;
  return "ADAPTER_ERROR";
}

function monotonicNow() {
  try {
    const perf = globalThis.performance;
    if (perf && typeof perf.now === "function") return perf.now();
  } catch {
    // fall through
  }
  return Date.now();
}

// Opt-in structured event hook. Called synchronously; a throwing (or
// rejecting) hook is swallowed and can never affect dispatch. Events carry
// ids, codes, transports and durations only -- never input or output values.
function makeEmitter(onEvent) {
  if (onEvent === undefined || onEvent === null) return () => {};
  if (typeof onEvent !== "function") {
    throw new SurfaceRuntimeError("INVALID_OPTIONS", "onEvent must be a function");
  }
  return (type, fields) => {
    try {
      const outcome = onEvent(Object.freeze({ type, ...fields }));
      if (outcome && typeof outcome.then === "function") outcome.then(undefined, () => {});
    } catch {
      // observability must never affect dispatch
    }
  };
}

// ---------------------------------------------------------------------------
// ash_surface.idempotency/1 -- the separately admitted protocol that alone
// permits a post-dispatch retry. Twin of lib/ash_surface/idempotency.ex; the
// key law and request digest are pinned by shared vectors in
// test/js/idempotency_parity.test.mjs and test/ash_surface/idempotency_test.exs.
// ---------------------------------------------------------------------------

/** Contract profile shape: `profile.idempotency`. Strict: unknown keys refuse. */
export const idempotencyProfileSchema = z
  .object({
    protocol: z.literal(IDEMPOTENCY_PROTOCOL),
    crossTransport: z.boolean().default(false),
    keyHeader: z.string().min(1).optional(),
  })
  .strict();

const IDEMPOTENCY_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_.:-]{7,127}$/;
const DIGEST_PATTERN = new RegExp(`^[0-9a-f]{${DIGEST_HEX_LENGTH}}$`);
const LONE_SURROGATE = /[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/;

/** @param {unknown} key @returns {boolean} 8..128 chars of [A-Za-z0-9_.:-], alphanumeric first. */
export function validateIdempotencyKey(key) {
  return typeof key === "string" && IDEMPOTENCY_KEY_PATTERN.test(key);
}

/**
 * Deterministic key: "ik_" + sha256 hex of the canonical {actionId, commandId}.
 * @param {string} actionId @param {string} commandId @returns {string}
 */
export function deriveIdempotencyKey(actionId, commandId) {
  return `ik_${sha256Hex(canonicalJson({ actionId, commandId }, []))}`;
}

/**
 * Canonical request digest binding the action identity to its admitted input:
 * sha256 hex of canonical {actionId, input}. `undefined` input digests as null.
 * Non-portable values (floats, unsafe integers, undefined members, lone
 * surrogates, non-plain objects) throw IDEMPOTENCY_INPUT_NOT_PORTABLE.
 * @param {string} actionId @param {unknown} input @returns {string}
 */
export function computeRequestDigest(actionId, input) {
  return sha256Hex(canonicalJson({ actionId, input: input === undefined ? null : input }, []));
}

function notPortable(path, why) {
  return new SurfaceRuntimeError(
    "IDEMPOTENCY_INPUT_NOT_PORTABLE",
    `input is not canonically digestible at ${path.length === 0 ? "<root>" : path.join(".")}: ${why}`,
  );
}

// Canonical JSON matching AshSurface.CanonicalJSON over the portable subset:
// key-sorted (code point == UTF-8 byte order), order-preserving lists, Jason's
// string escapes (uppercase \u00XX for control chars; "/" and DEL verbatim).
function canonicalJson(value, path) {
  if (value === null) return "null";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw notPortable(path, "only safe integers are portable");
    return Object.is(value, -0) ? "0" : String(value);
  }
  if (typeof value === "string") return canonicalString(value, path);
  if (Array.isArray(value)) {
    return `[${value.map((item, index) => canonicalJson(item, [...path, index])).join(",")}]`;
  }
  if (typeof value === "object") {
    const proto = Object.getPrototypeOf(value);
    if (proto !== Object.prototype && proto !== null) throw notPortable(path, "not a plain object");
    const keys = Object.keys(value).sort(compareCodePoints);
    return `{${keys
      .map((key) => `${canonicalString(key, path)}:${canonicalJson(value[key], [...path, key])}`)
      .join(",")}}`;
  }
  throw notPortable(path, `unsupported ${typeof value}`);
}

function compareCodePoints(a, b) {
  const ia = a[Symbol.iterator]();
  const ib = b[Symbol.iterator]();
  for (;;) {
    const x = ia.next();
    const y = ib.next();
    if (x.done || y.done) return x.done === y.done ? 0 : x.done ? -1 : 1;
    const d = x.value.codePointAt(0) - y.value.codePointAt(0);
    if (d !== 0) return d;
  }
}

const SHORT_ESCAPES = Object.freeze({ 8: "\\b", 9: "\\t", 10: "\\n", 12: "\\f", 13: "\\r" });

function canonicalString(str, path) {
  if (LONE_SURROGATE.test(str)) throw notPortable(path, "lone surrogate");
  let out = '"';
  for (let i = 0; i < str.length; i += 1) {
    const c = str.charCodeAt(i);
    if (c === 0x22) out += '\\"';
    else if (c === 0x5c) out += "\\\\";
    else if (c < 0x20) {
      out += SHORT_ESCAPES[c] ?? `\\u00${c.toString(16).toUpperCase().padStart(2, "0")}`;
    } else out += str[i];
  }
  return `${out}"`;
}

function utf8Bytes(str) {
  const out = [];
  for (const ch of str) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) out.push(cp);
    else if (cp < 0x800) out.push(0xc0 | (cp >> 6), 0x80 | (cp & 63));
    else if (cp < 0x10000) out.push(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    else {
      out.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    }
  }
  return out;
}

const SHA256_K = Object.freeze([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

// Synchronous, dependency-free SHA-256 (lowercase hex) so the runtime stays
// executable in Node, browsers and Hermes without node:crypto or async subtle.
function sha256Hex(str) {
  const bytes = utf8Bytes(str);
  const bitLength = bytes.length * 8;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) bytes.push(0);
  const hi = Math.floor(bitLength / 0x100000000);
  const lo = bitLength >>> 0;
  for (const word of [hi, lo]) bytes.push(word >>> 24, (word >>> 16) & 255, (word >>> 8) & 255, word & 255);

  const h = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  const w = new Array(64);
  const rotr = (x, n) => (x >>> n) | (x << (32 - n));

  for (let off = 0; off < bytes.length; off += 64) {
    for (let i = 0; i < 16; i += 1) {
      const j = off + i * 4;
      w[i] = ((bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]) | 0;
    }
    for (let i = 16; i < 64; i += 1) {
      const s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      const s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
    }
    let [a, b, c, d, e, f, g, hh] = h;
    for (let i = 0; i < 64; i += 1) {
      const t1 =
        (hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + SHA256_K[i] + w[i]) | 0;
      const t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) | 0;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) | 0;
    }
    h[0] = (h[0] + a) | 0;
    h[1] = (h[1] + b) | 0;
    h[2] = (h[2] + c) | 0;
    h[3] = (h[3] + d) | 0;
    h[4] = (h[4] + e) | 0;
    h[5] = (h[5] + f) | 0;
    h[6] = (h[6] + g) | 0;
    h[7] = (h[7] + hh) | 0;
  }

  return h.map((x) => (x >>> 0).toString(16).padStart(8, "0")).join("");
}

// The action's admitted protocol profile, or null when the action does not
// admit it. A present-but-invalid profile is a typed pre-dispatch refusal:
// silently ignoring it would let a caller believe a retry is safe.
function admitIdempotencyProfile(action) {
  const raw = action.profile?.idempotency;
  if (raw === undefined || raw === null) return null;
  const parsed = idempotencyProfileSchema.safeParse(raw);
  if (!parsed.success) {
    throw new SurfaceRuntimeError(
      "INVALID_IDEMPOTENCY_PROFILE",
      `profile.idempotency for ${action.id} does not admit ${IDEMPOTENCY_PROTOCOL}`,
      { issues: parsed.error.issues },
    );
  }
  return parsed.data;
}

// Per-call admission: absent profile -> null (and a supplied key refuses);
// admitted profile -> a validated/derived key bound to the request digest.
function admitIdempotencyForCall(action, admittedInput, options, commandId, retry) {
  const profile = admitIdempotencyProfile(action);
  const supplied = options.idempotencyKey;

  if (!profile) {
    if (supplied !== undefined && supplied !== null) {
      throw new SurfaceRuntimeError(
        "IDEMPOTENCY_NOT_ADMITTED",
        `${action.id} does not admit ${IDEMPOTENCY_PROTOCOL}; an idempotencyKey cannot be honored`,
      );
    }
    return null;
  }

  const key = retry
    ? retry.key
    : supplied === undefined || supplied === null
      ? deriveIdempotencyKey(action.id, commandId)
      : supplied;

  if (!validateIdempotencyKey(key)) {
    throw new SurfaceRuntimeError(
      "INVALID_IDEMPOTENCY_KEY",
      `idempotencyKey for ${action.id} must be 8..128 chars of [A-Za-z0-9_.:-] starting alphanumeric`,
    );
  }

  const requestDigest = computeRequestDigest(action.id, admittedInput);

  if (retry && requestDigest !== retry.requestDigest) {
    throw new SurfaceRuntimeError(
      "IDEMPOTENCY_DIGEST_MISMATCH",
      `retry input for ${action.id} does not match the request digest bound into the receipt`,
    );
  }

  return Object.freeze({
    protocol: IDEMPOTENCY_PROTOCOL,
    key,
    requestDigest,
    crossTransport: profile.crossTransport,
    keyHeader: profile.keyHeader ?? null,
    attempt: retry ? retry.attempt : 1,
  });
}

// What the adapter sees: enough to put the key on the wire; nothing else.
function publicIdempotency(idempotency) {
  return Object.freeze({
    protocol: idempotency.protocol,
    key: idempotency.key,
    keyHeader: idempotency.keyHeader,
    requestDigest: idempotency.requestDigest,
    attempt: idempotency.attempt,
  });
}

// Validates a caller-held receipt (untrusted) into the retry plan pieces.
function admitRetryReceipt(env, receiptOrError) {
  const receipt = receiptOrError instanceof SurfaceRuntimeError ? receiptOrError.receipt : receiptOrError;

  if (typeof receipt !== "object" || receipt === null) {
    throw new SurfaceRuntimeError(
      "RETRY_REQUIRES_RECEIPT",
      "retryUnknown requires the UNKNOWN_AFTER_DISPATCH receipt (or the TRANSPORT_OUTCOME_UNKNOWN error carrying it), not a bare id",
    );
  }
  if (receipt.dispatchState !== "unknown_after_dispatch" || receipt.outcome !== DISPATCH_OUTCOMES[1]) {
    throw new SurfaceRuntimeError(
      "RETRY_NOT_UNKNOWN",
      "only an UNKNOWN_AFTER_DISPATCH receipt can be retried; completed and not-dispatched outcomes never replay",
    );
  }

  const action = typeof receipt.actionId === "string" && Object.hasOwn(env.bindings, receipt.actionId)
    ? env.bindings[receipt.actionId].action
    : undefined;
  if (!action) {
    throw new SurfaceRuntimeError("UNKNOWN_ACTION", `unknown action: ${String(receipt.actionId)}`);
  }

  const profile = admitIdempotencyProfile(action);
  if (!profile) {
    throw new SurfaceRuntimeError(
      "IDEMPOTENCY_NOT_ADMITTED",
      `${action.id} does not admit ${IDEMPOTENCY_PROTOCOL}; a post-dispatch retry is refused`,
    );
  }

  const idem = receipt.idempotency;
  if (
    typeof idem !== "object" || idem === null ||
    idem.protocol !== IDEMPOTENCY_PROTOCOL ||
    !validateIdempotencyKey(idem.key) ||
    typeof idem.requestDigest !== "string" || !DIGEST_PATTERN.test(idem.requestDigest) ||
    !Number.isSafeInteger(idem.attempt) || idem.attempt < 1 ||
    typeof receipt.commandId !== "string" || receipt.commandId.length === 0 ||
    !KNOWN_TRANSPORTS.includes(receipt.selected)
  ) {
    throw new SurfaceRuntimeError(
      "RETRY_RECEIPT_INVALID",
      `receipt for ${action.id} does not carry a valid ${IDEMPOTENCY_PROTOCOL} binding (key, request digest, command, transport)`,
    );
  }

  return {
    action,
    retry: Object.freeze({
      commandId: receipt.commandId,
      key: idem.key,
      requestDigest: idem.requestDigest,
      attempt: idem.attempt + 1,
      transport: receipt.selected,
      crossTransport: profile.crossTransport,
    }),
  };
}

// Pre-dispatch admission of a caller-supplied commandId: absent (undefined/null)
// means "generate one"; anything else must be a non-empty string.
function admitCommandId(commandId, actionId) {
  if (commandId === undefined || commandId === null) return generateCommandId();
  if (typeof commandId !== "string" || commandId.length === 0) {
    throw new SurfaceRuntimeError(
      "INVALID_OPTIONS",
      `commandId must be a non-empty string for ${actionId}`,
    );
  }
  return commandId;
}

// Default command identity. Never throws: prefers crypto.randomUUID, else a
// v4 UUID from crypto.getRandomValues (Node 18 without the global, non-secure
// browser contexts), else a Math.random/time-based id (Hermes / React Native
// without a crypto polyfill).
function generateCommandId() {
  let c;
  try {
    c = globalThis.crypto;
  } catch {
    c = undefined;
  }
  try {
    if (c && typeof c.randomUUID === "function") return `cmd_${c.randomUUID()}`;
    if (c && typeof c.getRandomValues === "function") {
      const b = c.getRandomValues(new Uint8Array(16));
      b[6] = (b[6] & 0x0f) | 0x40;
      b[8] = (b[8] & 0x3f) | 0x80;
      const h = Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
      return `cmd_${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
    }
  } catch {
    // fall through to the non-crypto id
  }
  fallbackCounter = (fallbackCounter + 1) >>> 0;
  const rand = () => Math.floor(Math.random() * 0x100000000).toString(16).padStart(8, "0");
  return `cmd_${Date.now().toString(16)}-${fallbackCounter.toString(16)}-${rand()}${rand()}`;
}

let fallbackCounter = 0;

// Pre-dispatch admission of the opt-in dispatch deadline.
function admitTimeout(timeoutMs, actionId) {
  if (timeoutMs === undefined || timeoutMs === null) return null;
  if (typeof timeoutMs !== "number" || !Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new SurfaceRuntimeError(
      "INVALID_OPTIONS",
      `timeoutMs must be a positive finite number for ${actionId}`,
    );
  }
  return timeoutMs;
}

// Races an already-dispatched adapter promise against the optional deadline
// and abort signal. Settles exactly once; the timer and abort listener are
// always released on settlement so no handle outlives the call.
function raceDispatch(dispatched, timeoutMs, signal, actionId) {
  const abortable = signal && typeof signal.addEventListener === "function";
  if (timeoutMs === null && !abortable) return dispatched;

  return new Promise((resolve, reject) => {
    let timer = null;
    let settled = false;

    const settle = (fn, value) => {
      if (settled) return;
      settled = true;
      if (timer !== null) clearTimeout(timer);
      if (abortable) signal.removeEventListener("abort", onAbort);
      fn(value);
    };

    function onAbort() {
      settle(
        reject,
        new SurfaceRuntimeError("DISPATCH_ABORTED", `dispatch aborted for ${actionId}`, {
          cause: signal.reason,
        }),
      );
    }

    Promise.resolve(dispatched).then(
      (value) => settle(resolve, value),
      (error) => settle(reject, error),
    );

    if (abortable) {
      if (signal.aborted) {
        onAbort();
        return;
      }
      signal.addEventListener("abort", onAbort, { once: true });
    }

    if (timeoutMs !== null) {
      timer = setTimeout(() => {
        settle(
          reject,
          new SurfaceRuntimeError(
            "DISPATCH_TIMEOUT",
            `dispatch exceeded ${timeoutMs}ms for ${actionId}`,
          ),
        );
      }, timeoutMs);
    }
  });
}

function buildMXReceipt(decision, action, commandId, dispatchState, result, idempotency = null) {
  const domainReceiptRef = result?.receiptRef || result?.receipt?.hash || result?.data?.id || null;
  const outcome = dispatchState === "completed" ? DISPATCH_OUTCOMES[0] : DISPATCH_OUTCOMES[1];

  const transportReceipt = Object.freeze({
    actionId: decision.actionId,
    selected: decision.selected,
    preferred: decision.preferred,
    reason: decision.reason,
    fallback: decision.fallback,
    dispatchState,
    declared: [...decision.declared],
    available: [...decision.available],
    dimensions: decision.dimensions,
    frontier: [...(decision.frontier || [])],
  });

  return Object.freeze({
    ...decision,
    commandId,
    semanticId: action.semanticId,
    authorityBoundary: action.authorityBoundary,
    doAuthority: action.doAuthority,
    dispatchState,
    outcome,
    domainReceiptRef,
    transportReceipt,
    ...(idempotency
      ? {
          idempotency: Object.freeze({
            protocol: idempotency.protocol,
            key: idempotency.key,
            requestDigest: idempotency.requestDigest,
            crossTransport: idempotency.crossTransport,
            dispatchedTransport: decision.selected,
            attempt: idempotency.attempt,
          }),
        }
      : {}),
    consequenceReceipt: result?.consequenceReceipt || (result?.data ? { id: result.data.id, data: result.data } : null),
    timestamp: new Date().toISOString(),
  });
}

function declaredTransports(action) {
  const requested = action.profile?.transport ?? "auto";

  if (requested === "auto") return [...KNOWN_TRANSPORTS];
  if (KNOWN_TRANSPORTS.includes(requested)) return [requested];

  throw new SurfaceRuntimeError(
    "UNKNOWN_TRANSPORT",
    `unknown transport projection ${String(requested)} for ${action.id}`,
  );
}

function availableTransports(action, contract, transports, declared) {
  return declared.filter((name) => {
    const adapter = Object.hasOwn(transports, name) ? transports[name] : undefined;
    if (!adapter || typeof adapter.invoke !== "function") return false;

    if (typeof adapter.available === "function") {
      return adapter.available(action, contract) === true;
    }

    return adapter.available !== false;
  });
}

/**
 * Reads the delegated transport dimension facts out of an action's profile
 * (the contract's `surface.actions[].profile` shape). An absent or null
 * "transportFacts" key normalizes to an empty facts map — not delegated,
 * never defaulted. Unknown transports, dimensions, or classes are typed
 * pre-dispatch refusals, never silent drops.
 */
function factsFromProfile(action) {
  const raw = action.profile?.transportFacts;

  if (raw === undefined || raw === null) return {};
  assertPlainObject(raw, "transportFacts");

  const facts = {};

  for (const [transport, dimensions] of Object.entries(raw)) {
    if (!KNOWN_TRANSPORTS.includes(transport)) {
      throw new SurfaceRuntimeError(
        "UNKNOWN_TRANSPORT",
        `unknown transport fact key: ${transport}`,
      );
    }

    assertPlainObject(dimensions, `transportFacts.${transport}`);

    const admitted = {};

    for (const [dimension, value] of Object.entries(dimensions)) {
      if (value === undefined || value === null) continue; // nil = not delegated
      if (!KNOWN_DIMENSIONS.includes(dimension)) {
        throw new SurfaceRuntimeError(
          "UNKNOWN_DIMENSION",
          `unknown dimension fact ${dimension} for ${transport}`,
        );
      }
      if (!KNOWN_DIMENSION_CLASSES.includes(value)) {
        throw new SurfaceRuntimeError(
          "UNKNOWN_DIMENSION_CLASS",
          `unknown ${dimension} class ${String(value)} for ${transport}`,
        );
      }
      admitted[dimension] = value;
    }

    facts[transport] = admitted;
  }

  return facts;
}

function assertPlainObject(value, label) {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new SurfaceRuntimeError(
      "TRANSPORT_FACTS_MUST_BE_A_MAP",
      `${label} must be a plain object`,
    );
  }
}

function dimensionFact(facts, transport, dimension) {
  return facts[transport]?.[dimension] ?? null;
}

// Lower is better for cost and latency; higher is better for privacy.
const DIMENSION_RANK = Object.freeze({ low: 0, medium: 1, high: 2 });

function dimensionBetter(dimension, a, b) {
  return dimension === "privacy"
    ? DIMENSION_RANK[a] > DIMENSION_RANK[b]
    : DIMENSION_RANK[a] < DIMENSION_RANK[b];
}

// :better | :worse | :equal | :incomparable — an axis is comparable only
// where both transports declare a class.
function compareDimension(dimension, a, b, facts) {
  const classA = dimensionFact(facts, a, dimension);
  const classB = dimensionFact(facts, b, dimension);

  if (classA === null || classB === null) return "incomparable";
  if (classA === classB) return "equal";
  return dimensionBetter(dimension, classA, classB) ? "better" : "worse";
}

// a dominates b iff a is at least as good on every comparable axis and
// strictly better on at least one.
function dominates(a, b, facts) {
  let better = false;

  for (const dimension of DIMENSION_PRIORITY) {
    const verdict = compareDimension(dimension, a, b, facts);
    if (verdict === "worse") return false;
    if (verdict === "better") better = true;
  }

  return better;
}

// The admitted-alternatives frontier: every available transport (in declared
// order) that no other available transport dominates.
function transportFrontier(declared, available, facts) {
  const ordered = declared.filter((transport) => available.includes(transport));

  return ordered.filter(
    (transport) =>
      !ordered.some((other) => other !== transport && dominates(other, transport, facts)),
  );
}

// Deterministic frontier winner: compared pairwise in declared order, the
// first comparable axis with differing classes decides; a full tie falls to
// declared order.
function frontierBest(frontier, declared, facts) {
  return frontier.reduce((champion, candidate) => {
    for (const dimension of DIMENSION_PRIORITY) {
      const verdict = compareDimension(dimension, candidate, champion, facts);
      if (verdict === "better") return candidate;
      if (verdict === "worse") return champion;
    }

    return declared.indexOf(candidate) <= declared.indexOf(champion) ? candidate : champion;
  });
}

function selectTransport(actionId, declared, available, preferred, facts = {}) {
  const declaredDimensions = Object.values(facts).some(
    (dimensions) => Object.keys(dimensions).length > 0,
  );
  const dimensions = declaredDimensions ? "declared" : "undelegated";

  if (available.length === 0) {
    throw new SurfaceRuntimeError(
      "UNSUPPORTED_TRANSPORT",
      `no admitted transport implementation is available for ${actionId}`,
      {
        receipt: {
          actionId,
          declared: [...declared],
          available: [...available],
          preferred,
          selected: null,
          reason: "no_available_transport",
          fallback: "pre_dispatch_only",
          dispatchState: "not_dispatched",
          dimensions,
          frontier: [],
        },
      },
    );
  }

  const frontier = transportFrontier(declared, available, facts);
  const decision = (selected, reason) => ({
    actionId,
    declared: [...declared],
    available: [...available],
    selected,
    preferred,
    reason,
    fallback: "pre_dispatch_only",
    dispatchState: "not_dispatched",
    dimensions,
    frontier: [...frontier],
  });

  if (declaredDimensions) {
    if (available.includes(preferred) && frontier.includes(preferred)) {
      return decision(preferred, "preferred_available");
    }

    return decision(frontierBest(frontier, declared, facts), "dimension_weighed");
  }

  const selected = available.includes(preferred)
    ? preferred
    : declared.find((candidate) => available.includes(candidate));

  return decision(
    selected,
    selected === preferred ? "preferred_available" : "preferred_unavailable",
  );
}

function assertPreferred(prefer) {
  if (!KNOWN_TRANSPORTS.includes(prefer)) {
    throw new SurfaceRuntimeError("UNKNOWN_TRANSPORT", `unknown preferred transport: ${prefer}`);
  }
}

function assertTransportAdapters(transports) {
  if (!transports || typeof transports !== "object") {
    throw new SurfaceRuntimeError("INVALID_TRANSPORTS", "transports must be an object");
  }

  const unknown = Object.getOwnPropertyNames(transports).filter((name) => !KNOWN_TRANSPORTS.includes(name));
  if (unknown.length > 0) {
    throw new SurfaceRuntimeError("UNKNOWN_TRANSPORT", `unknown transport adapter(s): ${unknown.join(", ")}`);
  }
}

function freezeRecordValues(record) {
  for (const value of Object.values(record)) Object.freeze(value);
}
