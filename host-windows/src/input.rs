use serde::{Deserialize, Serialize};
use winapi::shared::minwindef::{BOOL, LPARAM, TRUE};
use winapi::shared::windef::{HDC, HMONITOR, LPRECT, RECT};
use winapi::um::winuser::{
    EnumDisplayMonitors, GetMonitorInfoW, GetSystemMetrics, SendInput, INPUT, INPUT_MOUSE,
    MONITORINFO, MONITORINFOF_PRIMARY, MOUSEEVENTF_ABSOLUTE, MOUSEEVENTF_LEFTDOWN,
    MOUSEEVENTF_LEFTUP, MOUSEEVENTF_MOVE, MOUSEEVENTF_VIRTUALDESK, MOUSEINPUT, SM_CXVIRTUALSCREEN,
    SM_CYVIRTUALSCREEN, SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN,
};

#[derive(Clone, Copy, Debug)]
pub struct DisplayTarget {
    left: i32,
    top: i32,
    width: i32,
    height: i32,
}

impl DisplayTarget {
    pub fn left(&self) -> i32 {
        self.left
    }

    pub fn top(&self) -> i32 {
        self.top
    }

    pub fn width(&self) -> i32 {
        self.width
    }

    pub fn height(&self) -> i32 {
        self.height
    }
}

#[derive(Clone, Copy, Debug)]
struct EnumeratedMonitor {
    target: DisplayTarget,
    is_primary: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct DisplayInfo {
    pub index: u32,
    pub left: i32,
    pub top: i32,
    pub width: i32,
    pub height: i32,
    pub is_primary: bool,
}

#[derive(Debug, Deserialize)]
pub struct PointerInputEvent {
    pub phase: PointerPhase,
    pub x_norm: f32,
    pub y_norm: f32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PointerPhase {
    Down,
    Move,
    Up,
}

pub fn inject_pointer_event(
    event: &PointerInputEvent,
    target: &DisplayTarget,
) -> anyhow::Result<()> {
    let x_norm = event.x_norm.clamp(0.0, 1.0);
    let y_norm = event.y_norm.clamp(0.0, 1.0);

    unsafe {
        // Map normalized touch position into the selected monitor's desktop-space rectangle.
        let target_x = target.left as f32 + x_norm * (target.width - 1).max(1) as f32;
        let target_y = target.top as f32 + y_norm * (target.height - 1).max(1) as f32;

        let virt_left = GetSystemMetrics(SM_XVIRTUALSCREEN);
        let virt_top = GetSystemMetrics(SM_YVIRTUALSCREEN);
        let virt_w = GetSystemMetrics(SM_CXVIRTUALSCREEN).max(1);
        let virt_h = GetSystemMetrics(SM_CYVIRTUALSCREEN).max(1);

        let absolute_x =
            (((target_x - virt_left as f32) * 65535.0) / (virt_w - 1).max(1) as f32).round() as i32;
        let absolute_y =
            (((target_y - virt_top as f32) * 65535.0) / (virt_h - 1).max(1) as f32).round() as i32;

        let mut input: INPUT = std::mem::zeroed();
        input.type_ = INPUT_MOUSE;
        *input.u.mi_mut() = MOUSEINPUT {
            dx: absolute_x,
            dy: absolute_y,
            mouseData: 0,
            dwFlags: MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK | MOUSEEVENTF_MOVE,
            time: 0,
            dwExtraInfo: 0,
        };

        let mut inputs = vec![input];

        match event.phase {
            PointerPhase::Down => inputs.push(mouse_button_input(MOUSEEVENTF_LEFTDOWN)),
            PointerPhase::Move => {}
            PointerPhase::Up => inputs.push(mouse_button_input(MOUSEEVENTF_LEFTUP)),
        }

        let sent = SendInput(
            inputs.len() as u32,
            inputs.as_mut_ptr(),
            std::mem::size_of::<INPUT>() as i32,
        );

        if sent != inputs.len() as u32 {
            anyhow::bail!("SendInput failed: only sent {sent}/{} events", inputs.len());
        }
    }

    Ok(())
}

pub fn resolve_display_target(display_idx: u32) -> anyhow::Result<DisplayTarget> {
    let monitors = enumerate_monitors()?;
    if monitors.is_empty() {
        anyhow::bail!("no monitors were enumerated")
    }

    let idx = display_idx as usize;
    if let Some(found) = monitors.get(idx) {
        return Ok(found.target);
    }

    Ok(monitors[0].target)
}

pub fn default_display_for_mode(mode: &str) -> anyhow::Result<u32> {
    let monitors = enumerate_monitors()?;
    if monitors.is_empty() {
        anyhow::bail!("no monitors were enumerated")
    }

    if mode.eq_ignore_ascii_case("extended") && monitors.len() > 1 {
        return Ok(1);
    }

    Ok(0)
}

pub fn list_displays() -> anyhow::Result<Vec<DisplayInfo>> {
    let monitors = enumerate_monitors()?;
    let mut list = Vec::with_capacity(monitors.len());
    for (idx, monitor) in monitors.into_iter().enumerate() {
        list.push(DisplayInfo {
            index: idx as u32,
            left: monitor.target.left,
            top: monitor.target.top,
            width: monitor.target.width,
            height: monitor.target.height,
            is_primary: monitor.is_primary,
        });
    }
    Ok(list)
}

fn enumerate_monitors() -> anyhow::Result<Vec<EnumeratedMonitor>> {
    let mut monitors: Vec<EnumeratedMonitor> = Vec::new();

    unsafe {
        let ok = EnumDisplayMonitors(
            std::ptr::null_mut(),
            std::ptr::null(),
            Some(enum_monitor_proc),
            &mut monitors as *mut Vec<EnumeratedMonitor> as LPARAM,
        );

        if ok == 0 {
            anyhow::bail!("EnumDisplayMonitors failed")
        }
    }

    monitors.sort_by_key(|monitor| (!monitor.is_primary, monitor.target.left, monitor.target.top));
    Ok(monitors)
}

unsafe extern "system" fn enum_monitor_proc(
    hmonitor: HMONITOR,
    _hdc: HDC,
    _rect: LPRECT,
    lparam: LPARAM,
) -> BOOL {
    let monitors = &mut *(lparam as *mut Vec<EnumeratedMonitor>);

    let mut info: MONITORINFO = std::mem::zeroed();
    info.cbSize = std::mem::size_of::<MONITORINFO>() as u32;

    if GetMonitorInfoW(hmonitor, &mut info as *mut MONITORINFO) == 0 {
        return TRUE;
    }

    let RECT {
        left,
        top,
        right,
        bottom,
    } = info.rcMonitor;

    monitors.push(EnumeratedMonitor {
        target: DisplayTarget {
            left,
            top,
            width: (right - left).max(1),
            height: (bottom - top).max(1),
        },
        is_primary: (info.dwFlags & MONITORINFOF_PRIMARY) != 0,
    });

    TRUE
}

fn mouse_button_input(flags: u32) -> INPUT {
    unsafe {
        let mut input: INPUT = std::mem::zeroed();
        input.type_ = INPUT_MOUSE;
        *input.u.mi_mut() = MOUSEINPUT {
            dx: 0,
            dy: 0,
            mouseData: 0,
            dwFlags: flags,
            time: 0,
            dwExtraInfo: 0,
        };
        input
    }
}
