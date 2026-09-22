# Semantic Context Envelope

Every demo case now has a stable deep-link JSON context surface:

```
/case-studies/wd-fa/context/:case_id.json?viewpoint=fa-engineer
```

The envelope carries:

- canonical subject identity;
- case identity;
- viewpoint;
- classification and standing;
- admitted mode;
- evidence identities;
- prior cases;
- semantic work identity/standing;
- authority ceiling;
- human gate;
- evidence ceiling;
- replay identity when applicable.

This implements the STOGAF deep-link rule: a human or generated view can return to the exact semantic subject without reconstructing context from the presentation.
