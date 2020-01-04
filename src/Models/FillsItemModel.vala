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
* Authored by: Giacomo "giacomoalbe" Alberini <giacomoalbe@gmail.com>
*/

public class Akira.Models.FillsItemModel : GLib.Object {
    public string color {
        owned get {
            return item.color;

            /*
            var rgba = item.fill_color_rgba;
            var result = "#%02x%02x%02x".printf (
                (int) (Math.round (rgba >> 24 & 0xFF)),
                (int) (Math.round (rgba >> 16 & 0xFF)),
                (int) (Math.round (rgba >> 8 & 0xFF))
            );
            return result;
            */
        } set {
            var new_rgba = Gdk.RGBA ();
            new_rgba.parse (value);

            debug (@"R: $(new_rgba.red)");
            debug (@"G: $(new_rgba.green)");
            debug (@"B: $(new_rgba.blue)");

            var alpha = item.fill_alpha * item.opacity;

            uint rgba = (uint) Math.round (new_rgba.red * 255);
            rgba = (rgba << 8) + (uint)Math.round (new_rgba.green * 255);
            rgba = (rgba << 8) + (uint)Math.round (new_rgba.blue * 255);
            rgba = (rgba << 8) + (uint)Math.round (alpha);

            var new_color_hex = "#%02x%02x%02x".printf (
                (int) (Math.round (rgba >> 24 & 0xFF)),
                (int) (Math.round (rgba >> 16 & 0xFF)),
                (int) (Math.round (rgba >> 8 & 0xFF))
            );

            debug (@"New color: $(new_color_hex)");

            item.color = new_color_hex;
        }
    }
    public double alpha {
        get {
            return item.fill_alpha;
        }
        set {
            debug (@"Alpha: $(value)");
            /*
            var rgba = item.fill_color_rgba;
            var fill_a = (int) (value * 255);
            //  debug ("set alpha: %f", fill_a);
            item.set_data<int?> ("fill-alpha", fill_a);
            var opacity_factor = item.get_data<double?> ("opacity") / 100;
            var alpha = fill_a * opacity_factor;
            item.fill_color_rgba = (rgba & 0xFFFFFF00) + (uint) (alpha);
            */
        }
    }
    public bool hidden { get; set; }
    public Akira.Utils.BlendingMode blending_mode { get; set; }
    public Akira.Models.FillsListModel list_model { get; set; }
    public Lib.Models.CanvasItem item { get; construct; }

    public FillsItemModel (
        Lib.Models.CanvasItem item,
        bool hidden,
        Akira.Utils.BlendingMode blending_mode,
        Akira.Models.FillsListModel list_model
    ) {
        Object (
            hidden: hidden,
            blending_mode: blending_mode,
            list_model: list_model,
            item: item
        );
    }

    public string to_string () {
        return "Color: %s\nAlpha: %f\nHidden: %s\nBlendingMode: %s".printf (
            color, alpha, (hidden ? "1" : "0"), blending_mode.to_string ());
    }
}
