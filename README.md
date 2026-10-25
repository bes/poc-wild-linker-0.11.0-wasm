# wild 0.11.0 can't link wasm-bindgen crates for wasm32-unknown-unknown

Linking a wasm-bindgen crate for `wasm32-unknown-unknown` with wild 0.11.0 fails:

1. `--features=<list>` is rejected as an unrecognized option.
2. `--export <symbol>` doesn't load the archive member that defines the symbol
3. Custom sections from input objects are not copied to the output, so `wasm-bindgen` can't find its `__wasm_bindgen_unstable` section.

## Environment

- wild 0.11.0
- rustc 1.99.1
- macOS on aarch64

## Running the reproducers

* `repro-direct.sh` compiles the files in `minimal/` to wasm objects with `rustc --emit obj`, puts one of them in an archive with `llvm-ar`, and links them with both linkers. Set `WILD=/path/to/wild` to test another build of wild.
* `repro-cargo.sh` first builds the workspace with rust-lld as a baseline (setting `RUSTFLAGS` replaces the rustflags from `.cargo/config.toml`), and then builds each case with wild.

## 1. `--features=<list>` is not recognized

```
$ wild -flavor wasm --no-entry --export defined_in_object --no-check-features --features=bulk-memory,mutable-globals,sign-ext out/object.o -o out/1-wild.wasm
wild: error: unrecognized option(s): --features=bulk-memory,mutable-globals,sign-ext
```

## 2. `--export` doesn't load archive members

```
$ wild -flavor wasm --no-entry --export defined_in_archive_member out/object.o out/libarchive.a -o out/2-wild.wasm
wild: error: symbol exported via --export not found: defined_in_archive_member
```

`web-sys` defines a `#[no_mangle]` `__wbindgen_describe_*` function for each JavaScript import it binds.

A `cdylib` that depends on `web-sys` hits this as soon as one of `web-sys`'s codegen units isn't otherwise referenced.
In the original project, `wasm-streams` was the first:

```
wild: error: symbol exported via --export not found: __wbindgen_describe___wbg_alert_33064daf5150a1a4
```

## 3. Custom sections from input objects are dropped

`minimal/custom_section.rs` puts a static in a custom section with `#[unsafe(link_section = "my_custom_section")]`, which is how wasm-bindgen emits its `__wasm_bindgen_unstable` metadata.

| Linker arguments                                      | rust-lld output has `my_custom_section` | wild output has `my_custom_section` |
| ----------------------------------------------------- | --------------------------------------- | ----------------------------------- |
| (none)                                                | yes                                     | no                                  |
| `--strip-all`                                         | yes                                     | no                                  |
| `--no-gc-sections --keep-section=my_custom_section`   | yes                                     | no                                  |

The links succeed, but the section is silently missing. wild also drops the `producers` section. In the cargo build, wild drops the `.debug_*` sections too, but that one is already known (wild-linker/wild#2561).

Running `wasm-bindgen` 0.2.129 on a module that wild linked fails with:

```
error: failed to read wasm-bindgen data from '<module>.wasm'

Caused by:
    the `__wasm_bindgen_unstable` custom section is missing, but the module still contains wasm-bindgen shims
```
