{
  lib,
  pkgs,
  mkCoqDerivation,
  wasmcert,
  coqprime,
  compcert,
  metarocq,
  ExtLib,
  version ? null,
}:

with lib;
mkCoqDerivation {
  pname = "CertiRocq";
  mlPlugin = true;

  inherit version;
  releaseRev = v: "v${v}";

  nativeBuildInputs = [
    pkgs.clang
    pkgs.python3
  ];

  propagatedBuildInputs = [
    wasmcert
    coqprime
    compcert
    ExtLib
    metarocq
  ];

  patchPhase = ''
    patchShebangs ./configure.sh
    patchShebangs ./clean_extraction.sh
    patchShebangs ./make_plugin.sh
  '';

  configurePhase = ''
    ./configure.sh local
  '';

  buildPhase = ''
    runHook preBuild

    make
    make plugin
    make cplugin
    make bootstrap

    runHook postBuild
  '';

  meta = {
    description = "CertiRocq";
    maintainers = with maintainers; [ womeier ];
    license = licenses.mit;
  };
}
