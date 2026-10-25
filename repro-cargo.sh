#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"

HOST=$(rustc -vV | sed -n 's/^host: //p')
LLVM_OBJDUMP="$(rustc --print sysroot)/lib/rustlib/$HOST/bin/llvm-objdump"
TARGET=wasm32-unknown-unknown

run() {
    echo
    echo "\$ $*"
    "$@"
    local status=$?
    echo "exit status: $status"
    return $status
}

sections() {
    echo "sections in $1: $("$LLVM_OBJDUMP" -h "$1" | awk '$1 ~ /^[0-9]+$/ { printf "%s ", $2 }')"
}

echo "rustc:   $(rustc -V)"
echo "wild:    $(wild --version)"

echo
echo "=== baseline: RUSTFLAGS replaces the rustflags from .cargo/config.toml, so rustc links with rust-lld ==="
run env RUSTFLAGS= cargo build --target $TARGET --target-dir target/lld --workspace

echo
echo "=== 1. wild plus a --features linker argument ==="
run cargo build --target $TARGET --target-dir target/wild-features -p app \
    --config "target.$TARGET.rustflags=[\"-C\", \"link-arg=--no-check-features\", \"-C\", \"link-arg=--features=bulk-memory,mutable-globals,sign-ext\"]"

echo
echo "=== 2. wild from .cargo/config.toml: rustc passes --export dep_exported, which only an unreferenced rlib member defines ==="
run cargo build --target $TARGET --target-dir target/wild -p app

echo
echo "=== 3. wild from .cargo/config.toml: the cdylib links, but my_custom_section is missing from it ==="
run cargo build --target $TARGET --target-dir target/wild -p custom-section
sections target/lld/$TARGET/debug/custom_section.wasm
sections target/wild/$TARGET/debug/custom_section.wasm
