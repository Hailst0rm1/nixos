{
  writeShellApplication,
  shadcn,
  jq,
  curl,
}:
# shadcn deliberately has no global search — `search` demands a namespace. This
# wraps `shadcn search` with a curated trust-list of high-craft registries so an
# agent can keyword-search across all of them at once, and `--all` widens to
# every public registry in the directory. Output is the shortlist an agent picks
# from (then reads with `shadcn view @ns/item` before writing). `registry:example`
# demos are dropped by default — they drown real components on common nouns.
writeShellApplication {
  name = "shadcn-index";
  runtimeInputs = [shadcn jq curl];
  text = ''
    trust=(@shadcn @magicui @aceternity @cult-ui @react-bits @kokonutui @animate-ui @motion-primitives @shadcnblocks)

    json=false
    all=false
    examples=false
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --json) json=true ;;
        --all) all=true ;;
        --examples) examples=true ;;
        -h | --help)
          echo "usage: shadcn-index [--all] [--json] [--examples] <query>"
          echo "  search a trust-list of high-craft shadcn registries by keyword"
          echo "  --all       widen to every public registry in the directory"
          echo "  --json      raw shadcn JSON (for agents) instead of plain lines"
          echo "  --examples  include registry:example demos (hidden by default)"
          exit 0
          ;;
        --) shift; args+=("$@"); break ;;
        -*) echo "shadcn-index: unknown flag: $1" >&2; exit 2 ;;
        *) args+=("$1") ;;
      esac
      shift
    done

    query="''${args[*]}"
    if [ -z "$query" ]; then
      echo "usage: shadcn-index [--all] [--json] [--examples] <query>" >&2
      exit 2
    fi

    if $all; then
      mapfile -t namespaces < <(curl -fsSL https://ui.shadcn.com/r/registries.json | jq -r '.[].name')
    else
      namespaces=("''${trust[@]}")
    fi

    if [ ''${#namespaces[@]} -eq 0 ]; then
      echo "shadcn-index: no registries to search (registries.json fetch failed?)" >&2
      exit 1
    fi

    # One namespace per call, not all at once: shadcn 3.7.0 aborts the WHOLE search
    # if any single registry errors (429/401/DNS-dead), so a batched call is only as
    # reliable as its flakiest registry. Loop and skip failures instead.
    # 3.7.0 also emits JSON from `search` by default (no `--json` flag); if the pin
    # ever moves to 4.x, human becomes default there and `--json` must be added back.
    raw='{"items":[]}'
    failed=()
    for ns in "''${namespaces[@]}"; do
      out=$(shadcn search "$ns" -q "$query" 2>/dev/null) || { failed+=("$ns"); continue; }
      if printf '%s' "$out" | jq -e '.items' >/dev/null 2>&1; then
        raw=$(jq -n --argjson a "$raw" --argjson b "$out" '{items: ($a.items + $b.items)}')
      else
        failed+=("$ns")
      fi
    done
    if [ ''${#failed[@]} -gt 0 ]; then
      echo "shadcn-index: skipped (unreachable/errored): ''${failed[*]}" >&2
    fi

    if ! $examples; then
      raw=$(printf '%s' "$raw" | jq '.items |= map(select(.type != "registry:example"))')
    fi

    if $json; then
      printf '%s\n' "$raw"
    else
      printf '%s' "$raw" \
        | jq -r '.items[] | "\(.addCommandArgument) (\(.type | sub("registry:"; "")))\(if .description then " — \(.description)" else "" end)"'
    fi
  '';
}
