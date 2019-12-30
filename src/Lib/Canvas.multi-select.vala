/*
* Copyright (c) 2019 Alecaddd (http://alecaddd.com)
*
* This file is part of Akira.
*
* Akira is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.

* Akira is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* You should have received a copy of the GNU General Public License
* along with Akira.  If not, see <https://www.gnu.org/licenses/>.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
* Authored by: Alberto Fanjul <albertofanjul@gmail.com>
* Authored by: Giacomo "giacomoalbe" Alberini <giacomoalbe@gmail.com>
*/

public class Akira.Lib.Canvas : Goo.Canvas {
    private const int MIN_SIZE = 1;
    private const int MIN_POS = 10;
    private const double ROTATION_FIXED_STEP = 15.0;

    /**
     * Signal triggered when item was clicked by the user
     */
    public signal void item_clicked (Goo.CanvasItem? item);
    public signal void canvas_moved (double delta_x, double delta_y);
    public signal void canvas_scroll_set_origin (double origin_x, double origin_y);

    /**
     * Signal triggered when item has finished moving by the user,
     * and a change of it's coordenates was made
     */
    public signal void item_moved (Goo.CanvasItem? item);


    public Goo.CanvasItem? selected_item;

    public Goo.CanvasRect select_effect;

    private EditMode _edit_mode;
    public EditMode edit_mode {
        get {
          return _edit_mode;
        }
        set {
          _edit_mode = value;
          set_cursor_by_edit_mode ();
        }
    }

    public InsertType? insert_type { get; set; }

    public void set_cursor_by_edit_mode () {
        switch (_edit_mode) {
            case EditMode.MODE_SELECTION:
                set_cursor ("default");
                break;

            case EditMode.MODE_INSERT:
                set_cursor ("crosshair");
                break;

            case EditMode.MODE_PAN:
                if (holding) {
                    set_cursor ("grabbing");
                } else {
                    set_cursor ("grab");
                }
                break;

            default:
                set_cursor ("default");
                break;
        }
    }

    public weak Akira.Window window { get; construct; }

    /*
        Grabber Pos:   8
                     0 1 2
                     7   3
                     6 5 4

        // -1 if no nub is grabbed
    */
    enum Nob {
        NONE=-1,
        TOP_LEFT,
        TOP_CENTER,
        TOP_RIGHT,
        RIGHT_CENTER,
        BOTTOM_RIGHT,
        BOTTOM_CENTER,
        BOTTOM_LEFT,
        LEFT_CENTER,
        ROTATE
    }

    public enum EditMode {
        MODE_SELECTION,
        MODE_MULTI_SELECT,
        MODE_INSERT,
        MODE_PAN,
    }

    public enum InsertType {
        RECT,
        ELLIPSE,
        TEXT
    }

    public Canvas (Akira.Window window) {
        Object (window: window);
    }

    private Goo.CanvasItemSimple[] nobs = new Goo.CanvasItemSimple[9];

    private Goo.CanvasRect? hover_effect;
    private Goo.CanvasRect? multi_select_effect;

    private HashTable<string, Goo.CanvasItem> canvas_items;
    private List<string> selected_items;

    private int items_global_id;
    private bool ctrl_is_pressed = false;
    private bool shift_is_pressed = false;
    private bool holding;
    private bool temp_event_converted;
    private double temp_event_x;
    private double temp_event_y;
    private double delta_x;
    private double delta_y;
    private double hover_x;
    private double hover_y;
    private double nob_size;
    private double current_scale;
    private int holding_id = Nob.NONE;
    private double bounds_x;
    private double bounds_y;
    private double bounds_w;
    private double bounds_h;

    private double border_size;
    private string border_color;
    private string fill_color;

    construct {
        edit_mode = EditMode.MODE_SELECTION;
        canvas_items = new GLib.HashTable<string, Goo.CanvasItem> (str_hash, str_equal);

        events |= Gdk.EventMask.KEY_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
        events |= Gdk.EventMask.POINTER_MOTION_MASK;

        get_bounds (out bounds_x, out bounds_y, out bounds_w, out bounds_h);

        items_global_id = 0;
    }

    /********************************
     **** CANVAS ITEM INSERTION *****
     *******************************/
    public Goo.CanvasItem? insert_object (Gdk.EventButton event) {
        udpate_default_values ();

        items_global_id++;

        if (insert_type == InsertType.RECT) {
          return add_rect (event);
        } else if (insert_type == InsertType.ELLIPSE) {
          return add_ellipse (event);
        } else if (insert_type == InsertType.TEXT) {
          return add_text (event);
        }

        return null;
    }

