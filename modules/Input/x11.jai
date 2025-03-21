#import "X11";
#import "String";  // @Cleanup: Remove this dependency on String?

set_custom_cursor_handling :: (is_custom: bool) {
    // @Incomplete: Implement this.
    // Use this if you are doing immediate-mode API stuff that sets cursors and want to prevent cursors from flickering. Windows is annoying to interface with.
}

get_key_code :: (key: KeySym) -> Key_Code {
    using Key_Code;

    if key == 32 return SPACEBAR;
    
    if key == XK_Left
        return ARROW_LEFT;
    if key == XK_Right
        return ARROW_RIGHT;
    if key == XK_Up
        return ARROW_UP;
    if key == XK_Down
        return ARROW_DOWN;
    if (key == XK_Shift_L) || (key == XK_Shift_R)
        return SHIFT;
    if key == XK_Escape
        return ESCAPE;
    if key == XK_Return
        return ENTER;
    if (key == XK_Control_L) || (key == XK_Control_R)
        return CTRL;
    if key == XK_BackSpace
        return BACKSPACE;
    if key == XK_Delete
        return DELETE;
    if key == XK_Tab
        return TAB;
    if key == XK_F1
        return F1;
    if key == XK_F2
        return F2;
    if key == XK_F3
        return F3;
    if key == XK_F4
        return F4;
    if key == XK_F5
        return F5;
    if key == XK_F6
        return F6;
    if key == XK_F7
        return F7;
    if key == XK_F8
        return F8;
    if key == XK_F9
        return F9;
    if key == XK_F10
        return F10;
    if key == XK_F11
        return F11;
    if key == XK_F12
        return F12;
    if key == XK_F13
        return F13;
    if key == XK_F14
        return F14;
    if key == XK_F15
        return F15;
    if key == XK_F16
        return F16;

    key = key & 0xFF;
    if (key >= #char "a") && (key <= #char "z") return cast(Key_Code) (key - 0x20);

    return UNKNOWN;
}


#scope_file

// Xdnd support by Jens Frederich. Send questions his way. Licensed under the MIT license; see copyright at the end of the file.

get_position_root_x :: inline (xevent: *XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] >> 16;
}

get_position_root_y :: inline (xevent: *XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] & 0xffff;
}

apply_position :: (dnd: *Xdnd_Context, widget: Window, from: Window, action: Atom, x: s32, y: s32, time: Time, typelist: [] Atom, want_position: *bool, supported_action_return: *Atom, desired_type: *Atom, rectangle: *XRectangle) -> bool {
    supported_type: Atom;
    supported_action: Atom;

    dropper_typelist  := drop_info.user_typelist;
    supported_actions := drop_info.user_actions;

    if dropper_typelist.count > 0 {
        // find a correlation:
        for j: dropper_typelist {
            for i: typelist {
                if i == j {
                    supported_type = i;
                    break;
                }
            }
        }
    } else {
        // user did not specify, so return first type
        supported_type = typelist[0];
    }

    // not supported, so return false
    if !supported_type  return false;

    if supported_actions.count > 0 {
        for supported_actions {
            if action == it {
                supported_action = action;
                break;
            }
        }
    } else {
        // user did not specify
        if action == XdndActionCopy  supported_action = action;
    }

    if !supported_action  return false;

    <<want_position = true;
    rectangle.x = 0;
    rectangle.y = 0;
    rectangle.width = 0;
    rectangle.height = 0;

    drop_info.return_action = supported_action;
    <<supported_action_return = supported_action;
    drop_info.return_type = supported_type;
    <<desired_type = supported_type;
    drop_info.x = x;
    drop_info.y = y;

    return true;
}

send_finished :: (display: *Display, window: Window, from: Window) {
    xevent: XEvent;
    xevent.xany.type = ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = XdndFinished;
    xevent.xclient.format = 32;

    // target window
    xevent.xclient.data.l[0] = cast(s64) from;

    XSendEvent(display, window, 0, 0, *xevent);
}

