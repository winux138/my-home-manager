{
  lib,
  stdenvNoCC,
  fetchurl,
  herdr-core,
  makeWrapper,
  versionCheckHook,
}:

assert lib.assertMsg (lib.versionAtLeast herdr-core.version "0.1.18")
  "Rodeo requires herdr-core >= 0.1.18";
stdenvNoCC.mkDerivation (final: {
  pname = "rodeo";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/lukeed/rodeo/releases/download/v${final.version}/rodeo-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-0r7u6VCW4N8f9w5BbjIY+Xh8olC8hmunHAH/yBxYNco=";
  };
  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    install -Dm755 rodeo "$out/bin/rodeo"
    wrapProgram "$out/bin/rodeo" --prefix PATH : ${lib.makeBinPath [ herdr-core ]}
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Keyboard-first terminal UI for Herdr Core";
    homepage = "https://github.com/lukeed/rodeo";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "rodeo";
  };
})