    public Goo.CanvasRect add_rect (Gdk.EventButton event) {
        var root = get_root_item ();
        var rect = new Goo.CanvasRect (null, event.x, event.y, 1, 1,
                                       "line-width", border_size,
                                       "radius-x", 0.0,
                                       "radius-y", 0.0,
                                       "stroke-color", border_color,
                                       "fill-color", fill_color, null);

        rect.set_data<string> ("id", @"rect_$items_global_id");
        rect.set_data<bool> ("is_item", true);

        rect.set ("parent", root);
        rect.set_transform (Cairo.Matrix.identity ());

        var artboard = window.main_window.right_sidebar.layers_panel.artboard;
        var layer = new Akira.Layouts.Partials.Layer (window, artboard, rect,
            "Rectangle", "shape-rectangle-symbolic", false);

        rect.set_data<Akira.Layouts.Partials.Layer?> ("layer", layer);

        artboard.container.add (layer);
        artboard.show_all ();
        return rect;
    }

    public Goo.CanvasEllipse add_ellipse (Gdk.EventButton event) {
        var root = get_root_item ();
        var ellipse = new Goo.CanvasEllipse (null, event.x, event.y, 1, 1,
                                             "line-width", border_size,
                                             "stroke-color", border_color,
                                             "fill-color", fill_color);

        ellipse.set_data<string> ("id", @"ellipse_$items_global_id");
        ellipse.set_data<bool> ("is_item", true);

        ellipse.set ("parent", root);
        ellipse.set_transform (Cairo.Matrix.identity ());
        var artboard = window.main_window.right_sidebar.layers_panel.artboard;
        var layer = new Akira.Layouts.Partials.Layer (window, artboard, ellipse,
            "Circle", "shape-circle-symbolic", false);
        ellipse.set_data<Akira.Layouts.Partials.Layer?> ("layer", layer);
        artboard.container.add (layer);
        artboard.show_all ();
        return ellipse;
    }

    public Goo.CanvasText add_text (Gdk.EventButton event) {
        var root = get_root_item ();
        var text = new Goo.CanvasText (null, "Add text here", event.x, event.y, 200,
                                       Goo.CanvasAnchorType.NW, "font", "Open Sans 18");
        text.set ("parent", root);
        text.set ("height", 25f);
        text.set_transform (Cairo.Matrix.identity ());
        var artboard = window.main_window.right_sidebar.layers_panel.artboard;
        var layer = new Akira.Layouts.Partials.Layer (window, artboard, text, "Text", "shape-text-symbolic", false);
        text.set_data<Akira.Layouts.Partials.Layer?> ("layer", layer);
        artboard.container.add (layer);
        artboard.show_all ();
        return text;
    }

    public void udpate_default_values () {
        border_size = settings.set_border ? settings.border_size : 0.0;
        border_color = settings.set_border ? settings.border_color: "";
        fill_color = settings.fill_color;
    }

    public new void focus () {
        grab_focus (get_root_item ());
    }

