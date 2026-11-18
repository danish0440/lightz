//! Review of PR #1065: while the window's device is being adopted (announced with
//! `set_window_device_pending`), neither the settings' warm-up nor a render creates a device of
//! its own, which would leave the window's device unused. One test in its own process: it runs
//! before anything else uses the GPU.

use std::sync::Arc;
use std::time::Duration;

use lightz_develop::DevelopSettings;
use lightz_pipeline::{RenderRequest, SourceInfo};

#[test]
fn no_device_of_its_own_is_created_while_the_window_device_is_pending() {
    lightz_gpu::set_window_device_pending(true);
    lightz_gpu::warm_up();
    assert!(!lightz_gpu::available());
    let src = Arc::new(lightz_scenes::demo_library()[0].render(300, 200));
    let rendered = lightz_gpu::render(&src, &SourceInfo::default(), &DevelopSettings::default(), &RenderRequest::fit(300, 200), None);
    assert!(rendered.is_none(), "the render takes the CPU path");
    assert!(lightz_gpu::wait_idle(Duration::from_secs(60)));
    let switched_off = lightz_gpu::unavailable_reason().is_some_and(|r| r.starts_with("disabled by LIGHTZ_GPU"));
    assert!(switched_off || !lightz_gpu::ready(), "no device was created");
    // withdrawn (the adoption couldn't start): renders create one as before
    lightz_gpu::set_window_device_pending(false);
}
