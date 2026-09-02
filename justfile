# CertiRocq development commands (see justfile in certirocq/wasm-opt for reference).

default: build

# Build the Coq theories and libraries.
build:
    make all

# Build everything, including the OCaml plugins and bootstrap.
build-full:
    ./configure.sh
    make all
    make plugins
    make bootstrap

# Launch opencode inside the nix dev shell (with rocq-mcp on PATH).
opencode:
    nix develop -c opencode

# Launch claude-sandbox inside the nix dev shell.
claude:
    nix develop -c claude-sandbox

clean:
    make clean