send_status :: (display: *Display, window: Window, from: Window, will_accept: bool, want_position: bool, x: int, y: int, w: int, h: int, action: Atom) {
    xevent: XEvent;
    xevent.xany.type = ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = XdndStatus;
    xevent.xclient.format = 32;

    // Our window
    xevent.xclient.data.l[0] = cast(s64) from;

    // will accept yes no
    xevent.xclient.data.l[1] = (xevent.xclient.data.l[1] & ~0x1) | ifx will_accept then 1 else 0;

    // want position?
    if will_accept  xevent.xclient.data.l[1] = (xevent.xclient.data.l[1] & ~0x2) | ifx want_position then 2 else 0;

    if want_position {
        xevent.xclient.data.l[2] = (x << 16) | (y & 0xffff);
        xevent.xclient.data.l[3] = (w << 16) | (h & 0xffff);
    }

    if will_accept  xevent.xclient.data.l[4] = cast(s64) action;

    XSendEvent(display, window, 0, 0, *xevent);
}

paste_property :: (display: *Display, from: Window, insert: Window, prop: u64, delete_prop: s64) -> bool {
    nread: s64;
    data_count: s64;
    bytes_after: s64;
    error: bool;

    array_reset(*drop_info.data);
    while true {
        actual_type: Atom;
        actual_fmt: s32;
        data: *u8;

        x := nread / 4;

        if XGetWindowProperty(display, insert, prop, xx x , 65536, xx delete_prop, AnyPropertyType, *actual_type, *actual_fmt, xx *data_count, xx *bytes_after, *data) != Success {
            XFree(data);
            return false;
        }

        nread += data_count;

        if (drop_info.data.count == 0) {
            array_reserve(*drop_info.data, data_count + bytes_after);
        }
        memcpy(drop_info.data.data + drop_info.data.count, data, data_count);
        drop_info.data.count += data_count;

        XFree(data);

        if bytes_after == 0  break;
    }

    if !nread  return false;

    return true;
}

get_selection :: (display: *Display, from: Window, prop: Atom, insert: Window) -> bool {
    if prop == None  return false;

    actual_type: Atom;
    actual_fmt: s32;
    nitems: u64;
    bytes_after: u64;
    s: *u8;
    if (XGetWindowProperty(display, insert, prop, 0, 8, False, AnyPropertyType, *actual_type, *actual_fmt, *nitems, *bytes_after, *s) != Success) {
        XFree(s);
        return false;
    }

    XFree(s);
    if actual_type != XInternAtom(display, "INCR", False) {
        return paste_property(display, from, insert, prop, True);
    }

    XDeleteProperty(display, insert, prop);

    /* @Cleanup: Get rid of fd_set stuff.
    time_start := get_time();
    while true {
        r: fd_set;
        xe: XEvent;
        if XCheckMaskEvent(display, PropertyChangeMask, *xe) {
            if xe.type == PropertyNotify && xe.xproperty.state == PropertyNewValue {
                // time between arrivals of data
                time_start = get_time();
                if paste_property(display, from, insert, prop, True)  break;
            }
        } else {
            FD_ZERO(*r);
            FD_SET(ConnectionNumber(display), *r);
            select(ConnectionNumber(display) + 1, *r, 0, 0, *tv);

            if FD_ISSET(ConnectionNumber(display), *r)  continue;
        }
        end := get_time();

        // no data for five seconds, so quit
        if end - start > 5000000  return false;
    }
    */
    return true;
}

