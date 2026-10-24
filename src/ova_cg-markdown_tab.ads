--  The window's last tab: the character's sheet in Markdown, to copy or
--  save.
--
--  ova_cg_po's PLAN.md, "The Markdown sheet".  The sheet
--  Ova_Cg.Markdown makes, shown as text the user can select, with
--  Copy, which puts all of it on the clipboard, and Save Markdown...,
--  which writes it to a file.  Inline, checked, shows the inline
--  paragraph instead (Markdown.Inline), and Copy and Save Markdown...
--  take that.
--
--  The window owns the character: it builds this tab inside its Tabs
--  (Build) and shows the character here again after each change
--  (Show), so the text is always the character's.  What would wait for
--  the user -- a message, the file chooser -- goes through
--  access-to-subprogram variables a test sets, as the window's do.

with Ada.Strings.Unbounded;
with FLTK.Widgets.Buttons.Light.Check;
with FLTK.Widgets.Groups.Text_Displays;
with Ova_Cg.Character;
with Ova_Cg.Widgets;

package Ova_Cg.Markdown_Tab is

   package Checks renames FLTK.Widgets.Buttons.Light.Check;
   package Displays renames FLTK.Widgets.Groups.Text_Displays;

   type Group_Access is access all Widgets.Groups.Group'Class;
   type Display_Access is access all Displays.Text_Display'Class;
   type Check_Access is access all Checks.Check_Button'Class;

   --  The widgets, for the window and tests; null before Build and
   --  after Close.
   function Tab return Group_Access;
   function Display return Display_Access;
   function Copy return Widgets.Button_Access;
   function Save return Widgets.Button_Access;
   function Inline return Check_Access;        --  checked: the inline paragraph

   --  The text shown: "" before Show.
   function Sheet return String;

   --  What would wait for the user: Tell shows a message; Choose_Path
   --  asks where to save the sheet, suggesting Suggested ("": nothing),
   --  False if cancelled.  Both are FLTK's dialogs until a test sets
   --  them.
   type Tell_Handler is access procedure (Text : String);
   type Choose_Handler is
     access function (Suggested : String; Path : out Ada.Strings.Unbounded.Unbounded_String)
     return Boolean;
   Tell        : Tell_Handler;
   Choose_Path : Choose_Handler;

   --  Opens the tab, "Markdown", as a child of the group being built,
   --  at X, Y, W by H.
   procedure Build (X, Y, W, H : Integer)
     with Pre => Tab = null;

   --  Shows C's sheet, or its inline paragraph if Inline is checked.
   procedure Show (C : not null Character.Character_Access)
     with Pre => Tab /= null;

   --  Frees the widgets, the tab last, and the buffer: before the
   --  window's Tabs, the tab's group, is freed.
   procedure Close;

end Ova_Cg.Markdown_Tab;