    /*************************
     **** EVENT HANDLERS *****
     ************************/
    public override bool button_press_event (Gdk.EventButton event) {
        remove_hover_effect ();

        current_scale = get_scale ();
        temp_event_x = event.x / current_scale;
        temp_event_y = event.y / current_scale;
        temp_event_converted = false;

        Goo.CanvasItem clicked_item = null;

        debug ("canvas temp event x: %f", temp_event_x);
        debug ("canvas temp event y: %f", temp_event_y);

        Goo.CanvasItem item_to_add = null;

        switch (edit_mode) {
            case EditMode.MODE_PAN:
                double tmp_event_x_normalized = temp_event_x;
                double tmp_event_y_normalized = temp_event_y;

                convert_to_pixels (ref tmp_event_x_normalized, ref tmp_event_y_normalized);

                canvas_scroll_set_origin (tmp_event_x_normalized, tmp_event_y_normalized);

                holding = true;

                return true;

            case EditMode.MODE_INSERT:
                item_to_add = insert_object (event);

                var item_id = item_to_add.get_data<string>("id");

                canvas_items.insert (item_id, item_to_add);
                this.selected_items.append (item_id);

                add_select_effect ();

                clicked_item = nobs[Nob.BOTTOM_RIGHT];
                break;

            case EditMode.MODE_SELECTION:
                clicked_item = get_item_at (temp_event_x, temp_event_y, true);
                break;

            default:
                break;
        }

        if (clicked_item != null) {
            var clicked_id = get_grabbed_id (clicked_item);
            holding = true;

            if (clicked_id == Nob.NONE) { // Non-nub was clicked
                // If shift is pressed remove JUST the select_effect rect
                // keep selected items list untouched
                remove_select_effect (shift_is_pressed);

                if (clicked_item.get_data<bool> ("is_item")) {
                    selected_items.append (clicked_item.get_data<string> ("id"));
                    add_select_effect ();
                    grab_focus (clicked_item);
                }

                holding_id = Nob.NONE;
            } else { // nob was clicked
                holding_id = clicked_id;
            }
        } else {
            remove_select_effect ();
            focus ();
            add_multi_select_effect (event);
        }

        return true;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        if (edit_mode == EditMode.MODE_MULTI_SELECT) {
            do_multi_select ();
        }

        edit_mode = EditMode.MODE_SELECTION;
        set_cursor_by_edit_mode ();

        if (!holding) return false;

        holding = false;

        if (delta_x == 0 && delta_y == 0) {
            return false;
        }

        item_moved (selected_item);
        add_hover_effect (selected_item);

        delta_x = 0;
        delta_y = 0;

        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        var event_x = event.x / current_scale;
        var event_y = event.y / current_scale;

        if (edit_mode == EditMode.MODE_PAN) {
            if (holding) {
                // Move canvas if holding mouse and spacebar pressed
                move_canvas (event_x, event_y);
            } else {
                // Remove hover effect on selected items if just
                // moving around with spacebar pressed
                remove_hover_effect ();
            }

            return false;
        }

        if (edit_mode == EditMode.MODE_MULTI_SELECT) {
            double x, y, width, height;
            multi_select_effect.get ("x", out x, "y", out y, "width", out width, "height", out height);

            // TODO: get the case in which new_delta are negative
            var new_width = event_x - x;
            var new_height = event_y - y;

            multi_select_effect.set("width", new_width, "height", new_height);

            return false;
        }

        if (!holding) {
            motion_hover_event (event.x, event.y);
            return false;
        }

        if (selected_items.length () == 0) {
            return false;
        }

        Goo.CanvasItem selected_item =
            canvas_items.get (selected_items.nth_data (0));

        debug (@"SelectedItem: $(selected_item.get_data<string>("id"))");

        convert_to_item_space (selected_item, ref event_x, ref event_y);

        //debug ("event x: %f", event_x);
        //debug ("event y: %f", event_y);

        if (!temp_event_converted) {
            convert_to_item_space (selected_item, ref temp_event_x, ref temp_event_y);
            temp_event_converted = true;
        }

        //debug ("temp event x: %f", temp_event_x);
        //debug ("temp event y: %f", temp_event_y);

        delta_x = event_x - temp_event_x;
        delta_y = event_y - temp_event_y;

        //debug ("delta x: %f", delta_x);
        //debug ("delta y: %f", delta_y);

        double x, y, width, height;
        selected_item.get ("x", out x, "y", out y, "width", out width, "height", out height);

        //debug ("x: %f", x);
        //debug ("y: %f", y);

        var new_height = height;
        var new_width = width;

        var new_delta_x = delta_x;
        var new_delta_y = delta_y;

        var canvas_x = x;
        var canvas_y = y;

        convert_from_item_space (selected_item, ref canvas_x, ref canvas_y);

        //debug ("new delta x: %f", new_delta_x);
        //debug ("new delta y: %f", new_delta_y);

        //debug ("height: %f", height);
        //debug ("width: %f", width);

        bool update_x = new_delta_x != 0;
        bool update_y = new_delta_y != 0;

        //debug ("update x: %s", update_x.to_string ());
        //debug ("update y: %s", update_y.to_string ());

        switch (holding_id) {
            case Nob.NONE: // Moving
                double move_x = fix_x_position (canvas_x, width, delta_x);
                double move_y = fix_y_position (canvas_y, height, delta_y);

                debug ("move x %f", move_x);
                debug ("move y %f", move_y);

                selected_item.translate (move_x, move_y);

                event_x -= move_x;
                event_y -= move_y;

                break;
            case Nob.TOP_LEFT:
                update_x = event_x < x + width;
                update_y = event_y < y + height;
                if (MIN_SIZE > height - new_delta_y) {
                    new_delta_y = 0;
                }
                if (MIN_SIZE > width - new_delta_x) {
                    new_delta_x = 0;
                }
                selected_item.translate (new_delta_x, new_delta_y);
                event_x -= new_delta_x;
                event_y -= new_delta_y;
                new_width = fix_size (width - new_delta_x);
                new_height = fix_size (height - new_delta_y);
                break;
            case Nob.TOP_CENTER:
                update_y = event_y < y + height;
                if (MIN_SIZE > height - new_delta_y) {
                    new_delta_y = 0;
                }
                new_height = fix_size (height - new_delta_y);
                selected_item.translate (0, new_delta_y);
                event_y -= new_delta_y;
                break;
            case Nob.TOP_RIGHT:
                update_x = event_x > x;
                if (!update_x) {
                    new_delta_x = 0;
                }
                update_y = event_y < y + height;
                new_width = fix_size (width + new_delta_x);
                if (!update_y) {
                    new_delta_y = 0;
                }
                if (new_delta_y < height) {
                    selected_item.translate (0, new_delta_y);
                    debug ("translate: %f,%f", 0, new_delta_y);
                    event_y -= new_delta_y;
                    new_height = fix_size (height - new_delta_y);
                }
                break;
            case Nob.RIGHT_CENTER:
                update_x = event_x > x;
                if (!update_x) {
                    new_delta_x = 0;
                }
                new_width = fix_size (width + new_delta_x);
                break;
            case Nob.BOTTOM_RIGHT:
                update_x = event_x > x;
                update_y = event_y > y;
                new_width = fix_size (width + new_delta_x);
                new_height = fix_size (height + new_delta_y);
                break;
            case Nob.BOTTOM_CENTER:
                update_y = event_y > y;
                if (!update_y) {
                    new_delta_y = 0;
                }
                new_height = fix_size (height + new_delta_y);
                break;
            case Nob.BOTTOM_LEFT:
                if (new_delta_x > width) {
                    new_delta_x = 0;
                }
                update_y = event_y > y;
                update_x = event_x < x + width;
                if (!update_x) {
                    new_delta_x = 0;
                }
                if (new_delta_y == 0) {
                    if (delta_y > 0 && update_y) {
                        new_delta_y = delta_y;
                    } else {
                        break;
                    }
                }
                debug ("translate: %f,%f", new_delta_x, 0);
                selected_item.translate (new_delta_x, 0);
                event_x -= new_delta_x;
                new_width = fix_size (width - new_delta_x);
                new_height = fix_size (height + new_delta_y);
                break;
            case Nob.LEFT_CENTER:
                update_x = event_x < x + width;
                if (new_delta_x < width) {
                    selected_item.translate (new_delta_x, 0);
                    event_x -= new_delta_x;
                    new_width = fix_size (width - new_delta_x);
                }
                break;
            case Nob.ROTATE:
                var center_x = x + width / 2;
                var center_y = y + height / 2;
                var do_rotation = true;

                //debug ("center x: %f", center_x);
                //debug ("center y: %f", center_y);

                var start_radians = GLib.Math.atan2 (center_y - temp_event_y, temp_event_x - center_x);
                var radians = GLib.Math.atan2 (center_y - event_y, event_x - center_x);

                //debug ("start_radians %f, atan2(%f - %f, %f - %f)", start_radians, center_y, temp_event_y, temp_event_x, center_x);
                //debug ("radians %f, atan2(%f - %f, %f - %f)", radians, center_y , event_y, event_x, center_x);

                radians = start_radians - radians;

                double current_x, current_y, current_scale, current_rotation;
                selected_item.get_simple_transform (out current_x, out current_y, out current_scale, out current_rotation);

                var rotation = radians * (180 / Math.PI);

                if (ctrl_is_pressed) {
                    do_rotation = false;

                    // Don't update temp_event_x and temp_event_y
                    // before reaching the ROTATION_FIXED_STEP threshold
                    update_x = false;
                    update_y = false;

                    if (rotation.abs () > ROTATION_FIXED_STEP) {
                        do_rotation = true;

                        // The rotation amount needs to take into consideration
                        // the current rotation in order to anchor the item to truly
                        // "fixed" rotation step instead of simply adding ROTATION_FIXED_STEP
                        // to the current rotation, which might lead to a situation in which you
                        // cannot "reset" item rotation to rounded values (0, 90, 180, ...) without
                        // manually resetting the rotation input field in the properties panel
                        var current_rotation_int = ((int) GLib.Math.round (current_rotation));

                        var rotation_amount = ROTATION_FIXED_STEP;

                        // Strange glitch: when current_rotation == 30.0, the fmod
                        // function does not work properly.
                        // 30.00000 % 15.00000 != 0 => rotation_amount becomes 0.
                        // That's why here is used the int representation of current_rotation
                        if (current_rotation_int % ROTATION_FIXED_STEP != 0) {
                            rotation_amount -= GLib.Math.fmod (current_rotation, ROTATION_FIXED_STEP);
                        }

                        rotation = rotation > 0 ? rotation_amount : -rotation_amount;

                        //debug ("Current rotation: %f", current_rotation);
                        //debug ("Current rotation int: %f", current_rotation_int);
                        //debug ("Actual rotation: %f", rotation);

                        update_x = true;
                        update_y = true;
                    }
                }

                if (do_rotation) {
                    convert_from_item_space (selected_item, ref event_x, ref event_y);
                    selected_item.rotate (rotation, center_x, center_y);
                    convert_to_item_space (selected_item, ref event_x, ref event_y);
                }

                break;
            default:
                break;
        }

        //debug ("new width: %f", new_width);
        //debug ("new height: %f", new_height);

        //debug ("update x: %s", update_x.to_string ());
        //debug ("update y: %s", update_y.to_string ());

        selected_item.set ("width", new_width, "height", new_height);

        update_nob_position (selected_item);
        update_select_effect (selected_item);

        if (update_x) {
            temp_event_x = event_x;
            //debug ("temp event x: %f", temp_event_x);
        }
        if (update_y) {
            temp_event_y = event_y;
            //debug ("temp event y: %f", temp_event_y);
        }

        //debug ("");

        return true;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        switch (Gdk.keyval_to_upper (event.keyval)) {
            case Gdk.Key.E:
                edit_mode = Akira.Lib.Canvas.EditMode.MODE_INSERT;
                insert_type = Akira.Lib.Canvas.InsertType.ELLIPSE;
                return true;
            case Gdk.Key.R:
                edit_mode = Akira.Lib.Canvas.EditMode.MODE_INSERT;
                insert_type = Akira.Lib.Canvas.InsertType.RECT;
                return true;
            case Gdk.Key.T:
                edit_mode = Akira.Lib.Canvas.EditMode.MODE_INSERT;
                insert_type = Akira.Lib.Canvas.InsertType.TEXT;
                return true;
            case Gdk.Key.Escape:
                edit_mode = Akira.Lib.Canvas.EditMode.MODE_SELECTION;
                insert_type = null;
                return true;
            case Gdk.Key.Delete:
                delete_selected ();
                return true;
            case Gdk.Key.space:
                edit_mode = EditMode.MODE_PAN;
                remove_hover_effect ();
                return true;
            case Gdk.Key.Control_L:
            case Gdk.Key.Control_R:
                ctrl_is_pressed = true;
                return true;
            case Gdk.Key.Shift_L:
            case Gdk.Key.Shift_R:
                shift_is_pressed = true;
                return true;
        }

        return false;
    }

