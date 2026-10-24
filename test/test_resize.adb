--  Ova_Cg.Window: resized, everything in it stretched to the window's
--  size.
--
--  Needs a display: run by make test-gui, as test_window is.  The
--  window, never shown, is resized as a window manager would (Resize,
--  which FLTK passes to its children), larger and back.  FLTK stretches
--  the widgets; the window fits what it doesn't, after: the menu bar
--  and the tabs' bar keep their height, the combat box's rows stretch
--  with the box, the traits' names' column with its browser, the
--  portrait with its box, keeping its proportions.  A row made again
--  after a resize (an attack removed) is stretched too.

with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Check;
with FLTK;
with Ova_Cg.Background;
with Ova_Cg.Markdown_Tab;
with Ova_Cg.Widgets;
with Ova_Cg.Window;

procedure Test_Resize is

   use Ova_Cg;
   use type Background.Image_Access;

   --  fltkada writes no PNG, so the portrait is a PPM, which FLTK's
   --  shared images read as they do a PNG (PLAN.md, "Findings").
   Image_Path : constant String := "../obj/resize-face.ppm";
   Image_W    : constant := 300;  --  larger than the box, and in its proportions taller
   Image_H    : constant := 400;
   Portrait_H : constant := 250;  --  the box's first height
   Width      : constant := 640;  --  the window's first size,
   Height     : constant := 800;
   Big_W      : constant := 960;  --  and the one it is resized to
   Big_H      : constant := 1200;
   Bar_Height : constant := 25;
   Tab_Height : constant := 25;
   Column_W   : constant := 620;
   Row_W      : constant := 600;
   Row        : constant := 25;
   Row_H      : constant := 30;
   Left_X     : constant := 10;
   Name_W     : constant := 180;
   Box_H      : constant := 17 * 30 + 4;  --  the combat box's first height

   Chosen_Image : Unbounded_String;
   First_Name_W : Integer;
   OK           : Boolean;

   procedure Tell (Text : String) is null;

   function Choose_Image (P : out Unbounded_String) return Boolean is
   begin
      P := Chosen_Image;
      return P /= Null_Unbounded_String;
   end Choose_Image;

   --  Lets FLTK run what it put off: timers.
   procedure Settle is
      Ignored : Long_Float;
   begin
      for I in 1 .. 5 loop
         Ignored := FLTK.Wait (0.01);
      end loop;
   end Settle;

   function Round (X : Float) return Integer is (Integer (Float'Floor (X + 0.5)));

   --  Whether A and B differ by at most D: FLTK rounds each edge.
   function Near (A, B, D : Integer) return Boolean is (abs (A - B) <= D);

   --  Whether the combat box's rows are its rows stretched by the box's
   --  width and height over its first ones: each the first row's size
   --  so stretched, its ROLL box as wide and as far along, and each as
   --  far below the one before.
   function Rows_Fit return Boolean is
      Box : constant Window.Scroll_Access := Window.Attack_Box;
      SX  : constant Float := Float (Box.Get_W) / Float (Column_W);
      SY  : constant Float := Float (Box.Get_H) / Float (Box_H);
      OK  : Boolean := Window.Row_Count > 0;
   begin
      for I in 1 .. Window.Row_Count loop
         exit when not OK;
         declare
            R : constant Window.Attack_Row_Access := Window.Row (I);
         begin
            OK := Near (R.Get_W, Round (Float (Row_W) * SX), 1)
              and then Near (R.Get_H, Round (Float (Row) * SY), 1)
              and then Near (R.Get_Y - Box.Get_Y, Round (Float (2 + (I - 1) * Row_H) * SY), 1)
              and then Near (R.Roll.Get_W, Round (Float (Widgets.Width) * SX), 1)
              and then Near (R.Roll.Get_X - Box.Get_X, Round (Float (2 + Name_W + 8) * SX), 2);
         end;
      end loop;
      return OK;
   end Rows_Fit;

   --  Whether the portrait shown fills its box's height, within its
   --  width: the image is taller than wide, as the box.
   function Portrait_Fits return Boolean is
      Img : constant Background.Image_Access := Background.Portrait_Image;
      Box : constant Background.Box_Access := Background.Portrait;
   begin
      return Img /= null and then Img.Get_H = Box.Get_H - 6 and then Img.Get_W <= Box.Get_W - 6;
   end Portrait_Fits;

   --  Resizes the window to W by H, and lets it fit what FLTK doesn't
   --  stretch.
   procedure Resize (W, H : Integer) is
   begin
      Window.Main.Resize (W, H);
      Settle;
   end Resize;

   --  A portrait: a gradient, Image_W by Image_H, as a binary PPM.
   function Write_Image return Boolean is
      use Ada.Streams.Stream_IO;
      F : File_Type;
      S : Stream_Access;
   begin
      Create (F, Out_File, Image_Path);
      S := Stream (F);
      String'Write (S, "P6" & ASCII.LF & "300 400" & ASCII.LF & "255" & ASCII.LF);
      for I in 0 .. Image_W * Image_H * 3 - 1 loop
         Standard.Character'Write (S, Standard.Character'Val (I mod 251));
      end loop;
      Close (F);
      return Natural (Ada.Directories.Size (Image_Path)) > Image_W * Image_H * 3;
   end Write_Image;

   R : Window.Attack_Row_Access;

begin
   Window.Build;
   Window.Tell := Tell'Unrestricted_Access;
   Background.Tell := Tell'Unrestricted_Access;
   Background.Choose_Image := Choose_Image'Unrestricted_Access;

   Check.Check (Write_Image, "an image written to choose");

   OK := Window.Load ("data/Ai.yaml");
   Chosen_Image := To_Unbounded_String (Image_Path);
   Background.Choose_Portrait.Do_Callback;
   Check.Check (OK and then Window.Row_Count >= 2, "a character with two attacks");
   R := Window.Row (1);
   Check.Check (Window.Main.Get_W = Width and then Window.Main.Get_H = Height and then R.Get_W = Row_W
                and then R.Get_H = Row and then R.Roll.Get_W = Widgets.Width
                and then R.Roll.Get_X = Left_X + 2 + Name_W + 8 and then Rows_Fit,
                "at first: the rows as built");
   First_Name_W := Window.Abilities.Name_W;
   Check.Check (First_Name_W = Window.Abilities.Browser.Get_W - 70, "the names' column, as built");
   Check.Check (Portrait_Fits, "the portrait fits its box");

   --  ---- Larger ----
   Resize (Big_W, Big_H);
   Check.Check (Window.Main.Get_W = Big_W and then Window.Main.Get_H = Big_H, "resized larger");
   Check.Check (Window.Bar.Get_H = Bar_Height and then Window.Character_Choice.Get_H = Bar_Height
                and then Window.Character_Choice.Get_X + Window.Character_Choice.Get_W = Big_W,
                "the menu bar and the characters' choice: as high, across the window");
   Check.Check (Window.Sheet_Tab.Get_Y = Bar_Height + Tab_Height and then Window.Sheet_Tab.Get_W = Big_W
                and then Window.Sheet_Tab.Get_H = Big_H - Bar_Height - Tab_Height
                and then Markdown_Tab.Tab.Get_W = Big_W
                and then Markdown_Tab.Tab.Get_H = Big_H - Bar_Height - Tab_Height,
                "the tabs' bar as high, the pages filling the rest");
   Check.Check (Window.Attack_Box.Get_W = Round (Float (Column_W) * 1.5)
                and then Window.Abilities.Browser.Get_W > First_Name_W + 70
                and then Window.Combat_Notes.Get_W = Round (Float (Column_W) * 1.5),
                "the widgets stretched");
   Check.Check (Rows_Fit and then Window.Row (1).Get_W > Row_W, "the combat box's rows stretched with it");
   Check.Check (Window.Abilities.Name_W = Window.Abilities.Browser.Get_W - 70,
                "the Abilities' names' column too");
   Check.Check (Window.Weaknesses.Name_W = Window.Weaknesses.Browser.Get_W - 70, "and the Weaknesses'");
   Check.Check (Portrait_Fits and then Background.Portrait_Image.Get_H > Portrait_H,
                "the portrait fits its larger box");

   --  A row made again, after a resize.
   Window.Row (1).Remove.Do_Callback;
   Settle;
   Check.Check (Rows_Fit and then Window.Row_Count = 1 and then Window.Row (1).Get_W > Row_W,
                "an attack removed: the row left, stretched");

   --  ---- Back ----
   Resize (Width, Height);
   R := Window.Row (1);
   Check.Check (Window.Sheet_Tab.Get_H = Height - Bar_Height - Tab_Height and then R.Get_W = Row_W
                and then R.Get_H = Row and then R.Roll.Get_W = Widgets.Width
                and then R.Roll.Get_X = Left_X + 2 + Name_W + 8,
                "back to the first size: the rows as built");
   Check.Check (Window.Abilities.Name_W = First_Name_W and then Portrait_Fits,
                "the column and the portrait too");

   Window.Close;
   if Ada.Directories.Exists (Image_Path) then
      Ada.Directories.Delete_File (Image_Path);
   end if;
   --  As test_markdown's: fltkada keeps no count of the widgets open.
   declare
      use type Window.Window_Access, Window.Tabs_Access, Background.Box_Access;
   begin
      Check.Check (Window.Main = null and then Window.Tabs = null and then Background.Portrait = null,
                   "every widget is deleted");
   end;
   Check.Summary;
end Test_Resize;
