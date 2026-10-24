with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ova_Cg.Rules;

package body Ova_Cg.Viewer is

   --  The rulebook where it is looked for last, under the home
   --  directory.
   Default_Rulebook : constant String := "/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf";

   --  okular's interface, and its main window's object.
   Okular_Iface : constant String := "org.kde.okular";
   Okular_Shell : constant String := "/okularshell";
   --  The most tabs of one okular looked through.
   Max_Tabs : constant := 50;

   --  The mupdf this program started last.
   Last_Mupdf_Process : Spawn.Process;

   function Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (N'Image, Ada.Strings.Left));

   --  ---- The PDF ----

   --  Path, made absolute against the working directory: okular is
   --  asked which tab shows it, and the viewers given it are run
   --  elsewhere.
   function Absolute (Path : String) return String is
   begin
      if Path /= "" and then Path (Path'First) /= '/' then
         return Ada.Directories.Current_Directory & "/" & Path;
      else
         return Path;
      end if;
   end Absolute;

   function Exists (Path : String) return Boolean is
     (Path /= "" and then Ada.Directories.Exists (Path));

   function Choose (Option, Env, Saved, Home : String; Path : out Unbounded_String)
     return Boolean is
   begin
      if Option /= "" then
         Path := To_Unbounded_String (Option);
      elsif Env /= "" then
         Path := To_Unbounded_String (Env);
      elsif Saved /= "" then
         Path := To_Unbounded_String (Saved);
      else
         Path := To_Unbounded_String (Home & Default_Rulebook);
      end if;
      Path := To_Unbounded_String (Absolute (To_String (Path)));
      return Exists (To_String (Path));
   end Choose;

   function Find_Rulebook (Option, Saved : String; Path : out Unbounded_String) return Boolean is
      use Ada.Environment_Variables;
   begin
      return Choose (Option, Value ("OVA_RULEBOOK", ""), Saved, Value ("HOME", ""), Path);
   end Find_Rulebook;

   --  ---- Viewers ----

   function Kind (V : Viewer_Type) return Kind_Type is (V.Kind);

   procedure Default (V : out Viewer_Type) is
   begin
      V.Template := Null_Unbounded_String;
      if Spawn.On_Path (To_String (Okular_Program)) then
         V.Kind := Okular;
      elsif Spawn.On_Path (To_String (Evince_Program)) then
         V.Kind := Evince;
      elsif Spawn.On_Path (To_String (Mupdf_Program)) then
         V.Kind := Mupdf;
      else
         V.Kind := Xdg_Open;
      end if;
   end Default;

   Blanks : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.LF & ASCII.CR);

   function Parse (S : String; V : in out Viewer_Type) return Boolean is
      T : constant String := Ada.Strings.Fixed.Trim (S, Blanks, Blanks);
   begin
      if T = "okular" then
         V := (Okular, Null_Unbounded_String);
      elsif T = "evince" then
         V := (Evince, Null_Unbounded_String);
      elsif T = "mupdf" then
         V := (Mupdf, Null_Unbounded_String);
      elsif T = "xdg-open" then
         V := (Xdg_Open, Null_Unbounded_String);
      elsif Ada.Strings.Fixed.Index (T, "%f") > 0 then
         V := (Template, To_Unbounded_String (T));
      else
         return False;
      end if;
      return True;
   end Parse;

   function Name (V : Viewer_Type) return String is
     (case V.Kind is
         when Okular   => "okular",
         when Evince   => "evince",
         when Mupdf    => "mupdf",
         when Xdg_Open => "xdg-open",
         when Template => To_String (V.Template));

   --  Adds the words of Template to A, each with %f, %p, %l and %%
   --  replaced by Pdf, Index, Label and %, the replacement staying
   --  within its word however many blanks it holds.
   procedure Add_Template (A : in out Spawn.Args; Template, Pdf : String; Index, Label : Integer) is
      I       : Positive := Template'First;
      Ch      : Standard.Character;
      Next    : Standard.Character;
      Word    : Unbounded_String;
      In_Word : Boolean := False;
   begin
      while I <= Template'Last + 1 loop
         Ch := (if I <= Template'Last then Template (I) else ' ');
         if Ch = ' ' or else Ch = ASCII.HT then
            if In_Word then
               Spawn.Add (A, Word);
               Word := Null_Unbounded_String;
               In_Word := False;
            end if;
         else
            In_Word := True;
            Next := (if Ch = '%' and then I < Template'Last then Template (I + 1) else ASCII.NUL);
            case Next is
               when 'f' =>
                  Append (Word, Pdf);
                  I := I + 1;
               when 'p' =>
                  Append (Word, Image (Index));
                  I := I + 1;
               when 'l' =>
                  Append (Word, Image (Label));
                  I := I + 1;
               when '%' =>
                  Append (Word, '%');
                  I := I + 1;
               when others =>
                  Append (Word, Ch);
            end case;
         end if;
         I := I + 1;
      end loop;
   end Add_Template;

   procedure Command (V : Viewer_Type; Pdf : String; Page : Positive; A : out Spawn.Args) is
      Index : constant String := Image (Rules.Pdf_Index (Page));
   begin
      Spawn.Clear (A);
      case V.Kind is
         when Okular =>
            Spawn.Add (A, Okular_Program);
            Spawn.Add (A, "--unique");
            Spawn.Add (A, "-p");
            Spawn.Add (A, Index);
            Spawn.Add (A, Pdf);
         when Evince =>
            Spawn.Add (A, Evince_Program);
            Spawn.Add (A, "-i");
            Spawn.Add (A, Index);
            Spawn.Add (A, Pdf);
         when Mupdf =>
            Spawn.Add (A, Mupdf_Program);
            Spawn.Add (A, Pdf);
            Spawn.Add (A, Index);
         when Xdg_Open =>
            Spawn.Add (A, Xdg_Open_Program);
            Spawn.Add (A, Pdf);
         when Template =>
            Add_Template (A, To_String (V.Template), Pdf, Rules.Pdf_Index (Page), Page);
      end case;
   end Command;

   --  ---- okular, over D-Bus ----

   Hex : constant String := "0123456789ABCDEF";

   function File_Url (Pdf : String) return String is
      R : Unbounded_String := To_Unbounded_String ("file://");
   begin
      for Ch of Pdf loop
         if Ch >= ' ' and then Ch /= ASCII.DEL and then Ch /= '%' and then Ch /= '#' and then Ch /= '?' then
            Append (R, Ch);
         else
            Append (R, '%');
            Append (R, Hex (Hex'First + Standard.Character'Pos (Ch) / 16));
            Append (R, Hex (Hex'First + Standard.Character'Pos (Ch) mod 16));
         end if;
      end loop;
      return To_String (R);
   end File_Url;

   --  The value of hex digit Ch, -1 if it isn't one.
   function Hex_Digit (Ch : Standard.Character) return Integer is
     (case Ch is
         when '0' .. '9' => Standard.Character'Pos (Ch) - Standard.Character'Pos ('0'),
         when 'A' .. 'F' => Standard.Character'Pos (Ch) - Standard.Character'Pos ('A') + 10,
         when 'a' .. 'f' => Standard.Character'Pos (Ch) - Standard.Character'Pos ('a') + 10,
         when others => -1);

   --  Doc as a path: a file: URL's path, percent-decoded; anything else
   --  as it is.
   function Doc_Path (Doc : String) return String is
      Prefix : constant String := "file://";
      R      : Unbounded_String;
      I      : Positive := Doc'First + Prefix'Length;
      Hi, Lo : Integer;
   begin
      if Doc'Length < Prefix'Length or else Doc (Doc'First .. Doc'First + Prefix'Length - 1) /= Prefix then
         return Doc;
      end if;
      while I <= Doc'Last loop
         Hi := -1;
         Lo := -1;
         if Doc (I) = '%' and then I + 2 <= Doc'Last then
            Hi := Hex_Digit (Doc (I + 1));
            Lo := Hex_Digit (Doc (I + 2));
         end if;
         if Hi >= 0 and then Lo >= 0 then
            Append (R, Standard.Character'Val (Hi * 16 + Lo));
            I := I + 3;
         else
            Append (R, Doc (I));
            I := I + 1;
         end if;
      end loop;
      return To_String (R);
   end Doc_Path;

   --  The first string in Output from position From on, gdbus's print
   --  of a GVariant tuple, such as ('/a/b.pdf',) or ("/an O'Brien.pdf",):
   --  quoted by ' or ", with \ escapes.  Next is where to look for the
   --  one after.  "", OK False, if there is none.
   function First_String (Output : String; From : Positive; Next : out Positive; OK : out Boolean)
     return String
   is
      R  : Unbounded_String;
      I  : Positive := From;
      Q  : Standard.Character;
      Ch : Standard.Character;
   begin
      OK := False;
      while I <= Output'Last and then Output (I) /= ''' and then Output (I) /= '"' loop
         I := I + 1;
      end loop;
      if I <= Output'Last then
         Q := Output (I);
         I := I + 1;
         while I <= Output'Last and then Output (I) /= Q loop
            Ch := Output (I);
            if Ch = '\' and then I < Output'Last then
               I := I + 1;
               Ch := Output (I);
               if Ch = 'n' then
                  Ch := ASCII.LF;
               elsif Ch = 't' then
                  Ch := ASCII.HT;
               end if;
            end if;
            Append (R, Ch);
            I := I + 1;
         end loop;
         OK := I <= Output'Last;
         I := I + 1;
      end if;
      Next := I;
      return To_String (R);
   end First_String;

   --  In A, a gdbus call on the session bus to Dest's object Obj, its
   --  method Method (interface and name); the caller adds the method's
   --  arguments.
   procedure Gdbus_Call (A : out Spawn.Args; Dest, Obj, Method : String) is
   begin
      Spawn.Clear (A);
      Spawn.Add (A, Gdbus_Program);
      Spawn.Add (A, "call");
      Spawn.Add (A, "--session");
      Spawn.Add (A, "--timeout");
      Spawn.Add (A, "5");
      Spawn.Add (A, "--dest");
      Spawn.Add (A, Dest);
      Spawn.Add (A, "--object-path");
      Spawn.Add (A, Obj);
      Spawn.Add (A, "--method");
      Spawn.Add (A, Method);
   end Gdbus_Call;

   --  Whether Name is an okular's on the bus: org.kde.okular (started
   --  --unique) or org.kde.okular-PID; not its Instance_ alias.
   function Is_Okular (Name : String) return Boolean is
      Prefix : constant String := Okular_Iface & "-";
   begin
      if Name = Okular_Iface then
         return True;
      elsif Name'Length <= Prefix'Length
        or else Name (Name'First .. Name'First + Prefix'Length - 1) /= Prefix
      then
         return False;
      end if;
      return (for all Ch of Name (Name'First + Prefix'Length .. Name'Last) => Ch in '0' .. '9');
   end Is_Okular;

   --  Tab number Tab's object in an okular: /okular, /okular2, ...
   function Tab_Object (Tab : Positive) return String is
     ("/okular" & (if Tab > 1 then Image (Tab) else ""));

   --  Capture of A: whether it started and exited 0, its output in
   --  Output.
   function Succeeds (A : Spawn.Args; Output : out Unbounded_String) return Boolean is
      Status : Integer;
   begin
      return Spawn.Capture (A, Output, Status) = 0 and then Status = 0;
   end Succeeds;

   --  Looks through every okular on the session bus for a tab showing
   --  Pdf; if one does, brings it forward and turns it to page Index.
   --  Whether one did.
   function Okular_Turn (Pdf : String; Index : Positive) return Boolean is
      A        : Spawn.Args;
      Output   : Unbounded_String;
      Names    : Unbounded_String;
      Dest     : Unbounded_String;
      Obj      : Unbounded_String;
      Pos      : Positive := 1;
      Tab      : Positive;
      OK, More : Boolean := True;
      Found    : Boolean := False;
   begin
      Gdbus_Call (A, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus.ListNames");
      if Succeeds (A, Names) then
         while More and then not Found loop
            declare
               Name : constant String := First_String (To_String (Names), Pos, Pos, More);
            begin
               if More and then Is_Okular (Name) then
                  Tab := 1;
                  loop
                     Obj := To_Unbounded_String (Tab_Object (Tab));
                     Gdbus_Call (A, Name, To_String (Obj), "org.kde.okular.currentDocument");
                     OK := Succeeds (A, Output);
                     if OK then
                        declare
                           After : Positive;
                           Doc   : constant String := First_String (To_String (Output), 1, After, OK);
                        begin
                           if OK and then Doc_Path (Doc) = Pdf then
                              Found := True;
                              Dest := To_Unbounded_String (Name);
                           end if;
                        end;
                     end if;
                     Tab := Tab + 1;
                     exit when not OK or else Found or else Tab > Max_Tabs;
                  end loop;
               end if;
            end;
         end loop;
      end if;
      if Found then
         --  openDocument of a file open in a tab brings that tab forward
         --  (no new tab); then the tab turns to the page.
         Gdbus_Call (A, To_String (Dest), Okular_Shell, "org.kde.okular.openDocument");
         Spawn.Add (A, File_Url (Pdf));
         Found := Succeeds (A, Output);
         if Found then
            Gdbus_Call (A, To_String (Dest), To_String (Obj), "org.kde.okular.goToPage");
            Spawn.Add (A, Image (Index));
            Found := Succeeds (A, Output);
         end if;
      end if;
      return Found;
   end Okular_Turn;

   --  ---- Opening ----

   function Open (V : Viewer_Type; Pdf : String; Page : Positive; Msg : out Unbounded_String)
     return Boolean
   is
      A     : Spawn.Args;
      P     : Spawn.Process;
      Err   : Integer := 0;
      Index : constant Positive := Rules.Pdf_Index (Page);
   begin
      Msg := Null_Unbounded_String;
      if V.Kind = Okular and then Okular_Turn (Pdf, Index) then
         null;  --  turned over D-Bus; without gdbus, Okular_Turn is False
      else
         Command (V, Pdf, Page, A);
         if V.Kind = Mupdf then
            End_Mupdf;
            Err := Spawn.Detached (A, Last_Mupdf_Process);
         else
            Err := Spawn.Detached (A, P);
         end if;
         if Err /= 0 then
            Msg := To_Unbounded_String ("can't start " & Spawn.Arg (A, 0) & ": " & Spawn.Error_Text (Err));
         elsif V.Kind = Xdg_Open then
            Msg := To_Unbounded_String
              ("xdg-open can't turn to a page: turn to page " & Image (Page)
               & " (the PDF's page " & Image (Index) & ")");
         end if;
      end if;
      return Err = 0;
   end Open;

   procedure End_Mupdf is
      Ended : constant Boolean := Spawn.Terminate_Process (Last_Mupdf_Process) with Unreferenced;
   begin
      null;
   end End_Mupdf;

   function Last_Mupdf return Integer is
     (if Spawn.Alive (Last_Mupdf_Process) then Spawn.Pid (Last_Mupdf_Process) else 0);

end Ova_Cg.Viewer;
