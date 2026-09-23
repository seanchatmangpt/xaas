#!/bin/sh
# GC23-8 court: Closed Frontier (PRD section 12; goal.ttl v23:GC23-8).
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# stop court's machinery-absent code (standing UNKNOWN); any other exit =
# the court ran and witnessed nothing (standing UNKNOWN).
# Initial body (lane V23-P): the gate's machinery lands in lane V23-D, which
# replaces this body with the real court.
echo "UNKNOWN: GC23-8 machinery lands in lane V23-D"
exit 75
