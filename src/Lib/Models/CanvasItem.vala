/*
* Copyright (c) 2019-202 Alecaddd (https://alecaddd.com)
*
* This file is part of Akira.
*
* Akira is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.

* Akira is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.

* You should have received a copy of the GNU General Public License
* along with Akira. If not, see <https://www.gnu.org/licenses/>.
*
* Authored by: Giacomo Alberini <giacomoalbe@gmail.com>
* Authored by: Alessandro "Alecaddd" Castellani <castellani.ale@gmail.com>
*/

public enum Akira.Lib.Models.CanvasItemType {
    RECT,
    ELLIPSE,
    TEXT,
    IMAGE
}

public interface Akira.Lib.Models.CanvasItem : Goo.CanvasItemSimple, Goo.CanvasItem {
    public abstract string layer_icon { get; set; }

    public static int global_id = 0;

    public abstract string id { get; set; }
    public abstract string name { get; set; }

    public abstract bool selected { get; set; }
    public abstract bool locked { get; set; default = false; }
    public abstract int z_index { get; set; }

    // Transform Panel attributes.
    public abstract double opacity { get; set; }
    public abstract double rotation { get; set; }

    // Fill Panel attributes.
    // If FALSE, don't add a FillItem to the ListModel
    public abstract bool has_fill { get; set; default = true; }
    public abstract int fill_alpha { get; set; }
    public abstract Gdk.RGBA color { get; set; }
    public abstract bool hidden_fill { get; set; default = false; }

    // Border Panel attributes.
    // If FALSE, don't add a BorderItem to the ListModel
    public abstract bool has_border { get; set; default = true; }
    public abstract int border_size { get; set; }
    public abstract Gdk.RGBA border_color { get; set; }
    public abstract int stroke_alpha { get; set; }
    public abstract bool hidden_border { get; set; default = false; }

    // Style Panel attributes.
    public abstract bool size_locked { get; set; default = false; }
    public abstract double size_ratio { get; set; default = 1.0; }
    public abstract bool flipped_h { get; set; default = false; }
    public abstract bool flipped_v { get; set; default = false; }
    public abstract bool show_border_radius_panel { get; set; default = false; }
    public abstract bool show_fill_panel { get; set; default = false; }
    public abstract bool show_border_panel { get; set; default = false; }

    public abstract Models.CanvasItemType item_type { get; set; }

    public double get_coords (string coord_id) {
        double _coord = 0.0;
        get (coord_id, out _coord);

        return _coord;
    }

    public void delete () {
        // TODO: emit signal to update SideMenu
        remove ();
    }

    public static string create_item_id (Models.CanvasItem item) {
        string[] type_slug_tokens = item.item_type.to_string ().split ("_");
        string type_slug = type_slug_tokens[type_slug_tokens.length - 1];

        return "%s %d".printf (capitalize (type_slug.down ()), global_id++);
    }

    public static string capitalize (string s) {
        string back = s;
        if (s.get_char (0).islower ()) {
            back = s.get_char (0).toupper ().to_string () + s.substring (1);
        }

        return back;
    }

    public static void init_item (Goo.CanvasItem item) {
        item.set ("opacity", 100.0);
        item.set ("fill-alpha", 255);
        item.set ("stroke-alpha", 255);

        update_z_index (item);
    }

    public static void update_z_index (Goo.CanvasItem item) {
        var z_index = item.get_canvas ().get_root_item ().find_child (item);

        item.set ("z_index", z_index);
    }

    public virtual void reset_colors () {
        reset_fill ();
        reset_border ();
    }

    private void reset_fill () {
        if (hidden_fill || !has_fill) {
            set ("fill-color-rgba", null);
            return;
        }

        var rgba_fill = Gdk.RGBA ();
        rgba_fill = color;
        //  debug (fill_alpha.to_string ());
        rgba_fill.alpha = ((double) fill_alpha) / 255 * opacity / 100;
        //  debug (rgba_fill.alpha.to_string ());

        uint fill_color_rgba = Utils.Color.rgba_to_uint (rgba_fill);
        set ("fill-color-rgba", fill_color_rgba);
    }

    private void reset_border () {
        if (hidden_border || !has_border) {
            set ("stroke-color-rgba", null);
            set ("line-width", null);
            return;
        }

        var rgba_stroke = Gdk.RGBA ();
        rgba_stroke = border_color;
        rgba_stroke.alpha = ((double) stroke_alpha) / 255 * opacity / 100;

        uint stroke_color_rgba = Utils.Color.rgba_to_uint (rgba_stroke);
        set ("stroke-color-rgba", stroke_color_rgba);
        set ("line-width", (double) border_size);
    }
}
