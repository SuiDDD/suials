use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::fs::{File, create_dir_all, copy};
use std::io::BufReader;
use std::path::{Path, PathBuf};
use tar::Archive;
use xz2::read::XzDecoder;
use xz2::stream::Stream;
#[unsafe(no_mangle)]
pub extern "C" fn unpack_xz_tar(src_ptr: *const c_char, dest_ptr: *const c_char) -> *mut c_char {
    if src_ptr.is_null() || dest_ptr.is_null() {
        return CString::new("Null pointer").unwrap().into_raw();
    }
    let src = unsafe { CStr::from_ptr(src_ptr).to_string_lossy() };
    let dest = unsafe { CStr::from_ptr(dest_ptr).to_string_lossy() };
    match perform_unpack(&src, &dest) {
        Ok(_) => std::ptr::null_mut(),
        Err(e) => {
            CString::new(e.to_string()).unwrap().into_raw()
        }
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { let _ = CString::from_raw(ptr); }
    }
}
fn perform_unpack(src: &str, dest: &str) -> Result<(), Box<dyn std::error::Error>> {
    let f = File::open(src)?;
    let _ = create_dir_all(dest);
    let reader = BufReader::with_capacity(1024 * 1024, f);
    let stream = Stream::new_auto_decoder(u64::MAX, 0x08)?;
    let decompressor = XzDecoder::new_stream(reader, stream);
    let mut archive = Archive::new(decompressor);
    archive.set_preserve_permissions(true);
    archive.set_unpack_xattrs(true);
    archive.set_overwrite(true);
    let dest_path = Path::new(dest);
    let mut hardlinks: Vec<(PathBuf, PathBuf)> = Vec::with_capacity(512);
    for entry in archive.entries()? {
        let mut entry = entry?;
        let path = entry.path()?.to_path_buf();
        if entry.header().entry_type().is_hard_link() {
            if let Some(link_name) = entry.link_name()? {
                hardlinks.push((link_name.to_path_buf(), path));
                continue;
            }
        }
        entry.unpack_in(dest)?;
    }
    for (src_rel, dest_rel) in hardlinks {
        let full_dest = dest_path.join(&dest_rel);
        let mut cleaned_src = src_rel.clone();
        if src_rel.is_absolute() {
            let s = src_rel.to_string_lossy();
            if let Some(pos) = s.find("containers/0/") {
                cleaned_src = PathBuf::from(&s[pos + 13..]);
            } else {
                cleaned_src = PathBuf::from(s.trim_start_matches('/'));
            }
        }
        let full_src = dest_path.join(&cleaned_src);
        if full_src.exists() {
            let _ = copy(&full_src, &full_dest);
        }
    }
    Ok(())
}