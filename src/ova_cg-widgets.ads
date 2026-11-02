--  What the window and its dialogs share: the number boxes, the ?
--  buttons, and the panels.
--
--  ova_cg_po's PLAN.md, "Overriding a computed number": beside every
--  number the program computes is an empty entry box.  A Number_Box is
--  both: the computed number, shown read-only, and the box, whose text
--  is the override in effect ("" for none).  Where its number lives is
--  its Target, which the window extends for each kind of number (an
--  attack's ROLL, the sheet's HEALTH, ...), so the box reads and sets
--  the model, never a copy.
--
--  A Help_Button, "?", opens the rulebook at a page ("Page numbers
--  beside names"), through Open_Page, which the window sets.
--
--  A Panel is a list and its editor, the shape PLAN.md gives the
--  Abilities and Weaknesses and the attack dialog's Perks and Flaws: a
--  browser of lines, under it a Choice of every name of one kind
--  (Rules.Label: "Attack (p. 50)"), for a Boss the Boss Abilities after
--  a divider, a Spinner, a text field, and Add, Change, Remove and ?
--  buttons.  What the lines are, and what the buttons do to the model,
--  are its extension's (its primitives).
--
--  Every widget here is on the heap, made in the group current when it
--  is opened; its Free frees the children's Ada objects before the
--  group's (AGENTS.md).

with FLTK.Widgets.Buttons;
with FLTK.Widgets.Groups;
with FLTK.Widgets.Groups.Browsers.Textline.Hold;
with FLTK.Widgets.Groups.Spinners;
with FLTK.Widgets.Inputs.Text;
with FLTK.Widgets.Inputs.Text.Outputs;
with FLTK.Widgets.Menus.Choices;
with Ova_Cg.Calc;
with Ova_Cg.Rules;

package Ova_Cg.Widgets is

   package Buttons renames FLTK.Widgets.Buttons;
   package Groups renames FLTK.Widgets.Groups;
   package Hold renames FLTK.Widgets.Groups.Browsers.Textline.Hold;
   package Spinners renames FLTK.Widgets.Groups.Spinners;
   package Texts renames FLTK.Widgets.Inputs.Text;
   package Outputs renames FLTK.Widgets.Inputs.Text.Outputs;
   package Choices renames FLTK.Widgets.Menus.Choices;

   --  A Number_Box's size: the computed number, then the box.
   Shown_Width : constant := 40;
   Entry_Width : constant := 45;
   Gap         : constant := 2;
   Width       : constant := Shown_Width + Gap + Entry_Width;
   Height      : constant := 25;

   --  ---- Targets ----

   --  Where a Number_Box's number lives.
   type Target is interface;
   type Target_Access is access all Target'Class;

   --  The number.
   function Get (T : Target) return Calc.Number is abstract;

   --  Sets the number to N.
   procedure Put (T : in out Target; N : Calc.Number) is abstract;

   procedure Free (T : in out Target_Access);

   --  ---- Number_Box ----

   type Number_Box is tagged;
   type Number_Box_Access is access all Number_Box'Class;

   type Output_Access is access all Outputs.Output'Class;

   --  The override's box: the user's text, taken into its Number_Box.
   type Entry_Input is new Texts.Text_Input with record
      Box : Number_Box_Access;
   end record;
   type Entry_Access is access all Entry_Input'Class;

   --  After the user leaves the box: the override set from its text,
   --  or (OK False) the text refused, and the box emptied.
   type Changed_Handler is access procedure (B : in out Number_Box'Class; OK : Boolean);

   type Number_Box is new Groups.Group with record
      Shown      : Output_Access;  --  the computed number
      Entry_In   : Entry_Access;   --  the override: "" for none
      Target     : Target_Access;  --  the box's own: Set_Target frees the one before
      Allow_Half : Boolean := False;  --  a DX's 1/2
      Allow_Plus : Boolean := False;  --  an END's 10+
      Changed    : Changed_Handler;
   end record;

   --  Opens a Number_Box at X, Y, Width by Height, labelled above, in
   --  the current group; no target.
   function Open_Number_Box (X, Y : Integer; Label : String) return not null Number_Box_Access;

   --  Makes T the box's target (null: none), freeing the one before.
   procedure Set_Target (B : in out Number_Box'Class; T : Target_Access);

   --  Shows the target's number: computed, and its override.
   procedure Display (B : in out Number_Box'Class);

   --  The box's text read into its target's override (an empty box
   --  clears it); text that isn't a number for it is refused, and the
   --  override cleared.
   procedure Take (B : in out Number_Box'Class);

   --  Frees B, its children and its target; B null after.
   procedure Free (B : in out Number_Box_Access);

   --  ---- Help_Button ----

   type Help_Button is new Buttons.Button with record
      Page : Natural := 0;  --  the printed page; 0: nothing to show
   end record;
   type Help_Button_Access is access all Help_Button'Class;

   --  What a Help_Button does with its page: the window's, which opens
   --  the rulebook there.
   type Page_Handler is access procedure (Page : Positive);
   Open_Page : Page_Handler;

   --  Opens a "?" button, 25 by 25, showing Page (0: none yet), in the
   --  current group.
   function Open_Help_Button (X, Y : Integer; Page : Natural) return not null Help_Button_Access;

   procedure Free (B : in out Help_Button_Access);

   --  ---- Panel ----

   type Browser_Access is access all Hold.Hold_Browser'Class;
   type Choice_Access is access all Choices.Choice'Class;
   type Spinner_Access is access all Spinners.Spinner'Class;
   type Input_Access is access all Texts.Text_Input'Class;
   type Button_Access is access all Buttons.Button'Class;

   type Panel is tagged;
   type Panel_Access is access all Panel'Class;

   type Panel is abstract tagged limited record
      Kind    : Rules.Kind;  --  the Choice's
      With_Boss : Boolean := False;  --  the Choice offers the Boss Abilities too
      Browser : Browser_Access;
      Choice  : Choice_Access;
      Spinner : Spinner_Access;
      Text    : Input_Access;
      Add_Button, Change_Button, Remove_Button : Button_Access;
      Help    : Help_Button_Access;
      Bottom  : Integer := 0;  --  the y under the panel's last row
      Next    : Panel_Access;  --  the open panels
   end record;

   --  The extension's: fills the browser from the model, lines in the
   --  model's order.
   procedure Fill (P : in out Panel) is abstract;

   --  The extension's: the controls set from the browser's line (1 is
   --  the first), the one the user selected.
   procedure Load (P : in out Panel; Line : Positive) is abstract;

   --  The extension's: what Add, Change and Remove do to the model,
   --  from the controls; Change and Remove on the selected line.  Add
   --  and Change return the line the item will be on once Fill runs
   --  again (a change can move it), or 0 if they changed nothing;
   --  Remove whether it removed it.  Each leaves the model recomputed.
   function Add (P : in out Panel) return Natural is abstract;
   function Change (P : in out Panel; Line : Positive) return Natural is abstract;
   function Remove (P : in out Panel; Line : Positive) return Boolean is abstract;

   --  The name chosen; null for none.
   function Item (P : Panel'Class) return Rules.Item;

   --  After the Choice changes: the ? button turns to the chosen name's
   --  page; an extension sets the Spinner's bounds and the text field
   --  too.
   procedure Chosen (P : in out Panel);

   --  What happens after a change the panel made: the window's or
   --  dialog's refresh.  Nothing here.
   procedure Changed (P : in out Panel);

   --  Chooses It in the Choice (none for null, or an item the Choice
   --  doesn't offer), and sets the ? button.
   procedure Choose (P : in out Panel'Class; It : Rules.Item);

   --  Offers the Boss Abilities, or stops: what is chosen stays, if it
   --  still can.
   procedure Offer_Boss (P : in out Panel'Class; On : Boolean);

   --  The browser filled again, its line Line selected (0: none) and
   --  the controls loaded from it.
   procedure Refresh (P : in out Panel'Class; Line : Natural);

   --  Opens P at X, Y, W wide, its browser H high, in the current
   --  group: its Choice of Kind's names, its Spinner labelled
   --  Spin_Label, its text field Text_Label, its browser Title.
   procedure Open_Panel (P : not null Panel_Access; X, Y, W, H : Integer; Kind : Rules.Kind;
                         Title, Spin_Label, Text_Label : String);

   --  Forgets P and frees its widgets.
   procedure Close_Panel (P : not null Panel_Access);

   --  ---- Helpers ----

   --  A Spinner's value as a whole number, rounded down (ENTIER).
   function Spin_Value (S : Spinners.Spinner'Class) return Integer;

end Ova_Cg.Widgets;
