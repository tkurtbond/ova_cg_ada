--  Character > Limits...: the rules that limit a character, saved in its
--  options.
--
--  ova_cg_po's PLAN.md, "Limiting the character (p. 21)": Base Zero, a
--  Power Ceiling, starting levels, Scaled Cost, Knowledge and Ineptitude
--  at half cost, Combined Effectiveness, each turned on here and saved
--  in the character's options: block.  Ova_Cg.Calc applies them; this
--  dialog only sets them.
--
--  It edits the character as the user works, as the attack dialog does,
--  so the totals and warnings behind it follow each change (Changed,
--  the window's); Cancel puts back the options there were.  It is modal
--  but doesn't wait: OK and Cancel call Done.  Once closed, its widgets
--  are freed from a timeout, as Ova_Cg.Attack_Dialog's are.
--
--  A number turned off keeps what it was, so turning it on again brings
--  it back; one never set starts at p. 21's example: Base Zero's 5, 5
--  starting levels and a Power Ceiling of 15.

with FLTK.Widgets.Buttons.Light.Check;
with FLTK.Widgets.Groups.Windows.Double;
with Ova_Cg.Character;
with Ova_Cg.Widgets;

package Ova_Cg.Settings is

   package Checks renames FLTK.Widgets.Buttons.Light.Check;
   package Windows renames FLTK.Widgets.Groups.Windows.Double;

   type Window_Access is access all Windows.Double_Window'Class;
   type Check_Access is access all Checks.Check_Button'Class;

   --  The dialog's widgets, for tests; the dialog null when not open.
   function Dialog return Window_Access;
   function Base_Zero return Check_Access;
   function Power_Ceiling return Check_Access;
   function Starting_Levels return Check_Access;
   function Scaled_Cost return Check_Access;
   function Half_Cost return Check_Access;
   function Combined return Check_Access;
   function Base_Zero_Range return Widgets.Spinner_Access;
   function Ceiling return Widgets.Spinner_Access;
   function Starting return Widgets.Spinner_Access;
   function OK_Button return Widgets.Button_Access;
   function Cancel_Button return Widgets.Button_Access;

   --  After each change: the window's, which recomputes and shows.
   type Changed_Handler is access procedure;
   Changed : Changed_Handler;

   --  Called after OK (Accepted True) or Cancel.
   type Done_Handler is access procedure (Accepted : Boolean);

   --  Edits C's limits.
   procedure Edit (C : not null Character.Character_Access; Done : Done_Handler)
     with Pre => Dialog = null;

   --  For tests: Cancel, as if pushed.
   procedure Cancel with Pre => Dialog /= null;

   --  Frees the closed dialogs now, not from the timeout that closing
   --  one sets: for the window's Close, which runs under no dialog's
   --  callback.
   procedure Free_Closed;

end Ova_Cg.Settings;
