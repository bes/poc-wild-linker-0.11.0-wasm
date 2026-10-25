extern crate dep;

#[unsafe(no_mangle)]
pub extern "C" fn app_exported() -> i32 {
    1
}
