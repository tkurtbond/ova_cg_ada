--  test/viewer.sh's driver: Ova_Cg.Viewer.Open with a real viewer.
--
--  open_page VIEWER PDF PAGE...
--  Opens each printed PAGE of PDF in VIEWER (as Ova_Cg.Viewer.Parse
--  takes it), one after another in this one process, Pause apart (3 s),
--  as the program's ? buttons would: so a mupdf started for one page is
--  ended before the next.  Prints each Open's message, and exits 1 if
--  one fails.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ova_Cg.Viewer; use Ova_Cg.Viewer;

procedure Open_Page is

   Pause : constant Duration := 3.0;

   V   : Viewer_Type;
   Msg : Unbounded_String;
   OK  : Boolean;

   --  Argument I as a page; 0 if it isn't one.
   function Page_Of (I : Positive) return Natural is
   begin
      return Natural'Value (Argument (I));
   exception
      when Constraint_Error =>
         return 0;
   end Page_Of;

begin
   OK := Argument_Count >= 3 and then Parse (Argument (1), V);
   if OK then
      OK := (for all I in 3 .. Argument_Count => Page_Of (I) > 0);
   end if;
   if not OK then
      Ada.Text_IO.Put_Line ("usage: open_page VIEWER PDF PAGE...");
      Set_Exit_Status (2);
      return;
   end if;
   for I in 3 .. Argument_Count loop
      if I > 3 then
         delay Pause;
      end if;
      if not Open (V, Argument (2), Page_Of (I), Msg) then
         OK := False;
      end if;
      if Msg /= "" then
         Ada.Text_IO.Put_Line (To_String (Msg));
      end if;
   end loop;
   if not OK then
      Set_Exit_Status (1);
   end if;
end Open_Page;
