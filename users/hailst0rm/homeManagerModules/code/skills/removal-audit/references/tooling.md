# Audit tooling matrix

Adapt to the repo's real stack. Detect the package manager from the lockfile
(`pnpm-lock.yaml`/`yarn.lock`/`bun.lockb`/`package-lock.json`;
`uv.lock`/`poetry.lock`/`requirements*.txt`) and the test runner from scripts /
`pyproject.toml`. **No single tool is authoritative** — Knip, ts-prune, depcheck,
madge, and a plain `rg` sweep each miss different things; cross-check them. If a
tool isn't installed, run it via the package runner (`npx`/`uvx`/`pipx`) only when
safe, or record it as unavailable rather than skipping silently.

## Universal

```bash
rg -n "<target terms>"      # targeted mode: every spelling/casing
rg --files                  # general mode: inventory the tree
rg --files | rg -i "<name>" # files/dirs named after the target
```

## JS / TS

```bash
npx knip                                              # files + exports + deps in one pass
npx knip --production                                 # production-only reachability
npx knip --include files,exports,dependencies,devDependencies,unlisted
npx ts-prune                                          # unused exports (cross-check Knip)
npx depcheck                                          # unused / missing deps
npx madge src --extensions ts,tsx --orphans          # orphaned modules
npx madge src --extensions ts,tsx --circular         # cycles
npx dependency-cruiser src                            # rule-based graph evidence
npx tsc --noEmit ; npm run lint ; npm test ; npm run build
```

Knip respects entry points and is generally the best single starting tool for JS/TS;
still confirm its findings against framework conventions before calling anything dead.

## Python

```bash
ruff check .                                          # lint, unused imports/vars
vulture src tests --min-confidence 80                 # dead code (tune confidence)
python -m compileall .
pytest
mypy . ; pyright                                      # if used
```

Vulture is heuristic — dynamic dispatch, fixtures, and framework hooks produce false
positives. Treat its output as candidates, not verdicts.

## Routes / API / GraphQL / specs

```bash
rg -n "router\.(get|post|put|patch|delete)\(|app\.(get|post|put|patch|delete)\("
rg -n "@(Get|Post|Put|Patch|Delete)\(|export async function (GET|POST|PUT|PATCH|DELETE)"
rg -n "@app\.route|@router\.(get|post|put|patch|delete)"
rg -n "type .*|extend type|Query|Mutation|resolver|\.graphql"
rg -n "openapi|swagger|paths:"
```

These are framework-dynamic entrypoints — absence of a local import does **not** mean dead.

## Structural patterns (Semgrep / ast-grep)

Use when a term sweep is too noisy or misses structural usage:
removed imports, route decorators, feature-flag calls, analytics events, config
lookups, permission constants, public-API entries. Encode as a rule for repeatable
re-checks.

## Build / generated artefacts

```bash
rg -n "<target terms>" dist build .next out coverage
```

Generated files (OpenAPI/GraphQL/protobuf/prisma clients) are `generated-do-not-edit`:
fix the source or regenerate; never hand-delete.

## Dependency tree (confirm orphan before recommending removal)

```bash
pnpm why <package> | npm ls <package> | yarn why <package>
uv pip tree | pipdeptree | poetry show --tree
```

## Cross-repo / high-risk

- GitHub code search (`gh search code`), Sourcegraph, CodeQL where available.
- A public package's consumers live in *other* repos — local "unused" is not "dead".
- Document any external reference you could not verify as a caveat.