    public override bool key_release_event (Gdk.EventKey event) {
        switch (Gdk.keyval_to_upper (event.keyval)) {
            case Gdk.Key.space:
                edit_mode = EditMode.MODE_SELECTION;
                motion_hover_event (hover_x, hover_y);
                return true;

            case Gdk.Key.Control_L:
            case Gdk.Key.Control_R:
                edit_mode = EditMode.MODE_SELECTION;
                ctrl_is_pressed = false;
                return true;

            case Gdk.Key.Shift_L:
            case Gdk.Key.Shift_R:
                edit_mode = EditMode.MODE_SELECTION;
                shift_is_pressed = false;
                return true;
        }

        return false;
    }

    private void move_canvas (double event_x, double event_y) {
        double event_x_normalized = event_x;
        double event_y_normalized = event_y;

        convert_to_pixels (ref event_x_normalized, ref event_y_normalized);

        canvas_moved (event_x_normalized, event_y_normalized);
        return;
    }

    private void motion_hover_event (double event_x, double event_y) {
        var hovered_item = get_item_at (event_x / get_scale (), event_y / get_scale (), true);

        if (!(hovered_item is Goo.CanvasItemSimple)) {
            remove_hover_effect ();
            return;
        }

        add_hover_effect (hovered_item);

        double check_x;
        double check_y;
        hovered_item.get ("x", out check_x, "y", out check_y);

        if ((hover_x != check_x || hover_y != check_y) && hover_effect != hovered_item) {
            remove_hover_effect ();
        }

        hover_x = check_x;
        hover_y = check_y;
    }

