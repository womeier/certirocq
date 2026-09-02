{
  description = "CertiRocq: A Verified Compiler for Gallina, written in Gallina";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        lib = nixpkgs.lib;
        pkgs = import nixpkgs {
          inherit system;
          # compcert is unfree; permit just it (matches its license).
          config.allowUnfreePredicate = pkg: lib.getName pkg == "compcert";
        };
        rocqPackages = pkgs.rocqPackages_9_1;
        coqPackages = pkgs.coqPackages_9_1;
        rocq-core = rocqPackages.rocq-core;
        ocaml = rocq-core.ocamlPackages.ocaml;

        # MetaRocq's plugins are packaged with Coq-8-era findlib names:
        # rocq-metarocq-erasure's META says
        #   requires = "coq-core.plugins.ltac ..."
        # while Rocq 9.1 installs those plugins under rocq-runtime.plugins.*.
        # coqPackages.coq (the Coq-compat build of Rocq) ships the missing
        # coq-core findlib package. Without it on OCAMLPATH, compiling
        # anything that transitively requires MetaRocq.ErasurePlugin.Erasure
        # -- i.e. most of theories/ -- fails with
        #   Findlib error: coq-core.plugins.ltac not found
        # We only add it to OCAMLPATH, not to the shell's packages, to keep
        # its coqc/rocq binaries off PATH.
        coq-compat-site-lib = "${coqPackages.coq}/lib/ocaml/${ocaml.version}/site-lib";

        mcp = import ./mcp.nix { inherit pkgs lib; };

        # CertiRocq's dependencies (mirrors rocq-certirocq.opam).
        #
        #   From compcert   <- coqPackages.compcert
        #   From Equations  <- coqPackages.equations
        #   From ExtLib     <- coqPackages.ExtLib
        #   From MetaRocq   <- coqPackages.metarocq-*-plugin
        #   From Wasm       <- coqPackages.wasmcert (= coq-wasm 2.2.0)
        certirocq-deps = [
          coqPackages.compcert
          coqPackages.equations
          coqPackages.ExtLib
          coqPackages.wasmcert
          coqPackages.metarocq-erasure-plugin
          coqPackages.metarocq-safechecker-plugin
        ];

        certirocq = rocqPackages.mkRocqDerivation {
          pname = "certirocq";
          version = "dev+9.0";
          src = lib.cleanSource self;
          useDune = false;

          # CertiRocq has a custom multi-part Makefile (not a single
          # root _CoqProject), so we drive the pure-Coq build manually.
          # The OCaml plugins / bootstrap are intentionally left out of
          # this package; build them in the dev shell instead.
          configurePhase = ''
            runHook preConfigure
            ./configure.sh
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            # See coq-compat-site-lib above.
            export OCAMLPATH="${coq-compat-site-lib}''${OCAMLPATH:+:$OCAMLPATH}"
            make -j$NIX_BUILD_CORES all
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            dest="$out/lib/coq/${rocq-core.rocq-version}"
            mkdir -p "$dest"
            make -C libraries install COQMF_COQLIB="$dest"
            make -C theories install COQMF_COQLIB="$dest"
            make -C runtime install
            runHook postInstall
          '';

          propagatedBuildInputs = certirocq-deps;

          meta = {
            description = "A Verified Compiler for Gallina, written in Gallina";
            license = lib.licenses.mit;
            homepage = "https://certirocq.org/";
          };
        };
      in
      {
        packages.default = certirocq;
        packages.certirocq = certirocq;
        packages.rocq-mcp = mcp.rocq-mcp;
        packages.rocq-mcp-wheelhouse = mcp.rocq-mcp-wheelhouse;
        packages.pytanque = mcp.pytanque;

        devShells.default = pkgs.mkShell {
          name = "certirocq";
          packages = [
            rocq-core
            # provides the `pet` binary rocq-mcp's interactive tools need.
            rocqPackages.coq-lsp
            # the CertiRocq Coq dependencies, kept in `packages` (=
            # buildInputs) so rocq-core's setup hook adds each package's
            # lib/coq/<version>/user-contrib to $ROCQPATH.
            coqPackages.compcert
            coqPackages.equations
            coqPackages.ExtLib
            coqPackages.wasmcert
            coqPackages.metarocq-erasure-plugin
            coqPackages.metarocq-safechecker-plugin
            # build tooling
            pkgs.just
            pkgs.gnumake
            pkgs.clang # conf-clang (for the OCaml plugins)
            ocaml
            rocq-core.ocamlPackages.findlib
            # the MCP server exposing the Rocq prover to LLM agents
            mcp.rocq-mcp
          ];

          # This Rocq install has no `coqc` symlink — point rocq-mcp at
          # the `rocq` binary directly.
          ROCQ_COQC_BINARY = "${rocq-core}/bin/rocq";

          shellHook = ''
            # ROCQ_WORKSPACE must be the live checkout, not the store copy
            # of ${self} (which omits untracked files).
            export ROCQ_WORKSPACE="$PWD"
            # See coq-compat-site-lib above.
            export OCAMLPATH="${coq-compat-site-lib}''${OCAMLPATH:+:$OCAMLPATH}"
            echo "CertiRocq development environment"
            echo "  rocq:     $(rocq --version | head -1)"
            echo "  ocaml:    $(ocaml -version)"
            echo "  rocq-mcp: ${mcp.rocq-mcp.name}"
            echo
            echo "Build the Coq theories with:  make all"
          '';
        };
      }
    );
}
