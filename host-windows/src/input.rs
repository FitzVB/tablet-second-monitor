use serde::Deserialize;
use winapi::um::winuser::{
    GetSystemMetrics, SendInput, INPUT, INPUT_MOUSE, MOUSEEVENTF_ABSOLUTE, MOUSEEVENTF_LEFTDOWN,
    MOUSEEVENTF_LEFTUP, MOUSEEVENTF_MOVE, MOUSEEVENTF_VIRTUALDESK, MOUSEINPUT,
    SM_CXSCREEN, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN, SM_CYSCREEN, SM_XVIRTUALSCREEN,
    SM_YVIRTUALSCREEN,
};

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
) -> anyhow::Result<()> {
    let x_norm = event.x_norm.clamp(0.0, 1.0);
    let y_norm = event.y_norm.clamp(0.0, 1.0);

    unsafe {
        // Map normalised touch position to the PRIMARY display (the captured display).
        // SM_CXSCREEN/SM_CYSCREEN give primary display dimensions at desktop origin (0, 0).
        // We then re-map those desktop pixel coords into the [0..65535] virtual-screen
        // range that MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK expects.
        let screen_w = GetSystemMetrics(SM_CXSCREEN).max(1);
        let screen_h = GetSystemMetrics(SM_CYSCREEN).max(1);

        // Pixel on the primary display (desktop space, origin = top-left of primary).
        let target_x = x_norm * (screen_w - 1) as f32;
        let target_y = y_norm * (screen_h - 1) as f32;

        // Virtual screen may span multiple monitors; primary display sits at desktop (0,0).
        let virt_left = GetSystemMetrics(SM_XVIRTUALSCREEN);
        let virt_top = GetSystemMetrics(SM_YVIRTUALSCREEN);
        let virt_w = GetSystemMetrics(SM_CXVIRTUALSCREEN).max(1);
        let virt_h = GetSystemMetrics(SM_CYVIRTUALSCREEN).max(1);

        let absolute_x = (((target_x - virt_left as f32) * 65535.0)
            / (virt_w - 1).max(1) as f32)
            .round() as i32;
        let absolute_y = (((target_y - virt_top as f32) * 65535.0)
            / (virt_h - 1).max(1) as f32)
            .round() as i32;

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