    private void add_multi_select_effect (Gdk.EventButton event) {
        edit_mode = EditMode.MODE_MULTI_SELECT;

        var line_width = 2.0 / get_scale ();

        // TODO: Take stroke_color from settings?
        var stroke_color = Gdk.RGBA ();
        // Corresponds to #41c9fd
        stroke_color.parse("rgba(65, 201, 253, 1)");

        var fill_color = stroke_color.copy ();
        fill_color.alpha = 0.1;

        multi_select_effect = new Goo.CanvasRect (
            null,
            event.x, event.y,
            1, 1,
            "line-width", line_width,
            "stroke-color-gdk-rgba", stroke_color,
            "fill-color-gdk-rgba", fill_color,
            null
        );

        multi_select_effect.set ("parent", get_root_item ());
        multi_select_effect.can_focus = false;
    }

    private void do_multi_select () {
        // Get multi select effect area
        Goo.CanvasBounds select_area;
        multi_select_effect.get_bounds (out select_area);

        // get_items_in_area(bounds, inside_area, allow_overlaps, include_containers)
        var selected_items_object =
            get_items_in_area (select_area, true, false, true);

        foreach (var item in selected_items_object) {
            if (item.get_data<bool> ("is_item")) {
                selected_items.append (item.get_data<string> ("id"));
            }
        }

        add_select_effect ();

        multi_select_effect.remove();
        multi_select_effect = null;
    }

