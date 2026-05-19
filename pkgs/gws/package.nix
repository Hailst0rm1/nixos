{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "gws";
  version = "0.22.5";

  src = fetchFromGitHub {
    owner = "googleworkspace";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Bj4gPklufU6p2JpvN6j7QViv7ghSn52jemeXPVXkhlk=";
  };

  cargoHash = "sha256-8vVTACodxxju4x19bNzDKM5xn6btV1UCh+5GUxS70S8=";

  nativeBuildInputs = [pkg-config];

  buildInputs = [dbus];

  doCheck = false;

  meta = {
    description = "One CLI for all of Google Workspace";
    homepage = "https://github.com/googleworkspace/cli";
    changelog = "https://github.com/googleworkspace/cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "gws";
    maintainers = with lib.maintainers; [imalison];
  };
})
