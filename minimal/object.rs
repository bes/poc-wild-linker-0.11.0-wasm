#![no_std]

#[unsafe(no_mangle)]
pub extern "C" fn defined_in_object() -> i32 {
    1
}
