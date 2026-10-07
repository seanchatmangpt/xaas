//! W638 court fixture: minimal hand-built wasm guest carrying the same
//! packed-u64 ABI as the graphlaw kernel (gl_alloc/gl_free/gl_call, exported
//! linear memory), used ONLY for the watchdog (timeout-refusal) leg of the
//! Xaas.Semantics.GraphlawWasm court, where a statutory-speed guest cannot
//! lose the race against the 15ms watchdog by construction.
//!
//! Built at test time with:
//!   rustc --target wasm32-unknown-unknown --crate-type=cdylib -O <this file>
//!
//! gl_call spins well past 15ms, then echoes the request bytes back through
//! the packed-u64 ABI so that the leg observes the timeout refusal, not an
//! echo-trap artifact.

#![no_std]
#![no_main]

use core::hint::black_box;
use core::panic::PanicInfo;

#[panic_handler]
fn ph(_info: &PanicInfo) -> ! {
    loop {
        core::hint::spin_loop();
    }
}

// Single fixed slot for the input buffer; output echo lands above it.
const BASE: u32 = 8192;

#[no_mangle]
pub extern "C" fn gl_alloc(_len: u32) -> *mut u8 {
    BASE as *mut u8
}

#[no_mangle]
pub unsafe extern "C" fn gl_free(_ptr: *mut u8, _len: u32) {}

#[no_mangle]
pub unsafe extern "C" fn gl_call(ptr: *const u8, len: u32) -> u64 {
    // Spin far past the 15ms host watchdog (bounded so the fixture instance
    // eventually returns and the suite is not left hanging).
    let mut i: u64 = 0;
    while i < 200_000_000 {
        i = i.wrapping_add(1);
        black_box(i);
    }

    let out = BASE + 4096;
    core::ptr::copy(ptr, out as *mut u8, len as usize);
    ((out as u64) << 32) | (len as u64)
}
