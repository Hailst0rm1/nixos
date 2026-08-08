{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.45.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${version}";
    hash = "sha256-weAyHM0nWLrM8JRbbXIfjUsHtAep3DOFyTO+M3BZ/iU=";
  };

  # cargoHash (fetchCargoVendor) is unusable here: crates.io/api/v1/* returns
  # 403 for this network's egress IP, while static.crates.io serves the same
  # /download paths fine. importCargoLock lets us point the registry at the
  # static CDN — and drops the vendor hash from the update loop entirely
  # (checksums come from Cargo.lock; bumps only need version + src hash).
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    extraRegistries = {
      "https://github.com/rust-lang/crates.io-index" = "https://static.crates.io/crates";
    };
  };

  # importCargoLock appends a [source."<index-url>"] block for every
  # extraRegistries key on top of its unconditional [source.crates-io] block;
  # with the key above both name the same registry and cargo refuses to build.
  # Drop the redundant URL-keyed block (crates-io already replaces-with vendor).
  postPatch = ''
    sed -i '/\[source."https:\/\/github.com\/rust-lang\/crates.io-index"\]/,+2d' ../.cargo/config.toml
  '';

  # Tests touch the network and depend on system state (sqlite cache, FS layout).
  doCheck = false;

  meta = {
    description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.mit;
    mainProgram = "rtk";
    platforms = lib.platforms.unix;
  };
}
