//! Issue #620: quitting right after the start must not leave the device being created (a long
//! call into the driver, on the `lc-gpu-init` thread) while the process exits. Once
//! `begin_shutdown` is called the device is not created at all.
//! One test in its own process: the shutdown comes before the first use of the GPU.

use std::sync::Arc;
use std::time::Duration;

use lightz_develop::DevelopSettings;
use lightz_pipeline::{RenderRequest, SourceInfo};

#[test]
fn the_device_is_not_created_once_the_process_is_ending() {
    lightz_gpu::begin_shutdown();
    lightz_gpu::warm_up();
    assert!(!lightz_gpu::available());
    assert_eq!(lightz_gpu::adapter_name(), None);
    let src = Arc::new(lightz_scenes::demo_library()[0].render(300, 200));
    let rendered = lightz_gpu::render(&src, &SourceInfo::default(), &DevelopSettings::default(), &RenderRequest::fit(300, 200), None);
    assert!(rendered.is_none());
    assert!(lightz_gpu::wait_idle(Duration::from_secs(60)), "the warm-up thread found the gate closed");
    // `ready()` is "device creation finished" (or the GPU is switched off by the environment)
    let switched_off = lightz_gpu::unavailable_reason().is_some_and(|r| r.starts_with("disabled by LIGHTZ_GPU"));
    assert!(switched_off || !lightz_gpu::ready(), "no device was created");
}
