#[unsafe(link_section = "my_custom_section")]
pub static MY_CUSTOM_SECTION: [u8; 5] = *b"hello";

#[unsafe(no_mangle)]
pub extern "C" fn custom_section_exported() -> i32 {
    3
}
