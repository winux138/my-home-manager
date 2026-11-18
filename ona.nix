{
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  openssh,
}:

stdenvNoCC.mkDerivation (final: {
  pname = "ona";
  version = "20261112.11538.0";

  # Version and linux-amd64 digest: https://app.gitpod.io/releases/cli/stable/manifest.json
  src = fetchurl {
    url = "https://releases.gitpod.io/cli/releases/${final.version}/gitpod-linux-amd64";
    hash = "sha256-7uJHt/Rvi/LmDEuVpmKEa3nGfh9huBtBYblf1/iqg0E=";
  };
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/ona"
    # Prefer the host ssh: it can resolve the workstation's directory-service UID.
    wrapProgram "$out/bin/ona" --suffix PATH : ${openssh}/bin
    runHook postInstall
  '';

  meta.mainProgram = "ona";
  meta.platforms = [ "x86_64-linux" ];
})