    private void add_select_effect () {
        // Bounding box edges
        double bb_left = 1e6, bb_top = 1e6, bb_right = 0, bb_bottom = 0;
        uint items_number = 0;

        foreach (var item_id in this.selected_items) {
            if (!canvas_items.contains (item_id)) {
                continue;
            }

            var item = canvas_items.get (item_id);

            items_number++;

            Goo.CanvasBounds item_bounds;
            item.get_bounds (out item_bounds);

            bb_left = double.min(bb_left, item_bounds.x1);
            bb_top = double.min(bb_top, item_bounds.y1);
            bb_right = double.max(bb_right, item_bounds.x2);
            bb_bottom = double.max(bb_bottom, item_bounds.y2);
        }

        // No "real" items present, so don't add select_effect
        if (items_number == 0) {
            return;
        }

        var select_bb = Goo.CanvasBounds () {
            x1 = bb_left,
            y1 = bb_top,
            x2 = bb_right,
            y2 = bb_bottom
        };

        add_select_effect_from_bounds (select_bb);
    }

    private void add_select_effect_from_bounds (Goo.CanvasBounds bounds) {
        var line_width = 2.0;

        double width = bounds.x2 - bounds.x1;
        double height = bounds.y2 - bounds.y1;

        select_effect = new Goo.CanvasRect (null,
            bounds.x1, bounds.y1,
            width, height,
            "line-width", line_width,
            "stroke-color", "#666",
        null);

        select_effect.set ("parent", get_root_item ());

        nob_size = 10 / current_scale;

        for (int i = 0; i < 9; i++) {
            var radius = i == 8 ? nob_size : 0;
            nobs[i] = new Goo.CanvasRect (null,
                0, 0,
                nob_size, nob_size,
                "line-width", line_width,
                "radius-x", radius,
                "radius-y", radius,
                "stroke-color", "#41c9fd",
                "fill-color", "#fff",
            null);

            nobs[i].set ("parent", get_root_item ());
        }

        update_nob_position_from_bounds (bounds, 0.0, Cairo.Matrix.identity ());

        select_effect.can_focus = false;
    }

    private void update_select_effect (Goo.CanvasItem? target) {
        if (target == null || target == select_effect) {
            return;
        }

        double width, height;
        target.get ("width", out width, "height", out height);

        var item = (target as Goo.CanvasItemSimple);
        var stroke = item.line_width / 2;
        var real_width = width + stroke * 2;
        var real_height = height + stroke * 2;

        select_effect.set ("width", real_width, "height", real_height);
        var transform = Cairo.Matrix.identity ();
        item.get_transform (out transform);
        select_effect.set_transform (transform);
    }

    private void remove_select_effect (bool only_select_effect = false) {
        if (!only_select_effect) {
            this.selected_items = null;
        }

        if (select_effect == null) {
            return;
        }

        select_effect.remove ();
        select_effect = null;

        for (int i = 0; i < 9; i++) {
            nobs[i].remove ();
        }
    }

    public void reset_select () {
        current_scale = get_scale ();

        if (selected_item == null && select_effect == null) {
            return;
        }

        select_effect.remove ();
        select_effect = null;

        for (int i = 0; i < 9; i++) {
            nobs[i].remove ();
        }

        current_scale = get_scale ();
    }

    private void add_hover_effect (Goo.CanvasItem? target) {
        if (target == null || hover_effect != null || target == selected_item
            || target == select_effect || edit_mode == EditMode.MODE_INSERT) {
            return;
        }

        if ((target as Goo.CanvasItemSimple) in nobs) {
            set_cursor_for_nob (get_grabbed_id (target));
            return;
        }

        double x, y, width, height;
        target.get ("x", out x, "y", out y, "width", out width, "height", out height);

        var item = (target as Goo.CanvasItemSimple);

        var line_width = 2.0 / get_scale ();
        var stroke = item.line_width;
        var real_x = x - stroke;
        var real_y = y - stroke;
        var real_width = width + stroke * 2;
        var real_height = height + stroke * 2;

        hover_effect = new Goo.CanvasRect (null, real_x, real_y, real_width, real_height,
                                           "line-width", line_width,
                                           "stroke-color", "#41c9fd", null);
        var transform = Cairo.Matrix.identity ();
        item.get_transform (out transform);
        hover_effect.set_transform (transform);

        hover_effect.set ("parent", get_root_item ());


        hover_effect.can_focus = false;
    }

