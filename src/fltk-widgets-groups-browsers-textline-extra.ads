--  What fltkada's Textline_Browser gets wrong: its Set_Column_Widths
--  copies one width past the end of the array it is given, so every
--  call raises Constraint_Error (fltk-widgets-groups-browsers-
--  textline.adb, Set_Column_Widths).  Checked under Xvfb.
--
--  A child of fltkada's package, kept here, not in fltkada, as
--  Menus.Choices.Extra is: its body sets the browser's own widths
--  array, which fltkada frees with the browser, and calls the C
--  wrapper fltkada's does.

package FLTK.Widgets.Groups.Browsers.Textline.Extra is

   --  The columns' widths, as Fl_Browser::column_widths takes them less
   --  its closing 0: Widths, then the last column takes the rest.
   procedure Set_Column_Widths (This : in out Textline_Browser'Class; Widths : Column_Widths);

end FLTK.Widgets.Groups.Browsers.Textline.Extra;
