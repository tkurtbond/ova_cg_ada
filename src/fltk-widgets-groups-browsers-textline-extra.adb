with Ada.Unchecked_Deallocation;

package body FLTK.Widgets.Groups.Browsers.Textline.Extra is

   --  libfltkada's, as Textline.Set_Column_Widths imports it.
   procedure fl_browser_set_column_widths (B, W : Storage.Integer_Address)
     with Import, Convention => C, External_Name => "fl_browser_set_column_widths";

   procedure Free is new Ada.Unchecked_Deallocation (C_Col_Widths, C_Col_Widths_Access);

   procedure Set_Column_Widths (This : in out Textline_Browser'Class; Widths : Column_Widths) is
   begin
      Free (This.Columns);
      This.Columns := new C_Col_Widths (1 .. Widths'Length + 1);
      for I in Widths'Range loop
         This.Columns (I - Widths'First + 1) := Interfaces.C.int (Widths (I));
      end loop;
      This.Columns (This.Columns'Last) := 0;
      fl_browser_set_column_widths (This.Void_Ptr, Storage.To_Integer (This.Columns.all'Address));
   end Set_Column_Widths;

end FLTK.Widgets.Groups.Browsers.Textline.Extra;
