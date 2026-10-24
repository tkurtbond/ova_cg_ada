--  The window's last two tabs: the sheet's left half, the fluff, and
--  the notes.
--
--  ova_cg_po's PLAN.md, "The window", the third and fourth tabs.
--  "Background": the Summary; Background, Appearance, Personality,
--  Character Hooks and Other Notes, each a text editor.  "Fluff": the
--  Character Portrait, an image file whose path is saved relative to
--  the YAML file; the fluff fields (p. 20) in a grid; and the headed
--  notes ova_fmt prints as callouts (notes:), so everything a file
--  holds can be edited.
--
--  The window owns the character and the file: it builds the two tabs
--  inside its Tabs (Build), shows a character here (Show), and is told
--  of each change (Changed).  What would wait for the user -- a
--  message, the image chooser -- goes through access-to-subprogram
--  variables a test sets, as the window's do.  Every change goes into
--  the character at once, as the user types; nothing here holds the
--  only copy.

with Ada.Strings.Unbounded;
with FLTK.Images.Shared;
with FLTK.Widgets.Boxes;
with FLTK.Widgets.Groups.Grids;
with FLTK.Widgets.Groups.Text_Displays.Text_Editors;
with FLTK.Widgets.Inputs.Text.Multiline;
with Ova_Cg.Character;
with Ova_Cg.Widgets;

package Ova_Cg.Background is

   package Boxes renames FLTK.Widgets.Boxes;
   package Grids renames FLTK.Widgets.Groups.Grids;
   package Editors renames FLTK.Widgets.Groups.Text_Displays.Text_Editors;
   package Shared renames FLTK.Images.Shared;
   package Multiline renames FLTK.Widgets.Inputs.Text.Multiline;

   type Group_Access is access all Widgets.Groups.Group'Class;
   type Box_Access is access all Boxes.Box'Class;
   type Grid_Access is access all Grids.Grid'Class;
   type Editor_Access is access all Editors.Text_Editor'Class;
   type Image_Access is access all Shared.Shared_Image'Class;
   type Multiline_Access is access all Multiline.Multiline_Input'Class;

   --  The prose sections, in the order the tab shows them.
   type Prose_Section is
     (Background_Section, Appearance_Section, Personality_Section, Character_Hooks_Section,
      Other_Notes_Section);

   --  The widgets, for the window and tests; null before Build and
   --  after Close.
   function Background_Tab return Group_Access;
   function Fluff_Tab return Group_Access;
   function Summary_In return Widgets.Input_Access;
   function Prose (Which : Prose_Section) return Editor_Access;
   function Portrait return Box_Access;               --  the image, or why it can't be shown
   function Portrait_Path return Widgets.Output_Access;  --  the path as saved
   function Choose_Portrait return Widgets.Button_Access;
   function Remove_Portrait return Widgets.Button_Access;
   function Portrait_Image return Image_Access;        --  the portrait shown; null: none
   function Fluff_Grid return Grid_Access;
   function Fluff_In (Field : Character.Fluff_Field) return Widgets.Input_Access;
   function Notes return Widgets.Browser_Access;       --  the notes' headers, in order
   function Note_Header return Widgets.Input_Access;
   function Note_Text return Multiline_Access;
   function Add_Note return Widgets.Button_Access;
   function Change_Note return Widgets.Button_Access;
   function Remove_Note return Widgets.Button_Access;

   --  Set by the window: called after every change the user makes here.
   type Changed_Handler is access procedure;
   Changed : Changed_Handler;

   --  What would wait for the user: Tell shows a message; Choose_Image
   --  asks for an image file, False if cancelled.  Both are FLTK's
   --  dialogs until a test sets them.
   type Tell_Handler is access procedure (Text : String);
   type Choose_Handler is
     access function (Path : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   Tell         : Tell_Handler;
   Choose_Image : Choose_Handler;

   --  Opens the two tabs, "Background" and "Fluff", as children of the
   --  group being built, each at X, Y, W by H.
   procedure Build (X, Y, W, H : Integer)
     with Pre => Background_Tab = null;

   --  Shows C, whose file is in directory Dir ("": none, never saved).
   procedure Show (C : not null Character.Character_Access; Dir : String)
     with Pre => Background_Tab /= null;

   --  The file is now in directory Dir: a portrait path is shown from
   --  it.  The window has rebased the path already (Paths.Rebase).
   procedure Set_Dir (Dir : String)
     with Pre => Background_Tab /= null;

   --  Fits the portrait shown to its box, as the box is now: after the
   --  window is resized.
   procedure Fit;

   --  Frees the widgets, the tabs last, the buffers and the image:
   --  before the window's Tabs, the tabs' group, is freed.
   procedure Close;

end Ova_Cg.Background;
