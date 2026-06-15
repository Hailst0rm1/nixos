# Removal tooling matrix

Adapt every command to the repo's real stack. Detect the package manager from the
lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun,
`package-lock.json` → npm; `uv.lock` → uv, `poetry.lock` → poetry,
`requirements*.txt` → pip). Detect the test runner from package scripts /
`pyproject.toml`. **Don't add a tool the repo doesn't use** just to run a check —
if a tool is absent, run it via the package runner (`npx`/`pipx`/`uvx`) only when
safe, or note it as unavailable. No single tool is sufficient; combine static
search, dead-code analysis, and runtime checks.

## Universal — term sweep

Run with every spelling and casing from the manifest `terms`.

```bash
rg -n "oldFeature|OldFeature|old-feature|OLD_FEATURE"
rg -n "/old-feature|/api/old-feature"
rg -n "OLD_FEATURE_|old_feature"
rg --files | rg -i "old.?feature"        # files/dirs named after the feature
```

## JS / TS

```bash
npx knip                                              # unused files/exports/deps
npx knip --include files,exports,dependencies,devDependencies,unlisted
npx knip --production                                 # production-only graph
npx ts-prune                                          # unused exports
npx depcheck                                          # unused/ missing deps
npx madge src --extensions ts,tsx --orphans          # orphaned modules
npx madge src --extensions ts,tsx --circular         # cycles created by removal
npx dependency-cruiser src                            # rule-based graph evidence
npx tsc --noEmit                                      # type integrity
npm run lint
npm test
npm run build
```

## Python

```bash
ruff check .                                          # lint, unused imports
vulture src tests --min-confidence 80                 # dead code
python -m compileall .                                # everything still compiles
pytest
mypy . ; pyright                                      # if the repo uses them
```

## Route / API scans

```bash
# Express / Koa / generic
rg -n "router\.(get|post|put|patch|delete)\("
rg -n "app\.(get|post|put|patch|delete)\("
# NestJS / decorator style
rg -n "@(Get|Post|Put|Patch|Delete)\("
# Next.js route handlers
rg -n "export async function (GET|POST|PUT|PATCH|DELETE)"
# Flask / FastAPI
rg -n "@app\.route|@router\.(get|post|put|patch|delete)"
# GraphQL
rg -n "type .*Feature|extend type|Query|Mutation|resolver|\.graphql"
# OpenAPI / Swagger specs
rg -n "openapi|swagger|paths:"
```

## Frontend route / link scans

```bash
rg -n "createBrowserRouter|Routes|Route path="
rg -n "href=.*feature|to=.*feature|next/link"
```

## Dependency tree (confirm a dep is truly orphaned before removing)

```bash
pnpm why <package>      # or
npm ls <package>        # or
yarn why <package>
uv pip tree             # or
pipdeptree              # or
poetry show --tree
```

## Generated / committed build artefacts

```bash
rg -n "oldFeature|OldFeature|old-feature|OLD_FEATURE" dist build .next out coverage
# regenerate rather than hand-edit:
#   OpenAPI clients, GraphQL codegen, protobuf, prisma generate, etc.
```

## Structural bans (Semgrep / ast-grep)

Use when a plain `rg` term sweep is too noisy or misses structural usage — e.g.
"no import of the removed module", "no call to the removed flag helper", "no
decorator registering the removed route". Encode the banned pattern as a rule so
the gate is repeatable.

## Cross-repo / high-risk

- GitHub code search (`gh search code`), Sourcegraph, or CodeQL where available.
- Document any external reference (other service, SDK consumer) you could not
  verify — an unverified external caller is a risk to call out, not to assume away.
