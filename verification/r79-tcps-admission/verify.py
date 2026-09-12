#!/usr/bin/env python3
import json, pathlib, re, sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=pathlib.Path(__file__).resolve().parent
S=json.loads((HERE/'subject.json').read_text())
HEX40=re.compile(r'^[0-9a-f]{40}$')

def refuse(reason):
    print('R79_XAAS='+reason); return 1

def main():
    if S.get('consumer_repo')!='seanchatmangpt/xaas': return refuse('REFUSED[FOREIGN_CONSUMER]')
    if S.get('producer_repo')!='seanchatmangpt/ggen-marketplace': return refuse('REFUSED[FOREIGN_PRODUCER]')
    if S.get('producer_pack')!='portfolio-epistemic-observability-pack': return refuse('REFUSED[FOREIGN_PACK]')
    if S.get('producer_capability')!='R78_TCPS_READY_SET_CAPITAL': return refuse('REFUSED[FOREIGN_CAPABILITY]')
    if not HEX40.fullmatch(S.get('consumer_base','')) or not HEX40.fullmatch(S.get('producer_head','')): return refuse('REFUSED[MALFORMED_SUBJECT]')
    if S.get('compatibility_state')!='COMPATIBLE_OBSERVED': return refuse('REFUSED[COMPATIBILITY_NOT_OBSERVED]')
    if S.get('consequential_do') is not False or 'DO' in S.get('authority','').split('|'): return refuse('REFUSED[AUTHORITY_FENCE]')
    ggen=(ROOT/S['local_ggen_config']).read_text()
    if '[project]' not in ggen or '[ontology]' not in ggen or 'source = "ontology.ttl"' not in ggen: return refuse('REFUSED[GGEN_CONFIG]')
    if 'ggen-marketplace/packs/xaas-ash-core-pack/ontology.ttl' not in ggen: return refuse('REFUSED[MARKETPLACE_LINEAGE_MISSING]')
    print('R79_XAAS=ADMISSIBLE')
    return 0

if __name__=='__main__': sys.exit(main())
