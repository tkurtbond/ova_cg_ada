--  What fltkada's Choice has no call for: choosing no item, which a
--  Panel shows for a name the tables don't have (Ova_Cg.Widgets).
--
--  A child of fltkada's package, kept here, not in fltkada: its body
--  sees the widget's C pointer, as fltkada's own do, and calls the C
--  wrapper Set_Chosen calls, with FLTK's -1 for none.  Checked under
--  Xvfb: Chosen_Index is 0 after it.

package FLTK.Widgets.Menus.Choices.Extra is

   --  Shows no item chosen: Chosen_Index 0.
   procedure Choose_None (This : in out Choice'Class);

end FLTK.Widgets.Menus.Choices.Extra;
