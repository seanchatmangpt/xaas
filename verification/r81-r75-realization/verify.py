#!/usr/bin/env python3
import copy, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
HEX40 = re.compile(r"^[0-9a-f]{40}$")
EXPECTED_BASE = "9a7dda3044311e2fbdec5a8d8171e31642dfe2d7"
EXPECTED_PRODUCER = "c54e25f884e6b56ae8bf62f058cf7d6851b8d7c3"


def refuse(reason):
    return f"REFUSED[{reason}]"


def validate(subject, plan):
    if subject.get("consumer_repo") != "seanchatmangpt/xaas": return refuse("FOREIGN_CONSUMER")
    if subject.get("producer_repo") != "seanchatmangpt/ggen-marketplace": return refuse("FOREIGN_PRODUCER")
    if subject.get("consumer_base") != EXPECTED_BASE or not HEX40.fullmatch(subject.get("consumer_base", "")): return refuse("CONSUMER_BASE")
    if subject.get("producer_head") != EXPECTED_PRODUCER or not HEX40.fullmatch(subject.get("producer_head", "")): return refuse("PRODUCER_HEAD")
    if subject.get("consumer_factory") != "forced-top25-standard-consumer-factory-pack": return refuse("CONSUMER_FACTORY")
    if subject.get("realization_factory") != "epistemic-sensor-factory-pack:r75": return refuse("REALIZATION_FACTORY")
    if subject.get("composition_pack") != "forced-top25-r75-realization-composition-pack": return refuse("COMPOSITION_PACK")
    if subject.get("consequential_do") is not False or "DO" in subject.get("authority", "").split("|"): return refuse("AUTHORITY_FENCE")
    if plan.get("repo") != "xaas": return refuse("PLAN_REPO")
    if plan.get("exact_head") != EXPECTED_BASE: return refuse("PLAN_EXACT_HEAD")
    if plan.get("upstream_consumer_factory") != subject.get("consumer_factory"): return refuse("PLAN_CONSUMER_FACTORY")
    if plan.get("upstream_realization_factory") != subject.get("realization_factory"): return refuse("PLAN_REALIZATION_FACTORY")
    if plan.get("authority") != "CONSTRUCT" or plan.get("consequential_do") is not False: return refuse("PLAN_AUTHORITY")
    if plan.get("standing") != "PLANNED": return refuse("PLAN_STANDING")
    ggen = (ROOT / subject["local_ggen_config"]).read_text()
    if "[project]" not in ggen or "[ontology]" not in ggen or 'source = "ontology.ttl"' not in ggen: return refuse("LOCAL_GGEN_CONFIG")
    if "ggen-marketplace/packs/xaas-ash-core-pack/ontology.ttl" not in ggen: return refuse("MARKETPLACE_LINEAGE")
    owners = {}
    for migration in sorted((ROOT / "priv/repo/migrations").glob("*.exs")):
        text = migration.read_text()
        for table in re.findall(r"\bcreate\s+table\(:(\w+)", text):
            owners.setdefault(table, []).append(migration.name)
    duplicates = {table: paths for table, paths in owners.items() if len(paths) > 1}
    if duplicates: return refuse("DUPLICATE_MIGRATION_TABLE_OWNER")
    return "ALIVE"


def apply_case(subject, plan, case):
    subject = copy.deepcopy(subject)
    plan = copy.deepcopy(plan)
    target = subject if case["target"] == "subject" else plan
    target[case["field"]] = case.get("value")
    return validate(subject, plan)


def main():
    subject = json.loads((HERE / "subject.json").read_text())
    plan = json.loads((HERE / "ggen-realization-plan.json").read_text())
    standing = validate(subject, plan)
    if standing != "ALIVE":
        print("R81_R75_XAAS=" + standing)
        return 1
    cases = sorted((HERE / "cases").glob("*.json"))
    if not cases:
        print("R81_R75_XAAS=REFUSED[NO_FALSIFIERS]")
        return 1
    for path in cases:
        case = json.loads(path.read_text())
        observed = apply_case(subject, plan, case)
        if observed != case["expected"]:
            print(f"R81_R75_XAAS=REFUSED[CASE_MISMATCH] case={path.name} expected={case['expected']} observed={observed}")
            return 1
    print(f"R81_R75_XAAS=ALIVE cases={len(cases)} authority=VERIFY consequential_do=false")
    return 0


if __name__ == "__main__":
    sys.exit(main())
