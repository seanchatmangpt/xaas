# Deterministic Autonomic Work Selection

The STOGAF WD work graph now has an executable selector.

Given only the declared dependency graph and admitted work standings, it selects the lowest-numbered eligible non-ALIVE work order.

```
standings + dependencies
→ deterministic selector
→ next sJira work
```

Properties:

- no LLM call;
- no human interpretation of the graph;
- no authority grant;
- blocked dependencies fail closed;
- file presence does not create ALIVE standing.

The initial architecture state deliberately leaves SJ-011 through SJ-020 UNKNOWN, therefore the selector chooses SJ-011.

This demonstrates the **selection mechanism** required for ST-6. It does not by itself promote the whole episode to ST-6; downstream construction/manufacture/verification must still close.