maybe_handle_xdnd_drop_events :: (display: *Display, xevent: *XEvent, drop_info: *Drop_Info) -> bool {
    assert(xevent.type == ClientMessage);
    assert(xevent.xclient.message_type == XdndEnter);

    dnd := x_global_xdnd_context;
    dnd.root_window = DefaultRootWindow(display);

    while true {
        if xevent.type == ClientMessage {
            if xevent.xclient.message_type == XdndEnter {
                version := xevent.xclient.data.l[1] >> 24;
                if version < 3  return false;

                xdnd_context_reset(*dnd);
                dnd.dragger_window = cast(Window) xevent.xclient.data.l[0];
                dnd.dropper_toplevel = xevent.xany.window;
                dnd.dropper_window = 0;  // Enter goes to the top level window only, so we don't really know what the sub window is yet.

                support_more_than_three_types := xevent.xclient.data.l[1] & 0x1;
                if !support_more_than_three_types {
                    for 0..2 {
                        atom := cast(Atom) xevent.xclient.data.l[2 + it];
                        array_add(*dnd.dragger_typelist, atom);
                    }
                } else {
                    array_reset(*dnd.dragger_typelist);

                    type: Atom;
                    format: s32;
                    count, remaining: u64;
                    data: *u8 = null;
                    XGetWindowProperty(display, dnd.dragger_window, XdndTypeList, 0, 0x8000000, False, XA_ATOM, *type, *format, *count, *remaining, *data);

                    if type != XA_ATOM || format != 32 || count == 0 || data == null {
                        print("XGetWindowProperty failed in get type list\n");
                    }

                    atom_data: *Atom = cast(*Atom)data;
                    for 0..count {
                        array_add(*dnd.dragger_typelist, atom_data[it]);
                    }

                    XFree(data);
                }

                if dnd.dragger_typelist {
                    dnd.stage = Xdnd_Stage.DROP_ENTERED;
                } else {
                    print("      typelist returned as zero!\n");
                }
            } else if xevent.xclient.message_type == XdndLeave {
                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    dnd.stage = Xdnd_Stage.DROP_IDLE;
                    array_reset(*dnd.dragger_typelist);
                    dnd.dropper_toplevel = 0;
                    dnd.dropper_window = 0;
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == XdndPosition {
                action: Atom;
                rectangle: XRectangle;
                want_position: bool;
                last_window: Window;

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    last_window = dnd.dropper_window;

                    if xevent.xany.window != dnd.dropper_toplevel || !dnd.dropper_window {
                        dnd.dropper_toplevel = xevent.xany.window;
                        parent := dnd.root_window;
                        child := dnd.dropper_toplevel;
                        root_x := get_position_root_x(xevent);
                        root_y := get_position_root_y(xevent);

                        while true {
                            xd: s32;
                            yd: s32;
                            new_child: Window;
                            if !XTranslateCoordinates(display, parent, child, root_x, root_y, *xd, *yd, *new_child)  break;
                            if !new_child  break;

                            child = new_child;
                        }

                        dnd.dropper_window = child;
                        xevent.xany.window = child;
                    } else if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                        xevent.xany.window = dnd.dropper_window;
                    }

                    action := XdndActionCopy;
                    dnd.supported_action = XdndActionCopy;
                    dnd.x = get_position_root_x(xevent);
                    dnd.y = get_position_root_y(xevent);
                    dnd.time = CurrentTime;

                    dnd.will_accept = apply_position(*dnd, xevent.xany.window, dnd.dragger_window, action, dnd.x, dnd.y, dnd.time, dnd.dragger_typelist, *want_position, *dnd.supported_action, *dnd.desired_type, *rectangle);
                    send_status(display, dnd.dragger_window, dnd.dropper_toplevel, dnd.will_accept, want_position, rectangle.x, rectangle.y, rectangle.width, rectangle.height, dnd.supported_action);
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == XdndDrop {
                if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                    xevent.xany.window = dnd.dropper_window;
                }

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    dnd.time = CurrentTime;
                    if dnd.will_accept {
                        // convert selection
                        {
                            dnd.dragger_window = XGetSelectionOwner(display, XdndSelection);
                            if !dnd.dragger_window {
                                print(" XGetSelectionOwner failed\n");
                            } else {
                                XConvertSelection(display, XdndSelection, dnd.desired_type, x_global_non_protocol_atom, dnd.dropper_window, CurrentTime);
                            }
                        }

                        dnd.stage = Xdnd_Stage.DROP_CONVERTING;
                    } else {
                        print("    will_accept is false - sending finished\n");
                        send_finished(display, dnd.dragger_window, dnd.dropper_toplevel);

                        array_reset(*dnd.dragger_typelist);
                        xdnd_context_reset(*dnd);
                        dnd.stage = Xdnd_Stage.DROP_IDLE;
                    }
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            }
        } else if xevent.type == SelectionNotify {
            if xevent.xselection.property == x_global_non_protocol_atom && dnd.stage == Xdnd_Stage.DROP_CONVERTING {
                error := get_selection(display, dnd.dragger_window, xevent.xselection.property, xevent.xany.window);
                // Error is not actually used, I think future versions of the protocol maybe should return an error status to the calling window with the XdndFinished client message.

                send_finished(display, dnd.dragger_window, dnd.dropper_toplevel);

                array_reset(*dnd.dragger_typelist);
                xdnd_context_reset(*dnd);
                dnd.stage = Xdnd_Stage.DROP_IDLE;
            } else {
                print("  property is not Xdnd_NON_PROTOCOL_ATOM - ignoring\n");
            }
        }

        if dnd.stage == Xdnd_Stage.DROP_IDLE  break;

        XNextEvent(x_global_display, xevent);
    }

    if drop_info.data.count > 0 {
        files: [..] string;

        p := "";
        p.data = drop_info.data.data;
        p.count = drop_info.data.count;
        while true {
            i := find_index_from_left(p, "\r\n");
            if i == -1  break;

            file_name := "";
            // Heap allocated like on Windows.
            file_name_bytes := cast(*u8) alloc(i, __temporary_allocator);
            memcpy(file_name_bytes, p.data, i);
            p.data = p.data + i + 2;
            p.count = p.count - i - 2;

            file_name.data = file_name_bytes;
            file_name.count = i;
            array_add(*files, file_name);
        }


        event: Event;
        event.type = .DRAG_AND_DROP_FILES;
        event.files = files;
        array_add(*events_this_frame, event);

        array_reset(*drop_info.data);
        return true;
    }

    return false;
}


