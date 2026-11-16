with Ada.Unchecked_Deallocation;
with FLTK.Asks;
with FLTK.Native_File_Choosers;
with FLTK.Static;
with FLTK.Text_Buffers;
with Ova_Cg.Markdown;

package body Ova_Cg.Markdown_Tab is

   use Ada.Strings.Unbounded;
   use type Character.Character_Access;

   package Buffers renames FLTK.Text_Buffers;

   type Buffer_Access is access all Buffers.Text_Buffer'Class;

   Row      : constant := 25;
   Left_X   : constant := 10;
   Column_W : constant := 620;

   type Parts is record
      Tab        : Group_Access;
      Display    : Display_Access;
      Buffer     : Buffer_Access;
      Copy, Save : Widgets.Button_Access;
      Inline     : Check_Access;
   end record;

   Open : Parts;

   The_Sheet     : Unbounded_String;            --  the text shown
   The_Character : Character.Character_Access;  --  the character shown

   function Tab return Group_Access is (Open.Tab);
   function Display return Display_Access is (Open.Display);
   function Copy return Widgets.Button_Access is (Open.Copy);
   function Save return Widgets.Button_Access is (Open.Save);
   function Inline return Check_Access is (Open.Inline);
   function Sheet return String is (To_String (The_Sheet));

   procedure Dialog_Tell (Text : String) is
   begin
      FLTK.Asks.Message_Box (Text);
   end Dialog_Tell;

   function Dialog_Path (Suggested : String; Path : out Unbounded_String) return Boolean is
      use FLTK.Native_File_Choosers;
      C : Native_File_Chooser := Forge.Create (Browse_Save_File);
   begin
      Path := Null_Unbounded_String;
      C.Set_Title ("Save the Markdown sheet as");
      C.Set_Options (Saveas_Confirm);
      C.Add_Filter ("Markdown", "*.md");
      if Suggested /= "" then
         C.Set_Preset_File (Suggested);
      end if;
      if C.Show = Picked then
         Path := To_Unbounded_String (C.Get_Filename);
      end if;
      return Path /= "";
   end Dialog_Path;

   procedure Show (C : not null Character.Character_Access) is
      Ok : Boolean;
   begin
      The_Character := C;
      if Open.Inline.Is_On then
         Ok := Markdown.Inline (C, The_Sheet);
      else
         Ok := Markdown.Sheet (C, The_Sheet);
      end if;
      pragma Unreferenced (Ok);  --  The_Sheet is "" if not
      Open.Buffer.Set_Entire_Text (To_String (The_Sheet));
   end Show;

   --  Inline: the character shown again, the other way.
   procedure Inline_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if The_Character /= null then
         Show (The_Character);
      end if;
   end Inline_Action;

   --  Copy: the whole sheet on the clipboard.
   procedure Copy_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      FLTK.Static.Copy (To_String (The_Sheet), FLTK.Static.Clipboard);
   end Copy_Action;

   --  Save Markdown...: the sheet in a file the user chooses, the
   --  character's name suggested: NAME.md, or NAME-inline.md for the
   --  inline paragraph.
   procedure Save_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Name : constant String :=
        (if The_Character = null then "" else To_String (The_Character.Name));
      Path, Msg : Unbounded_String;
   begin
      if Choose_Path ((if Name = "" then ""
                       elsif Open.Inline.Is_On then Name & "-inline.md"
                       else Name & ".md"), Path)
        and then not Markdown.Save (To_String (The_Sheet), To_String (Path), Msg)
      then
         Tell (To_String (Msg));
      end if;
   end Save_Action;

   procedure Build (X, Y, W, H : Integer) is
      Top : constant := 10;
   begin
      Open.Tab := new Widgets.Groups.Group'(Widgets.Groups.Forge.Create (X, Y, W, H, "Markdown"));
      Open.Tab.Begin_Current;
      Open.Copy := new Widgets.Buttons.Button'
        (Widgets.Buttons.Forge.Create (Left_X, Y + Top, 80, Row, "Copy"));
      Open.Copy.Set_Callback (Copy_Action'Access);
      Open.Copy.Set_Tooltip ("Put the whole sheet on the clipboard");
      Open.Save := new Widgets.Buttons.Button'
        (Widgets.Buttons.Forge.Create (Left_X + 85, Y + Top, 150, Row, "Save Markdown..."));
      Open.Save.Set_Callback (Save_Action'Access);
      Open.Inline := new Checks.Check_Button'
        (Checks.Forge.Create (Left_X + 245, Y + Top, 100, Row, "Inline"));
      Open.Inline.Set_Callback (Inline_Action'Access);
      Open.Inline.Set_Tooltip ("Show the character as one paragraph, as an adventure's cast lists it");
      Open.Buffer := new Buffers.Text_Buffer'(Buffers.Forge.Create);
      Open.Display := new Displays.Text_Display'
        (Displays.Forge.Create (Left_X, Y + Top + Row + 10, Column_W, H - Top - Row - 20, ""));
      Open.Display.Set_Buffer (Buffers.Text_Buffer (Open.Buffer.all));
      Open.Display.Set_Text_Font (FLTK.Courier);
      Open.Display.Set_Wrap_Mode (Displays.Bounds, 0);
      Open.Tab.End_Current;
   end Build;

   procedure Close is
      procedure Free_Group is new Ada.Unchecked_Deallocation (Widgets.Groups.Group'Class, Group_Access);
      procedure Free_Display is new Ada.Unchecked_Deallocation (Displays.Text_Display'Class, Display_Access);
      procedure Free_Buffer is new Ada.Unchecked_Deallocation (Buffers.Text_Buffer'Class, Buffer_Access);
      procedure Free_Check is new Ada.Unchecked_Deallocation (Checks.Check_Button'Class, Check_Access);
      procedure Free_Button is
        new Ada.Unchecked_Deallocation (Widgets.Buttons.Button'Class, Widgets.Button_Access);
   begin
      --  The display before its buffer; every child before the tab.
      Free_Display (Open.Display);
      Free_Buffer (Open.Buffer);
      Free_Button (Open.Copy);
      Free_Button (Open.Save);
      Free_Check (Open.Inline);
      Free_Group (Open.Tab);
      Open := (others => <>);
      The_Sheet := Null_Unbounded_String;
      The_Character := null;
   end Close;

begin
   Tell := Dialog_Tell'Access;
   Choose_Path := Dialog_Path'Access;
end Ova_Cg.Markdown_Tab;