    private void remove_hover_effect () {
        set_cursor_by_edit_mode ();

        if (hover_effect == null) {
            return;
        }

        hover_effect.remove ();
        hover_effect = null;
    }

    private int get_grabbed_id (Goo.CanvasItem? target) {
        for (int i = 0; i < 9; i++) {
            if (target == nobs[i]) return i;
        }

        return Nob.NONE;
    }

    private void set_cursor_for_nob (int grabbed_id) {
        switch (grabbed_id) {
            case Nob.NONE:
                set_cursor_by_edit_mode ();
                break;
            case Nob.TOP_LEFT:
            case Nob.BOTTOM_RIGHT:
                set_cursor ("nwse-resize");
                break;
            case Nob.TOP_CENTER:
            case Nob.BOTTOM_CENTER:
                set_cursor ("ns-resize");
                break;
            case Nob.TOP_RIGHT:
            case Nob.BOTTOM_LEFT:
                set_cursor ("nesw-resize");
                break;
            case Nob.RIGHT_CENTER:
            case Nob.LEFT_CENTER:
                set_cursor ("ew-resize");
                break;
            case Nob.ROTATE:
                debug ("Rotate Nob");
                set_cursor ("move");
                break;
        }
    }

    private void update_nob_position (Goo.CanvasItem target) {
        var item = (target as Goo.CanvasItemSimple);

        var stroke = (item.line_width / 2);
        double x, y, width, height;
        target.get ("x", out x, "y", out y, "width", out width, "height", out height);

        var transform = Cairo.Matrix.identity ();
        item.get_transform (out transform);

        var item_bounds = Goo.CanvasBounds () {
            x1 = x,
            y1 = y,
            x2 = x + width,
            y2 = y + height
        };

        update_nob_position_from_bounds (item_bounds, stroke, transform);
    }