update_x11_window_events :: () {
    using Key_Code;

    input_per_frame_event_and_flag_update();

    display := x_global_display;
    XLockDisplay(display);
    
    while XPending(display) {
        xev: XEvent;
        XNextEvent(display, *xev);

        if xev.type == {

          case ClientMessage;
            message_type := xev.xclient.message_type;
            if message_type == XdndEnter {
                drop_handled := maybe_handle_xdnd_drop_events(display, *xev, *drop_info);
		if drop_handled  continue;
            } else if message_type == x_global_wm_protocols {
                message0 := cast(Atom) xev.xclient.data.l[0];

                // This can't be a switch, because the values are not constant!
                // Except come on guys, every single implementation of X11 in the universe
                // is going to agree on these values. Why are we pretending they are not constant?
                // How about if we just look them up once and then hardcode them into this program?
                // We'd save startup time...

                if message0 == x_global_wm_delete_window {
                    event: Event;
                    event.type = .QUIT;
                    array_add(*events_this_frame, event);
                }
            }
        case KeyPress;
            event: Event;

            shift: u32;
            if xev.xkey.state & ShiftMask
                shift = 1;
            if xev.xkey.state & ControlMask
                event.ctrl_pressed = true;
            if xev.xkey.state & Mod1Mask
                event.alt_pressed = true;

            keysym := XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, 0 /* English lowercase group*/);
            event.type = .KEYBOARD;
            event.key_pressed = 1;
            event.key_code = get_key_code(keysym);
            event.shift_pressed = cast(bool) shift;

            input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);
            
            array_add(*events_this_frame, event);

            keysym = XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, shift);
            if (keysym < XK_BackSpace || keysym > XK_Hyper_R) && !event.ctrl_pressed {
                //WM_CHAR equivalent
                char_event: Event;
                char_event.type = .TEXT_INPUT;
                char_event.utf32 = xx keysym; // luckily most Xkb keys are directly mapped to Unicode characters @FixME which keys dont map to utf32 ??

                array_add(*events_this_frame, char_event);
            }
        case KeyRelease;
            // For some odd reason X11 generates KeyRelease followed by a near identical KeyPress to simulate repeat events so we have to filter that out
            if XEventsQueued(display, QueuedAfterReading) {
                nev: XEvent;
                XPeekEvent(display, *nev);

                if nev.type == KeyPress
                    && nev.xkey.time == xev.xkey.time
                    && nev.xkey.keycode == xev.xkey.keycode {

                    // This is a repeat, so we ignore the KeyRelease.
                    continue;
                }
            }

            event: Event;

            shift: u32;
            if xev.xkey.state & ShiftMask
                shift = 1;
            if xev.xkey.state & ControlMask
                event.ctrl_pressed = true;
            if xev.xkey.state & Mod1Mask
                event.alt_pressed = true;

            keysym := XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, 0 /* English lowercase group*/);
            event.type = .KEYBOARD;
            event.key_pressed = 0;
            event.shift_pressed = cast(bool) shift;
            event.key_code = get_key_code(keysym);

            input_button_states[event.key_code] = Key_Current_State.END;
            
            array_add(*events_this_frame, event);
        case ButtonPress;
            event: Event;
            event.type = .KEYBOARD;

            event.key_pressed = 1;
            button := xev.xbutton.button;
            if button == Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);

            array_add(*events_this_frame, event);
        case ButtonRelease;
            // it seems that mouse input doesnt generate repeat events so we dont have to peek the queue
            event: Event;
            event.type = .KEYBOARD;

            event.key_pressed = 0;
            button := xev.xbutton.button;
            if button == Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            input_button_states[event.key_code] = Key_Current_State.END;

            array_add(*events_this_frame, event);
        case SelectionRequest;
            selreq := cast(*XSelectionRequestEvent) *xev;

            out: XEvent;
            selnot := cast(*XSelectionEvent) *out;
            selnot.type = SelectionNotify;
            selnot.requestor = selreq.requestor;
            selnot.selection = selreq.selection;
            selnot.target = selreq.target;
            selnot.time = selreq.time;
            selnot.property = None;

            if x_window_is_ours(x_global_display, selreq.owner) {
                if selreq.target == x_global_xa_utf8 {
                    selnot.property = selreq.property;

                    text_data := x_global_clipboard_buffer.text_data;
                    XChangeProperty(selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
                                    text_data.data, cast(s32) text_data.count);
                } else if selreq.target == x_global_xa_targets {

                    selnot.property = selreq.property;

                    atoms: [..] Atom;
                    array_add(*atoms, x_global_xa_utf8);
                    array_add(*atoms, x_global_xa_targets);
                    array_add(*atoms, x_global_xa_multiple);
                    if x_global_clipboard_buffer.rgb_data {
                        array_add(*atoms, x_global_image_bmp);
                    }
                    XChangeProperty(selreq.display, selreq.requestor, selreq.property, x_global_xa_atom, 32, PropModeReplace,
                                    xx atoms.data, cast(s32) atoms.count);

                    array_reset(*atoms);
                } else if selreq.target == x_global_image_bmp {
                    #import "stb_image_write";

                    Data :: struct {
                        _context: *Context;
                        data: [..] u8;
                    }

                    write_func :: (_context: *void, _data: *void, size: s32) #c_call {
                        data := cast(*Data) _context;
                        push_context <<data._context {
                            data8 := cast(*u8) _data;
                            for 0..size-1 {
                                array_add(*data.data, data8[it]);
                            }
                        }
                    }

                    data: Data;
                    data._context = *context;
                    w := x_global_clipboard_buffer.width;
                    h := x_global_clipboard_buffer.height;
                    comp: s32 = 3;
                    stride := x_global_clipboard_buffer.pitch;
                    stbi_write_bmp_to_func(write_func, *data, w, h, comp, x_global_clipboard_buffer.rgb_data);

                    selnot.property = selreq.property;
                    XChangeProperty(selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
                                    xx data.data.data, cast(s32) data.data.count);

                    array_reset(*data.data);
                } else {
                    // print("GOT REQ: %\n", to_string(XGetAtomName(x_global_display, selreq.target)));
                }
            }

            XSendEvent(selreq.display, selreq.requestor, True, 0, *out);
        case ConfigureNotify;
            config := cast(*XConfigureEvent) *xev;
            add_resize_record(config.window, config.width, config.height);
        case FocusIn;
            input_application_has_focus = true;
        case FocusOut;
            input_application_has_focus = false;
        }
    }
    XUnlockDisplay(display);
}
#scope_export

update_window_events :: () {
    update_x11_window_events();
}

// @Cutnpaste from Input/windows.jai
add_resize_record :: (hwnd: Window, width: s32, height: s32) {
    record: *Window_Resize_Record;
    for * pending_resizes {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_resizes);
    }

    record.window = hwnd;
    record.width = width;
    record.height = height;
}

#scope_file

/*

Copyright 2021, Thekla, Inc (portions of this code, dealing with Xdnd, are copyright Jens Frederich).

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


*/    
