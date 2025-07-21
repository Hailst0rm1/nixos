source "$stdenv"/setup

export HOME=$(mktemp -d)
npm install --loglevel=info --logs-max=0 "ghost-cli@$ghostCliVersion"

mkdir --parents "$out"/
node_modules/ghost-cli/bin/ghost install "$version" --db=sqlite3 \
  --no-enable --no-prompt --no-stack --no-setup --no-start --dir "$out"
