#![no_std]

#[unsafe(link_section = "my_custom_section")]
pub static MY_CUSTOM_SECTION: [u8; 5] = *b"hello";

#[unsafe(no_mangle)]
pub extern "C" fn defined_with_custom_section() -> i32 {
    3
}
