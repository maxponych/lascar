#![no_main]
#![no_std]
extern crate alloc;
use core::time::Duration;

use alloc::vec::Vec;
use log::info;
use uefi::{
    boot::{MemoryType, ScopedProtocol},
    fs::{FileSystem, FileSystemResult},
    prelude::*,
    proto::{
        console::gop::{GraphicsOutput, PixelFormat},
        media::fs::SimpleFileSystem,
    },
    CString16, Result,
};

use uefi::allocator::Allocator;

#[global_allocator]
static ALLOCATOR: Allocator = Allocator;

#[derive(Clone, Copy)]
#[repr(C)]
pub struct VBE {
    pub width: usize,
    pub height: usize,
    pub pitch: usize,
    pub framebuffer: *mut u32,
    pub pixel_format: PixelFormat,
}

impl VBE {
    pub fn new() -> Result<Self> {
        info!("Getting GOP handle...");
        let gop_handle = uefi::boot::get_handle_for_protocol::<GraphicsOutput>()?;

        info!("Opening GOP protocol...");
        let mut gop = unsafe {
            boot::open_protocol::<GraphicsOutput>(
                boot::OpenProtocolParams {
                    handle: gop_handle,
                    agent: boot::image_handle(),
                    controller: None,
                },
                boot::OpenProtocolAttributes::GetProtocol,
            )?
        };

        info!("Getting mode info...");
        let mode_info = gop.current_mode_info();

        info!("Getting framebuffer...");
        let fb = gop.frame_buffer().as_mut_ptr() as *mut u32;

        info!("Getting pixel format...");
        let pixel_format = mode_info.pixel_format();

        let pitch_pixels = mode_info.stride();

        info!("VBE struct created");
        Ok(Self {
            width: mode_info.resolution().0 as usize,
            height: mode_info.resolution().1 as usize,
            pitch: pitch_pixels,
            framebuffer: fb,
            pixel_format,
        })
    }
}

fn read_file(path: &str) -> FileSystemResult<Vec<u8>> {
    let path: CString16 = CString16::try_from(path).expect("Failed to parse file path");
    let fs: ScopedProtocol<SimpleFileSystem> =
        boot::get_image_file_system(boot::image_handle()).expect("Failed to get filesystem image");
    let mut fs = FileSystem::new(fs);
    fs.read(path.as_ref())
}

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    system::with_stdout(|stdout| {
        stdout.clear().unwrap();
    });

    info!("UEFI Bootloader started");
    info!("Initializing graphics...");
    let vbe = VBE::new().unwrap();
    info!("GOP initialized: {}x{}", vbe.width, vbe.height);

    info!("Loading kernel from /kernel.bin...");
    let kernel_data = read_file("\\kernel.bin").unwrap();
    info!("Kernel loaded: {} bytes", kernel_data.len());

    const KERNEL_BASE: u64 = 0x200000;

    info!("Allocating memory at 0x{:X}...", KERNEL_BASE);
    let page_count = (kernel_data.len() + 4095) / 4096;
    let kernel_addr = boot::allocate_pages(
        boot::AllocateType::Address(KERNEL_BASE),
        MemoryType::LOADER_CODE,
        page_count,
    )
    .expect("Failed to allocate memory for kernel");
    info!("Allocated {} pages", page_count);

    info!("Copying kernel to memory...");
    let kernel_dest = unsafe {
        core::slice::from_raw_parts_mut(kernel_addr.as_ptr() as *mut u8, kernel_data.len())
    };
    kernel_dest.copy_from_slice(&kernel_data);
    info!("Kernel copied successfully");

    info!("Exiting boot services in 2s");
    boot::stall(Duration::from_secs(2));
    unsafe {
        let _ = boot::exit_boot_services(Some(boot::MemoryType::LOADER_DATA));
    }

    unsafe {
        core::arch::asm!(
            "call {entry}",
            entry = in(reg) kernel_addr.as_ptr(),
            in("rdi") &vbe,
            options(noreturn)
        );
    }
}
