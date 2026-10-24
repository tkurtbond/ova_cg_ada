--  What fltkada's Widget has no call for: showing no image again, which
--  the portrait's box does when the portrait is removed or can't be
--  read (Ova_Cg.Background).  Set_Image takes an image, never none.
--
--  A child of fltkada's package, kept here, not in fltkada: its body
--  sees the widget's C pointer and its record, as fltkada's own do, and
--  calls the C wrapper Set_Image calls, with no image.

package FLTK.Widgets.Extra is

   --  This shows no image: Get_Image null.  The image it showed is the
   --  caller's to free, now or later.
   procedure Clear_Image (This : in out Widget'Class);

end FLTK.Widgets.Extra;
