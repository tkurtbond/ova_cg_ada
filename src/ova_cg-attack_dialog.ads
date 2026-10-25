--  The attack dialog, and the Perks and Flaws editor of an Ability.
--
--  ova_cg_po's PLAN.md, "The window": an attack's name, description and
--  affinity, whether it is made with Telekinesis or in the transformed
--  form, its Perks and its Flaws, each a list with a name, a count
--  (where it can be taken more than once) and a cost (where the user
--  chooses one: Cancel, Requirement, Unique), and its ROLL, DX and END,
--  computed as the Perks and Flaws change, each with its override box.
--  An Ability with Perks and Flaws is edited by the same dialog,
--  without the attack's fields: its END alone.
--
--  The dialog changes the model as the user works, so the numbers it
--  shows are Ova_Cg.Calc's; Cancel puts back what was there when it
--  opened (a new attack, the window added, it takes out and frees).  It
--  doesn't wait: Edit_Attack and Edit_Mods show it, and OK or Cancel
--  calls Done.  Once closed, its widgets are freed from a timeout, never
--  inside their own callbacks (AGENTS.md).

with FLTK.Widgets.Buttons.Light.Check;
with FLTK.Widgets.Groups.Windows.Double;
with FLTK.Widgets.Inputs.Text.Multiline;
with Ova_Cg.Character;
with Ova_Cg.Widgets;

private with Ada.Containers.Vectors;

package Ova_Cg.Attack_Dialog is

   package Checks renames FLTK.Widgets.Buttons.Light.Check;
   package Windows renames FLTK.Widgets.Groups.Windows.Double;
   package Multiline renames FLTK.Widgets.Inputs.Text.Multiline;

   type Window_Access is access all Windows.Double_Window'Class;
   type Check_Access is access all Checks.Check_Button'Class;
   type Multiline_Access is access all Multiline.Multiline_Input'Class;

   --  The Perks' or the Flaws' list and editor.
   type Mod_Panel is new Widgets.Panel with private;
   type Mod_Panel_Access is access all Mod_Panel'Class;

   --  The dialog's widgets, for tests; the dialog null when closed.
   function Dialog return Window_Access;
   function Name_In return Widgets.Input_Access;
   function Affinity_In return Widgets.Input_Access;
   function Description_In return Multiline_Access;
   function Telekinetic return Check_Access;
   function Transformed return Check_Access;
   function Perks return Mod_Panel_Access;
   function Flaws return Mod_Panel_Access;
   function Roll return Widgets.Number_Box_Access;
   function DX return Widgets.Number_Box_Access;
   function End_Box return Widgets.Number_Box_Access;
   function OK_Button return Widgets.Button_Access;
   function Cancel_Button return Widgets.Button_Access;

   --  Shows a message: the window's.
   type Tell_Handler is access procedure (Text : String);
   Tell : Tell_Handler;

   --  Called after OK (Changed True) or Cancel.
   type Done_Handler is access procedure (Changed : Boolean);

   --  Edits A, an attack of C; Is_New if the window has just added it,
   --  so that Cancel takes it out again, and frees it.
   procedure Edit_Attack (C : not null Character.Character_Access; A : not null Character.Attack;
                          Is_New : Boolean; Done : Done_Handler)
     with Pre => Dialog = null;

   --  Edits T's Perks and Flaws, and its END: an Ability of C.
   procedure Edit_Mods (C : not null Character.Character_Access; T : not null Character.Trait;
                        Done : Done_Handler)
     with Pre => Dialog = null;

   --  For tests: OK and Cancel, as if pushed.
   procedure OK with Pre => Dialog /= null;
   procedure Cancel with Pre => Dialog /= null;

   --  Frees the closed dialogs now, not from the timeout that closing
   --  one sets: for the window's Close, which runs under no dialog's
   --  callback.
   procedure Free_Closed;

private

   package Modifier_Vectors is
     new Ada.Containers.Vectors (Positive, Character.Modifier, Character."=");

   type Mod_Panel is new Widgets.Panel with record
      Is_Flaw : Boolean := False;
      Shown   : Modifier_Vectors.Vector;  --  Shown (I): line I's
   end record;

   overriding procedure Fill (P : in out Mod_Panel);
   overriding procedure Load (P : in out Mod_Panel; Line : Positive);
   overriding function Add (P : in out Mod_Panel) return Natural;
   overriding function Change (P : in out Mod_Panel; Line : Positive) return Natural;
   overriding function Remove (P : in out Mod_Panel; Line : Positive) return Boolean;
   overriding procedure Chosen (P : in out Mod_Panel);

end Ova_Cg.Attack_Dialog;
