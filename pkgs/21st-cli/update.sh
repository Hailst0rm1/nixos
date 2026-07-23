#!/usr/bin/env bash
# Re-pin pkgs/21st-cli/package.nix against upstream.
#
# Neither source is on GitHub, so scripts/nix-github-update-report.py cannot
# see them:
#   - the CLI ships only as an npm tarball (package.json has repository: null)
#   - the three skills are plain markdown served from unversioned 21st.dev URLs
#     (see `21st install-skill`), so upstream edits them in place
#
# Both are therefore frozen by their FOD hash until this script refreshes it.
set -euo pipefail

pkg="$(dirname "$(readlink -f "$0")")/package.nix"

prefetch() { nix store prefetch-file --json --hash-type sha256 "$1" | jq -r .hash; }
repin() { # repin <anchor-url-fragment> <new-hash>
	local url_frag=$1 hash=$2
	# Replace the `hash = "...";` on the first line following the anchor URL.
	sed -i "\|$url_frag|,/hash = / s|hash = \"[^\"]*\"|hash = \"$hash\"|" "$pkg"
}

old_version=$(sed -nE 's/^  version = "(.*)";/\1/p' "$pkg")
new_version=$(curl -sf https://registry.npmjs.org/@21st-dev/cli | jq -r '."dist-tags".latest')

if [[ $old_version != "$new_version" ]]; then
	echo "cli: $old_version -> $new_version"
	sed -i -E "s/^  version = \".*\";/  version = \"$new_version\";/" "$pkg"
	repin "cli-\${finalAttrs.version}.tgz" \
		"$(prefetch "https://registry.npmjs.org/@21st-dev/cli/-/cli-$new_version.tgz")"
else
	echo "cli: $old_version (current)"
fi

for skill in 21st-cli-use 21st-registry 21st-design-sync 21st-ai; do
	url="https://21st.dev/skills/$skill.md"
	new_hash=$(prefetch "$url")
	if grep -qF "$new_hash" "$pkg"; then
		echo "skill $skill: unchanged"
	else
		echo "skill $skill: re-pinned"
		repin "skills/$skill.md" "$new_hash"
	fi
done
