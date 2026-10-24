with Ada.Command_Line;
with Ada.Text_IO;

package body Check is

   Failures : Natural := 0;

   procedure Check (OK : Boolean; Label : String) is
   begin
      if OK then
         Ada.Text_IO.Put_Line ("ok   - " & Label);
      else
         Ada.Text_IO.Put_Line ("FAIL - " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Summary is
   begin
      if Failures = 0 then
         Ada.Text_IO.Put_Line ("All checks passed.");
      else
         Ada.Text_IO.Put_Line (Natural'Image (Failures)(2 .. Natural'Image (Failures)'Last)
                               & " check(s) failed.");
         Ada.Command_Line.Set_Exit_Status (1);
      end if;
   end Summary;

   function Failed return Natural is (Failures);

end Check;
