# STOGAF Demo JSON Surface

`GET /case-studies/wd-fa/stogaf.json` exposes the repository-local architecture projection used by the Friday demo.

It returns:

- architecture standing and ADM transition;
- cumulative conformance;
- requirement registry;
- viewpoint registry;
- ST-6 sJira work graph;
- Friday SA2A capability set;
- explicitly excluded production DO capability;
- DfCM coverage metrics.

The route is read-only. It grants no authority and is not a production WD API.

The endpoint exists so the browser, tests, presentation tooling and future generated runtime can consume the same explicit architecture projection instead of scraping prose.
