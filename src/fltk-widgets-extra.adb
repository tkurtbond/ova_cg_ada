package body FLTK.Widgets.Extra is

   --  libfltkada's, as Widgets.Set_Image imports it: Fl_Widget::image.
   procedure fl_widget_set_image (W, I : Storage.Integer_Address)
     with Import, Convention => C, External_Name => "fl_widget_set_image";

   procedure Clear_Image (This : in out Widget'Class) is
   begin
      This.Current_Image := null;
      fl_widget_set_image (This.Void_Ptr, Null_Pointer);
   end Clear_Image;

end FLTK.Widgets.Extra;
