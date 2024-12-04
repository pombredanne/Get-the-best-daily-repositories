/*
 * Copyright 2023-2024 Juan Miguel Giraldo
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

use x86_64::structures::idt::{InterruptDescriptorTable, InterruptStackFrame, PageFaultErrorCode};
use crate::{print, println};
use pic8259::ChainedPics;
use spin;
use lazy_static::lazy_static;
use pc_keyboard::{layouts, HandleControl, Keyboard, ScancodeSet1, KeyCode};
use crate::time::SYSTEM_TIME;
use crate::scheduler::SCHEDULER;
use crate::vga_buffer::WRITER;
use crate::serial_println;
use crate::MEMORY_MANAGER;
use crate::process::PROCESS_LIST;
use x86_64::instructions::port::Port;
use crate::process::USER_STACK_SIZE;
use crate::memory::PageFault;

pub const PIC_1_OFFSET: u8 = 32;
pub const PIC_2_OFFSET: u8 = PIC_1_OFFSET + 8;

pub static PICS: spin::Mutex<ChainedPics> =
    spin::Mutex::new(unsafe { ChainedPics::new(PIC_1_OFFSET, PIC_2_OFFSET) });

const BACKSPACE: u8 = 0x08;
const ENTER: u8 = 0x0D;
const ESC: u8 = 0x1B;

#[derive(Debug, Clone, Copy)]
#[repr(u8)]
pub enum InterruptIndex {
    Timer = PIC_1_OFFSET,
    Keyboard = PIC_1_OFFSET + 1,
}

impl InterruptIndex {
    fn as_u8(self) -> u8 {
        self as u8
    }

    fn as_usize(self) -> usize {
        usize::from(self.as_u8())
    }
}

lazy_static! {
    static ref IDT: InterruptDescriptorTable = {
        let mut idt = InterruptDescriptorTable::new();
        idt.breakpoint.set_handler_fn(breakpoint_handler);
        unsafe {
            idt.double_fault
                .set_handler_fn(double_fault_handler)
                .set_stack_index(crate::gdt::DOUBLE_FAULT_IST_INDEX);
        }
        idt.page_fault.set_handler_fn(page_fault_handler);
        idt[InterruptIndex::Timer.as_usize()]
            .set_handler_fn(timer_interrupt_handler);
        idt[InterruptIndex::Keyboard.as_usize()]
            .set_handler_fn(keyboard_interrupt_handler);
        idt
    };
}

lazy_static! {
    static ref KEYBOARD: spin::Mutex<Keyboard<layouts::Jis109Key, ScancodeSet1>> = spin::Mutex::new(
        Keyboard::new(ScancodeSet1::new(), layouts::Jis109Key, HandleControl::Ignore)
    );
}

unsafe fn reset_keyboard_controller() {
    
    let mut command_port = Port::<u8>::new(0x64);
    let mut data_port = Port::<u8>::new(0x60);
    
    
    command_port.write(0xAD);  
    command_port.write(0xA7);  
    
    
    while (command_port.read() & 1) == 1 {
        data_port.read();
    }
    
    
    command_port.write(0x20);  
    while (command_port.read() & 1) == 0 {}
    let mut config = data_port.read();
    
    config |= 1;  
    config &= !0x10;  
    
    command_port.write(0x60);  
    while (command_port.read() & 2) != 0 {}
    data_port.write(config);
    
    
    command_port.write(0xAE);  
    
    
    data_port.write(0xFF);
    while (command_port.read() & 1) == 0 {}
    let _ack = data_port.read();
}

pub fn init_idt() {
    IDT.load();
    
    unsafe {
        PICS.lock().write_masks(0xfd, 0xff);
        PICS.lock().initialize();
        
        
        reset_keyboard_controller();
        
        
        for _ in 0..10000 {
            core::hint::spin_loop();
        }
        
        x86_64::instructions::interrupts::enable();
    }
    
    serial_println!("IDT, PIC, and keyboard initialization completed");
}

extern "x86-interrupt" fn breakpoint_handler(stack_frame: InterruptStackFrame) {
    println!("EXCEPTION: BREAKPOINT\n{:#?}", stack_frame);
}

extern "x86-interrupt" fn double_fault_handler(
    stack_frame: InterruptStackFrame, _error_code: u64) -> ! 
{
    panic!("EXCEPTION: DOUBLE FAULT\n{:#?}", stack_frame);
}


extern "x86-interrupt" fn page_fault_handler(
    stack_frame: InterruptStackFrame,
    error_code: PageFaultErrorCode,
) {
    use x86_64::registers::control::Cr2;
    
    let fault_addr = Cr2::read();
    let present = error_code.contains(PageFaultErrorCode::PROTECTION_VIOLATION);
    let write = error_code.contains(PageFaultErrorCode::CAUSED_BY_WRITE);
    let user = error_code.contains(PageFaultErrorCode::USER_MODE);
    let instruction_fetch = error_code.contains(PageFaultErrorCode::INSTRUCTION_FETCH);
    
    serial_println!("Page fault at address: {:#x}", fault_addr.as_u64());
    serial_println!("Error code: {:?}", error_code);
    
    let mut handled = false;
    
    
    if !present && user && write {
        if let Some(current) = PROCESS_LIST.lock().current() {
            if let Some(stack_top) = current.user_stack_top() {
                if fault_addr.as_u64() <= stack_top.as_u64() && 
                   fault_addr.as_u64() >= stack_top.as_u64() - USER_STACK_SIZE as u64 {
                    let mut mm_lock = MEMORY_MANAGER.lock();
                    if let Some(mm) = mm_lock.as_mut() {
                        if mm.handle_stack_growth(fault_addr).is_ok() {
                            handled = true;
                        }
                    }
                }
            }
        }
    }
    
    
    if !handled && present && write {
        let mut mm_lock = MEMORY_MANAGER.lock();
        if let Some(ref mut mm) = *mm_lock {
            if let Ok(()) = mm.handle_cow_fault(fault_addr) {
                handled = true;
            }
        }
    }
    
    
    if !handled && !present && !instruction_fetch {
        let mut mm_lock = MEMORY_MANAGER.lock();
        if let Some(mm) = mm_lock.as_mut() {
            let fault = PageFault {
                address: fault_addr,
                error_code,
            };
            if mm.handle_page_fault(fault).is_ok() {
                handled = true;
            }
        }
    }
    
    if !handled {
        if user {
            
            let mut process_list = PROCESS_LIST.lock();
            if let Some(current) = process_list.current_mut() {
                serial_println!("Killing process {} due to page fault", current.id().0);
                current.exit(-11, &mut MEMORY_MANAGER.lock().as_mut().unwrap()).unwrap_or(());
            }
        } else {
            panic!("Unhandled kernel page fault:\n{:#?}\nError Code: {:?}\nAddress: {:#x}",
                stack_frame, error_code, fault_addr.as_u64());
        }
    }
}

extern "x86-interrupt" fn timer_interrupt_handler(
    _stack_frame: InterruptStackFrame)
{
    SYSTEM_TIME.tick();
    
    {
        let mut scheduler = SCHEDULER.lock();
        scheduler.tick();
    }
    
    unsafe {
        PICS.lock()
            .notify_end_of_interrupt(InterruptIndex::Timer.as_u8());
    }
}

fn handle_backspace() {
    let mut writer = WRITER.lock();
    if writer.column_position > 0 {
        writer.column_position -= 1;
        writer.write_byte(b' ');
        writer.column_position -= 1;
    }
}

extern "x86-interrupt" fn keyboard_interrupt_handler(
    _stack_frame: InterruptStackFrame)
{
    use x86_64::instructions::port::Port;
    use crate::syscall::push_to_keyboard_buffer;
    use pc_keyboard::DecodedKey;

    
    let mut port = Port::new(0x60);
    let scancode: u8 = unsafe { port.read() };
    
    serial_println!("Keyboard interrupt: scancode={:#x}", scancode);

    
    unsafe {
        PICS.lock()
            .notify_end_of_interrupt(InterruptIndex::Timer.as_u8());
    }

    
    let mut keyboard = KEYBOARD.lock();
    
    if let Ok(Some(key_event)) = keyboard.add_byte(scancode) {
        if let Some(key) = keyboard.process_keyevent(key_event) {
            match key {
                DecodedKey::Unicode(character) => {
                    serial_println!("Received character: {}", character);
                    push_to_keyboard_buffer(character as u8);
                },
                DecodedKey::RawKey(key) => {
                    serial_println!("Received raw key: {:?}", key);
                    match key {
                        KeyCode::ArrowLeft => {
                            
                            push_to_keyboard_buffer(27);  
                            push_to_keyboard_buffer(b'[');
                            push_to_keyboard_buffer(b'D');
                        },
                        KeyCode::ArrowRight => {
                            
                            push_to_keyboard_buffer(27);  
                            push_to_keyboard_buffer(b'[');
                            push_to_keyboard_buffer(b'C');
                        },
                        KeyCode::ArrowUp => {
                            
                            push_to_keyboard_buffer(27);  
                            push_to_keyboard_buffer(b'[');
                            push_to_keyboard_buffer(b'A');
                        },
                        KeyCode::ArrowDown => {
                            
                            push_to_keyboard_buffer(27);  
                            push_to_keyboard_buffer(b'[');
                            push_to_keyboard_buffer(b'B');
                        },
                        KeyCode::Backspace => push_to_keyboard_buffer(8),
                        KeyCode::Delete => push_to_keyboard_buffer(127),
                        _ => {}
                    }
                }
            }
        }
    }
}