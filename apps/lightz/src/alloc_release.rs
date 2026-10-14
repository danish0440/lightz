//! Give memory the system allocator keeps after frees back to the system
//! ([`lightz_engine::memory::set_release_hook`]). The platform call lives in
//! `lightz-sysmem`, the workspace's only crate allowed `unsafe`.

/// Install the hook.
pub fn install() {
    lightz_engine::memory::set_release_hook(release);
}

fn release() {
    let _ = lightz_sysmem::release_free_memory();
}
