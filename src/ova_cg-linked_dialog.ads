--  An Ability's linked content: a Transformation's form, a Magic's
--  spells, a Companion or Vehicle.
--
--  ova_cg_po's PLAN.md, "The window": an Ability with linked content
--  has a button that opens this dialog, in one of three shapes
--  (Rules.Item_Record.Linked):
--
--  - Form, a Transformation's (p. 63): the form's Abilities and
--    Weaknesses, worth 2 levels a level of Transformation, each line
--    with its page; the selected Ability's Perks and Flaws and END.
--  - Spells, a Magic's (p. 57-58): each spell's name, the Ability it
--    mimics, its level, and its END, computed from the Magic's level
--    and its own, with an override box.  Witchcraft's spells are
--    curses: the Weakness each casts, at -1 to -3 (p. 58;
--    Rules.Casts_Weaknesses).
--  - A partner's sheet, a Companion's (p. 52) or a Vehicle's (p. 64):
--    its name, whether it is a Fragment, whether it has combat stats,
--    its Abilities and Weaknesses, its attacks (edited in the attack
--    dialog) and its numbers, each with its override box.
--
--  It edits the model as the user works, as the window's first tab
--  does, and has Close, no Cancel: a change is in the character at
--  once, and Changed (the window's) recomputes it and shows it.  It is
--  modal but doesn't wait: Edit shows it, and Close calls Done.  Once
--  closed, its widgets are freed from a timeout, never inside their
--  own callbacks (AGENTS.md).

with FLTK.Widgets.Boxes;
with FLTK.Widgets.Buttons.Light.Check;
with FLTK.Widgets.Groups.Windows.Double;
with Ova_Cg.Character;
with Ova_Cg.Rules;
with Ova_Cg.Trait_Panel;
with Ova_Cg.Widgets;

package Ova_Cg.Linked_Dialog is

   package Boxes renames FLTK.Widgets.Boxes;
   package Checks renames FLTK.Widgets.Buttons.Light.Check;
   package Windows renames FLTK.Widgets.Groups.Windows.Double;

   type Window_Access is access all Windows.Double_Window'Class;
   type Check_Access is access all Checks.Check_Button'Class;
   type Box_Access is access all Boxes.Box'Class;

   --  A partner's numbers, each with its box.
   type Sheet_Number is
     (Defense_Number, Barrier_Number, Health_Number, Endurance_Number, Reserve_Number, TV_Number,
      Incorporeal_Number);

   --  The dialog's widgets, for tests; the dialog null when closed, and
   --  each null where its shape has none.
   function Dialog return Window_Access;
   function Mode return Rules.Link;          --  Form, Spells, Partner or Machine
   function Info return Box_Access;          --  what the dialog edits, and the form's levels
   function Close_Button return Widgets.Button_Access;

   --  A form's, or a partner's:
   function Abilities return Trait_Panel.Trait_Panel_Access;
   function Weaknesses return Trait_Panel.Trait_Panel_Access;
   function Mods_Button return Widgets.Button_Access;  --  the selected Ability's Perks and Flaws
   function End_Box return Widgets.Number_Box_Access;  --  its END

   --  A Magic's:
   function Spells return Widgets.Browser_Access;
   function Spell_Name return Widgets.Input_Access;
   function Spell_Ability return Widgets.Choice_Access;
   function Spell_Level return Widgets.Spinner_Access;
   function Spell_Help return Widgets.Help_Button_Access;
   function Add_Spell_Button return Widgets.Button_Access;
   function Change_Spell_Button return Widgets.Button_Access;
   function Remove_Spell_Button return Widgets.Button_Access;
   function Spell_End return Widgets.Number_Box_Access;
   function Cast_Kind return Rules.Kind;  --  what the spells mimic: Ability, or Weakness for Witchcraft

   --  A partner's:
   function Partner_Name return Widgets.Input_Access;
   function Fragment return Check_Access;
   function Combat return Check_Access;
   function Attacks return Widgets.Browser_Access;
   function Add_Attack_Button return Widgets.Button_Access;
   function Edit_Attack_Button return Widgets.Button_Access;
   function Remove_Attack_Button return Widgets.Button_Access;
   function Number (Which : Sheet_Number) return Widgets.Number_Box_Access;

   --  Set by the window: recomputes the character and shows it, after
   --  every change made here.
   type Changed_Handler is access procedure;
   Changed : Changed_Handler;

   --  Shows a message: the window's.
   type Tell_Handler is access procedure (Text : String);
   Tell : Tell_Handler;

   --  Called on Close.
   type Done_Handler is access procedure;

   --  Edits T's linked content, T an Ability of C (or of its form, or
   --  its partner's).  A Companion or Vehicle gets its sheet now if it
   --  has none.
   procedure Edit (C : not null Character.Character_Access; T : not null Character.Trait;
                   Done : Done_Handler)
     with Pre => Dialog = null and then Rules."/=" (T.Item, null)
                 and then Rules."/=" (T.Item.Linked, Rules.No_Link);

   --  For tests and the window: Close, as if pushed, though the attack
   --  dialog is open.
   procedure Close with Pre => Dialog /= null;

   --  Frees the closed dialogs now, not from the timeout that closing
   --  one sets: for the window's Close, which runs under no dialog's
   --  callback.
   procedure Free_Closed;

end Ova_Cg.Linked_Dialog;
