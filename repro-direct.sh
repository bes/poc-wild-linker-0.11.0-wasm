#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"

HOST=$(rustc -vV | sed -n 's/^host: //p')
TOOLS="$(rustc --print sysroot)/lib/rustlib/$HOST/bin"
RUST_LLD="$TOOLS/rust-lld"
LLVM_AR="$TOOLS/llvm-ar"
LLVM_OBJDUMP="$TOOLS/llvm-objdump"
WILD=${WILD:-wild}

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

set -e
rm -rf out
mkdir -p out
for name in object archive_member custom_section; do
    rustc --edition 2024 --target wasm32-unknown-unknown --crate-type lib --emit obj \
        -C opt-level=1 -C codegen-units=1 -o "out/$name.o" "minimal/$name.rs"
done
"$LLVM_AR" rcs out/libarchive.a out/archive_member.o
set +e

echo "rustc:   $(rustc -V)"
echo "wild:    $("$WILD" --version)"
echo "lld:     $("$RUST_LLD" -flavor wasm --version)"

echo
echo "=== 1. --features=<list> is not a recognized option ==="
run "$RUST_LLD" -flavor wasm --no-entry --export defined_in_object \
    --no-check-features --features=bulk-memory,mutable-globals,sign-ext out/object.o -o out/1-lld.wasm
run "$WILD" -flavor wasm --no-entry --export defined_in_object \
    --no-check-features --features=bulk-memory,mutable-globals,sign-ext out/object.o -o out/1-wild.wasm

echo
echo "=== 2. --export does not load the archive member that defines the symbol ==="
run "$RUST_LLD" -flavor wasm --no-entry --export defined_in_archive_member \
    out/object.o out/libarchive.a -o out/2-lld.wasm
run "$WILD" -flavor wasm --no-entry --export defined_in_archive_member \
    out/object.o out/libarchive.a -o out/2-wild.wasm

echo
echo "=== 2a. control: wild exports the same symbol once the member is loaded ==="
run "$WILD" -flavor wasm --no-entry --export defined_in_archive_member \
    out/object.o --whole-archive out/libarchive.a --no-whole-archive -o out/2a-wild-whole-archive.wasm
run "$WILD" -flavor wasm --no-entry --export defined_in_archive_member \
    out/object.o out/archive_member.o -o out/2a-wild-object.wasm

echo
echo "=== 3. custom sections from input objects are dropped ==="
link_custom_section() {
    run "$RUST_LLD" -flavor wasm --no-entry --export defined_with_custom_section "$@" \
        out/custom_section.o -o out/3-lld.wasm && sections out/3-lld.wasm
    run "$WILD" -flavor wasm --no-entry --export defined_with_custom_section "$@" \
        out/custom_section.o -o out/3-wild.wasm && sections out/3-wild.wasm
}
sections out/custom_section.o
link_custom_section
link_custom_section --strip-all
link_custom_section --no-gc-sections --keep-section=my_custom_section
