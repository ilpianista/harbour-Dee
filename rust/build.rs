use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_dir = PathBuf::from(&crate_dir).join("..").join("src");

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_language(cbindgen::Language::C)
        .with_include_guard("LEMMY_BRIDGE_H")
        .with_no_includes()
        .with_sys_include("stdbool.h")
        .generate()
        .expect("Unable to generate C bindings")
        .write_to_file(out_dir.join("lemmy_bridge.h"));
}
