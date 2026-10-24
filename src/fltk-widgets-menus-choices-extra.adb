with Interfaces.C;

package body FLTK.Widgets.Menus.Choices.Extra is

   --  libfltkada's, as Choices.Set_Chosen imports it: Fl_Choice::value.
   function fl_choice_set_value2 (M : Storage.Integer_Address; I : Interfaces.C.int)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "fl_choice_set_value2";

   procedure Choose_None (This : in out Choice'Class) is
      Ignore : constant Interfaces.C.int := fl_choice_set_value2 (This.Void_Ptr, Interfaces.C."-" (1));
   begin
      null;
   end Choose_None;

end FLTK.Widgets.Menus.Choices.Extra;