    // Updates all the nub's position arround the selected item, except for the grabbed nub
    private void update_nob_position_from_bounds (Goo.CanvasBounds bounds, double stroke, Cairo.Matrix transform) {
        double x = bounds.x1;
        double y = bounds.y1;
        double width = bounds.x2 - bounds.x1;
        double height = bounds.y2 - bounds.y1;

        bool print_middle_width_nobs = width > nob_size * 3;
        bool print_middle_height_nobs = height > nob_size * 3;

        var nob_offset = (nob_size / 2);


        // TOP LEFT nob
        nobs[Nob.TOP_LEFT].set_transform (transform);
        if (print_middle_width_nobs && print_middle_height_nobs) {
          nobs[Nob.TOP_LEFT].translate (x - (nob_offset + stroke), y - (nob_offset + stroke));
        } else {
          nobs[Nob.TOP_LEFT].translate (x - nob_size - stroke, y - nob_size - stroke);
        }

        if (print_middle_width_nobs) {
          // TOP CENTER nob
          nobs[Nob.TOP_CENTER].set_transform (transform);
        if (print_middle_height_nobs) {
          nobs[Nob.TOP_CENTER].translate (x + (width / 2) - nob_offset, y - (nob_offset + stroke));
        } else {
          nobs[Nob.TOP_CENTER].translate (x + (width / 2) - nob_offset, y - (nob_size + stroke));
        }
          nobs[Nob.TOP_CENTER].set ("visibility", Goo.CanvasItemVisibility.VISIBLE);
        } else {
          nobs[Nob.TOP_CENTER].set ("visibility", Goo.CanvasItemVisibility.HIDDEN);
        }

        // TOP RIGHT nob
        nobs[Nob.TOP_RIGHT].set_transform (transform);
        if (print_middle_width_nobs && print_middle_height_nobs) {
          nobs[Nob.TOP_RIGHT].translate (x + width - (nob_offset - stroke), y - (nob_offset + stroke));
        } else {
          nobs[Nob.TOP_RIGHT].translate (x + width + stroke, y - (nob_size + stroke));
        }

        if (print_middle_height_nobs) {
          // RIGHT CENTER nob
          nobs[Nob.RIGHT_CENTER].set_transform (transform);
          if (print_middle_width_nobs) {
            nobs[Nob.RIGHT_CENTER].translate (x + width - (nob_offset - stroke), y + (height / 2) - nob_offset);
          } else {
            nobs[Nob.RIGHT_CENTER].translate (x + width + stroke, y + (height / 2) - nob_offset);
          }
          nobs[Nob.RIGHT_CENTER].set ("visibility", Goo.CanvasItemVisibility.VISIBLE);
        } else {
          nobs[Nob.RIGHT_CENTER].set ("visibility", Goo.CanvasItemVisibility.HIDDEN);
        }

        // BOTTOM RIGHT nob
        nobs[Nob.BOTTOM_RIGHT].set_transform (transform);
        if (print_middle_width_nobs && print_middle_height_nobs) {
          nobs[Nob.BOTTOM_RIGHT].translate (x + width - (nob_offset - stroke), y + height - (nob_offset - stroke));
        } else {
          nobs[Nob.BOTTOM_RIGHT].translate (x + width + stroke, y + height + stroke);
        }


        if (print_middle_width_nobs) {
          // BOTTOM CENTER nob
          nobs[Nob.BOTTOM_CENTER].set_transform (transform);
          if (print_middle_height_nobs) {
            nobs[Nob.BOTTOM_CENTER].translate (x + (width / 2) - nob_offset, y + height - (nob_offset - stroke));
          } else {
            nobs[Nob.BOTTOM_CENTER].translate (x + (width / 2) - nob_offset, y + height + stroke);
          }
          nobs[Nob.BOTTOM_CENTER].set ("visibility", Goo.CanvasItemVisibility.VISIBLE);
        } else {
          nobs[Nob.BOTTOM_CENTER].set ("visibility", Goo.CanvasItemVisibility.HIDDEN);
        }

        // BOTTOM LEFT nob
        nobs[Nob.BOTTOM_LEFT].set_transform (transform);
        if (print_middle_width_nobs && print_middle_height_nobs) {
          nobs[Nob.BOTTOM_LEFT].translate (x - (nob_offset + stroke), y + height - (nob_offset - stroke));
        } else {
          nobs[Nob.BOTTOM_LEFT].translate (x - (nob_size + stroke), y + height + stroke);
        }

        if (print_middle_height_nobs) {
          // LEFT CENTER nob
          nobs[Nob.LEFT_CENTER].set_transform (transform);
          if (print_middle_width_nobs) {
            nobs[Nob.LEFT_CENTER].translate (x - (nob_offset + stroke), y + (height / 2) - nob_offset);
          } else {
            nobs[Nob.LEFT_CENTER].translate (x - (nob_size + stroke), y + (height / 2) - nob_offset);
          }
          nobs[Nob.LEFT_CENTER].set ("visibility", Goo.CanvasItemVisibility.VISIBLE);
        } else {
          nobs[Nob.LEFT_CENTER].set ("visibility", Goo.CanvasItemVisibility.HIDDEN);
        }

        // ROTATE nob
        double distance = 40;
        if (current_scale < 1) {
            distance = 40 * (2 * current_scale - 1);
        }

        nobs[Nob.ROTATE].set_transform (transform);
        nobs[Nob.ROTATE].translate (x + (width / 2) - nob_offset, y - nob_offset - distance);
    }

    private void set_cursor (string cursor_name) {
        var cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), cursor_name);

        var window = get_window ();

        if (window != null) {
            window.set_cursor (cursor);
        }
    }

    private double fix_y_position (double y, double height, double delta_y) {
        var min_delta = Math.round ((MIN_POS - height));
        var max_delta = Math.round ((bounds_h - MIN_POS));

        debug ("min delta y %f", min_delta);
        debug ("max delta y %f", max_delta);

        var new_y = Math.round (y + delta_y);
        if (new_y < min_delta) {
            return 0;
        } else if (new_y > max_delta) {
            return 0;
        } else {
            return delta_y;
        }
    }

    private double fix_x_position (double x, double width, double delta_x) {
        var min_delta = Math.round ((MIN_POS - width));
        var max_delta = Math.round ((bounds_w - MIN_POS));

        debug ("min delta x %f", min_delta);
        debug ("max delta x %f", max_delta);

        var new_x = Math.round (x + delta_x);

        if (new_x < min_delta) {
            return 0;
        } else if (new_x > max_delta) {
            return 0;
        } else {
            return delta_x;
        }
    }

    private double fix_size (double size) {
        var new_size = Math.round (size);
        return new_size > MIN_SIZE ? new_size : MIN_SIZE;
    }

    public void delete_selected () {
        if (selected_item != null) {
            selected_item.remove ();
            var artboard = window.main_window.right_sidebar.layers_panel.artboard;
            Akira.Layouts.Partials.Layer layer = selected_item.get_data<Akira.Layouts.Partials.Layer?> ("layer");
            if (layer != null) {
                artboard.container.remove (layer);
            }
            remove_select_effect ();
            remove_hover_effect ();
        }
    }
}