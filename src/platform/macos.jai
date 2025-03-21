PLATFORM_CONFIG_SECTION :: "[[macos]]";
PLATFORM_SUBSECTION_ENUM :: enum {}
PLATFORM_SUBSECTION_NAMES :: string.[];
platform_config :: struct {}

platform_parse_config_line :: (config: *platform_config, section: PLATFORM_SUBSECTION_ENUM, line: string) -> success: bool, error_msg: string {
    return true, "";
}

platform_apply_config :: (config: *platform_config) {
}

platform_setup :: inline () {
}

platform_get_centered_window_dimensions :: (open_on_biggest: bool) -> s32, s32, s32, s32 {
    // On macOS, we do not need to set x & y from open_on_biggest.
    // By default, macOS already positions the window within the monitor in which
    // the user performed the action to launch it. This makes sense when we are
    // not maximizing the window on launch anyway. (See platform_maximize_window)

    return -1, -1, 1920, 1080;
}

platform_create_window :: inline () {
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y);
}

platform_maximize_window :: inline (window: Window_Type) {
    // On macOS, we do not do this.
    // Maximized (fullscreen) text editor windows on launch would feel jarring
    // and out of place. It also comes with a cumbersome fullscreening animation.
}

platform_enable_drag_and_drop :: inline (window: Window_Type) {

}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return xx NSView.convertPointToBacking(NSWindow.contentView(window), .{1, 0}).x;
}

platform_set_window_title :: (title: string) {
    NSWindow.setTitle(window, title);
}

platform_wait_message :: inline () {

}

platform_set_refresh_timer :: (window: Window_Type) {

}

platform_kill_refresh_timer :: (window: Window_Type) {

}

platform_enumerate_logical_drives :: inline () -> [] string {
    return .["/"];
}

platform_get_save_file_name :: inline (name := "") -> string, bool {
    return "", false;
}

platform_get_fonts_dir :: inline () -> string {
    return "/Library/Fonts";
}

platform_open_in_explorer :: inline (dir: string) {
    run_command("open", dir);
}

#scope_file

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

#import "Objective_C";
#import "Objective_C/AppKit";
#import "Process";
