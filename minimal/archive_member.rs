#![no_std]

#[unsafe(no_mangle)]
pub extern "C" fn defined_in_archive_member() -> i32 {
    2
}
