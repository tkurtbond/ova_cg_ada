--  Ova_Cg.Viewer: the rulebook's path, the viewers' commands, okular
--  over D-Bus.
--
--  Run from test/, as make test does, with fakes in the programs'
--  places: fake-viewer.sh for every viewer, recording its arguments in
--  ../obj/fake-viewer.log, and fake-gdbus.sh, answering from
--  ../obj/gdbus.scenario and logging its calls in ../obj/gdbus.log.
--  Every fake viewer started is ended by its pid, never by name.  The
--  real viewers are test/viewer.sh's, on a headless sway.  Needs no
--  display.

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Check;
with Ova_Cg.Rules;
with Ova_Cg.Spawn;
with Ova_Cg.Viewer; use Ova_Cg.Viewer;

procedure Test_Viewer is

   package Spawn renames Ova_Cg.Spawn;

   Fake       : constant String := "./fake-viewer.sh";
   Fake_Gdbus : constant String := "./fake-gdbus.sh";
   Missing    : constant String := "ova-cg-no-such-program";
   Viewer_Log : constant String := "../obj/fake-viewer.log";
   Gdbus_Log  : constant String := "../obj/gdbus.log";
   --  The PDF: blanks and a "'", which a shell would need quoted, and
   --  "#", "%" and "?", which a URL needs encoded; as okular's
   --  openDocument is given it, and as a URL encoded in full.
   Pdf        : constant String := "/tmp/an O'Brien #1 100% ?.pdf";
   Url        : constant String := "file:///tmp/an O'Brien %231 100%25 %3F.pdf";
   Full_Url   : constant String := "file:///tmp/an%20O%27Brien%20%231%20100%25%20%3F.pdf";
   Page       : constant := 60;  --  printed; the PDF's index is 62
   LF         : constant Standard.Character := Standard.Character'Val (10);

   V      : Viewer_Type;
   A      : Spawn.Args;
   Path   : Unbounded_String;
   Msg    : Unbounded_String;
   Log    : Unbounded_String;
   Want   : Unbounded_String;
   Pid    : Integer;
   First  : Integer;
   OK     : Boolean;

   function Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (N'Image, Ada.Strings.Left));

   --  Runs Cmd with sh, for setting up; whether it succeeded.
   function Sh (Cmd : String) return Boolean is
      C   : Spawn.Args;
      Out_Text : Unbounded_String;
      St  : Integer;
   begin
      Spawn.Add (C, "sh");
      Spawn.Add (C, "-c");
      Spawn.Add (C, Cmd);
      return Spawn.Capture (C, Out_Text, St) = 0 and then St = 0;
   end Sh;

   --  The text of file Name; "" if it can't be read.
   function Contents (Name : String) return Unbounded_String is
      C  : Spawn.Args;
      R  : Unbounded_String;
      St : Integer;
   begin
      Spawn.Add (C, "cat");
      Spawn.Add (C, Name);
      if Spawn.Capture (C, R, St) /= 0 or else St /= 0 then
         R := Null_Unbounded_String;
      end if;
      return R;
   end Contents;

   procedure Remove (Name : String) is
   begin
      if Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_File (Name);
      end if;
   end Remove;

   --  Removes the logs, before a case.
   procedure Reset is
   begin
      Remove (Viewer_Log);
      Remove (Gdbus_Log);
   end Reset;

   --  The fake viewer's record, once written (up to 5 s); "" if none
   --  was.
   function Viewer_Record return Unbounded_String is
      N : Natural := 0;
   begin
      while not Ada.Directories.Exists (Viewer_Log) and then N < 100 loop
         delay 0.05;
         N := N + 1;
      end loop;
      return Contents (Viewer_Log);
   end Viewer_Record;

   --  The record's arguments, one "<A>" each, joined by blanks: what
   --  started the fake viewer.
   function Args_Of (Rec : Unbounded_String) return String is
      R        : Unbounded_String;
      Pos      : Natural := Index (Rec, "arg <");
      Line_End : Natural;
   begin
      while Pos > 0 loop
         Line_End := Index (Rec, [LF], Pos);
         if Line_End = 0 then
            Line_End := Length (Rec) + 1;
         end if;
         if R /= Null_Unbounded_String then
            Append (R, ' ');
         end if;
         Append (R, Slice (Rec, Pos + 4, Line_End - 1));
         Pos := (if Line_End > Length (Rec) then 0 else Index (Rec, "arg <", Line_End));
      end loop;
      return To_String (R);
   end Args_Of;

   --  The record's pid, -1 if none.
   function Pid_Of (Rec : Unbounded_String) return Integer is
      Pos : Natural := Index (Rec, "pid ");
      N   : Integer := -1;
   begin
      --  "ppid " comes first; the pid line starts a line.
      while Pos > 1 and then Element (Rec, Pos - 1) /= LF loop
         Pos := (if Pos + 1 > Length (Rec) then 0 else Index (Rec, "pid ", Pos + 1));
      end loop;
      if Pos > 0 then
         Pos := Pos + 4;
         N := 0;
         while Pos <= Length (Rec) and then Element (Rec, Pos) in '0' .. '9' loop
            N := N * 10 + Standard.Character'Pos (Element (Rec, Pos)) - Standard.Character'Pos ('0');
            Pos := Pos + 1;
         end loop;
      end if;
      return N;
   end Pid_Of;

   --  Ends the fake viewer Pid, by its pid.
   procedure Kill (Pid : Integer) is
      C        : Spawn.Args;
      Out_Text : Unbounded_String;
      St       : Integer;
   begin
      if Pid > 0 then
         Spawn.Add (C, "kill");
         Spawn.Add (C, Image (Pid));
         if Spawn.Capture (C, Out_Text, St) = 0 then
            null;
         end if;
      end if;
   end Kill;

   --  Waits up to 5 s for Pid to end; whether it did.
   function Gone (Pid : Integer) return Boolean is
      N : Natural := 0;
   begin
      while Spawn.Session (Pid) /= -1 and then N < 100 loop
         delay 0.05;
         N := N + 1;
      end loop;
      return Spawn.Session (Pid) = -1;
   end Gone;

   --  Whether no fake viewer starts within a second.
   function No_Viewer return Boolean is
   begin
      delay 1.0;
      return not Ada.Directories.Exists (Viewer_Log);
   end No_Viewer;

   --  Whether A's arguments, joined by blanks with each in <>, are
   --  Want.
   function Command_Is (A : Spawn.Args; Want : String) return Boolean is
      R : Unbounded_String;
   begin
      for I in 0 .. Spawn.Count (A) - 1 loop
         if I > 0 then
            Append (R, ' ');
         end if;
         Append (R, "<" & Spawn.Arg (A, I) & ">");
      end loop;
      return R = Want;
   end Command_Is;

   --  Appends S and a newline to R.
   procedure Line (R : in out Unbounded_String; S : String) is
   begin
      Append (R, S & LF);
   end Line;

   --  Adds a tab showing Doc, object Obj of okular Name, to the
   --  scenario.
   procedure Tab (Name, Obj, Doc : String) is
      C        : Spawn.Args;
      Out_Text : Unbounded_String;
      St       : Integer;
   begin
      Spawn.Add (C, "sh");
      Spawn.Add (C, "-c");
      Spawn.Add (C, "printf ""%s\t%s\t%s\n"" ""$1"" ""$2"" ""$3"" >> ../obj/gdbus.scenario");
      Spawn.Add (C, "sh");
      Spawn.Add (C, Name);
      Spawn.Add (C, Obj);
      Spawn.Add (C, Doc);
      if Spawn.Capture (C, Out_Text, St) = 0 then
         null;
      end if;
   end Tab;

   --  Empties the scenario: no okular on the bus.
   procedure No_Tabs is
   begin
      if Sh (": > ../obj/gdbus.scenario") then
         null;
      end if;
   end No_Tabs;

   --  Opens Page of Pdf in V, which must start the fake viewer with
   --  Args; ends it after.
   procedure Starts (V : Viewer_Type; Args, Label : String) is
      Rec : Unbounded_String;
      Msg : Unbounded_String;
      OK  : Boolean;
   begin
      Reset;
      OK := Open (V, Pdf, Page, Msg) and then Msg = "";
      Rec := Viewer_Record;
      Check.Check (OK and then Args_Of (Rec) = Args, Label);
      Kill (Pid_Of (Rec));
   end Starts;

   procedure Use_Fakes is
   begin
      Okular_Program := To_Unbounded_String (Fake);
      Evince_Program := To_Unbounded_String (Fake);
      Mupdf_Program := To_Unbounded_String (Fake);
   end Use_Fakes;

begin
   Use_Fakes;
   Xdg_Open_Program := To_Unbounded_String (Fake);
   Gdbus_Program := To_Unbounded_String (Fake_Gdbus);

   --  ---- The PDF ----
   OK := not Choose ("/no/such/a.pdf", "/env.pdf", "/saved.pdf", "/home/u", Path);
   Check.Check (OK and then Path = "/no/such/a.pdf", "Choose: --rulebook first; FALSE when it isn't there");
   OK := not Choose ("", "/env.pdf", "/saved.pdf", "/home/u", Path);
   Check.Check (OK and then Path = "/env.pdf", "Choose: then OVA_RULEBOOK");
   OK := not Choose ("", "", "/saved.pdf", "/home/u", Path);
   Check.Check (OK and then Path = "/saved.pdf", "Choose: then the saved path");
   OK := not Choose ("", "", "", "/home/u", Path);
   Check.Check (OK and then Path = "/home/u/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf",
                "Choose: then the default under the home directory");
   OK := Choose ("fake-viewer.sh", "", "", "", Path);
   Check.Check (OK and then Path = Ada.Directories.Current_Directory & "/fake-viewer.sh",
                "Choose: a relative path is made absolute; TRUE for a file there");

   --  ---- Viewers ----
   OK := Parse (" okular ", V) and then Kind (V) = Okular
     and then Parse ("evince", V) and then Kind (V) = Evince
     and then Parse ("mupdf", V) and then Kind (V) = Mupdf
     and then Parse ("xdg-open", V) and then Kind (V) = Xdg_Open
     and then Name (V) = "xdg-open";
   Check.Check (OK, "Parse: the viewers' names, and Name");
   OK := Parse ("zathura -P %p %f", V) and then Kind (V) = Template
     and then Name (V) = "zathura -P %p %f";
   Check.Check (OK, "Parse: a command template");
   Check.Check (not Parse ("zathura", V) and then not Parse ("", V)
                and then Kind (V) = Template,
                "Parse: a name it doesn't know, a template without %f, nothing: FALSE");

   Okular_Program := To_Unbounded_String (Missing);
   Default (V);
   Check.Check (Kind (V) = Evince, "Default: evince when okular isn't on PATH");
   Evince_Program := To_Unbounded_String (Missing);
   Mupdf_Program := To_Unbounded_String (Missing);
   Default (V);
   Check.Check (Kind (V) = Xdg_Open, "Default: xdg-open when none is");
   Use_Fakes;
   Default (V);
   Check.Check (Kind (V) = Okular, "Default: okular first");

   OK := Parse ("view  --page=%p %f%% -l %l x%q %", V);
   Command (V, Pdf, Page, A);
   Check.Check (OK and then Command_Is (A, "<view> <--page=62> </tmp/an O'Brien #1 100% ?.pdf%> <-l> <60> <x%q> <%>"),
                "Command: a template's words, each substitution within its word");
   Check.Check (Ova_Cg.Rules.Pdf_Index (Page) = 62, "the PDF's index of printed page 60 is 62");
   Check.Check (File_Url (Pdf) = Url, "FileUrl: only %, # and ? encoded");

   --  ---- Starting each ----
   OK := Parse ("evince", V);
   Starts (V, "<-i> <62> </tmp/an O'Brien #1 100% ?.pdf>", "evince: -i INDEX PDF");
   OK := Parse ("./fake-viewer.sh -P %l %f", V);
   Starts (V, "<-P> <60> </tmp/an O'Brien #1 100% ?.pdf>", "a template runs as given");

   OK := Parse ("xdg-open", V);
   Reset;
   OK := Open (V, Pdf, Page, Msg);
   Log := Viewer_Record;
   Check.Check (OK and then Args_Of (Log) = "</tmp/an O'Brien #1 100% ?.pdf>"
                and then Msg = "xdg-open can't turn to a page: turn to page 60 (the PDF's page 62)",
                "xdg-open: PDF, and a message giving the page");
   Kill (Pid_Of (Log));

   Evince_Program := To_Unbounded_String (Missing);
   OK := Parse ("evince", V) and then not Open (V, Pdf, Page, Msg);
   Check.Check (OK and then Msg = "can't start ova-cg-no-such-program: No such file or directory",
                "a missing viewer: FALSE, and why");
   Evince_Program := To_Unbounded_String (Fake);

   --  ---- mupdf: the last one replaced ----
   OK := Parse ("mupdf", V);
   Reset;
   OK := Open (V, Pdf, Page, Msg) and then Msg = "";
   Log := Viewer_Record;
   First := Pid_Of (Log);
   Check.Check (OK and then Args_Of (Log) = "</tmp/an O'Brien #1 100% ?.pdf> <62>"
                and then First > 0 and then Last_Mupdf = First, "mupdf: PDF INDEX");
   Reset;
   OK := Open (V, Pdf, Page + 1, Msg);
   Log := Viewer_Record;
   Pid := Pid_Of (Log);
   Check.Check (OK and then Gone (First) and then Pid > 0 and then Pid /= First and then Last_Mupdf = Pid
                and then Args_Of (Log) = "</tmp/an O'Brien #1 100% ?.pdf> <63>",
                "mupdf: the one started before is ended, the next started");
   End_Mupdf;
   Check.Check (Gone (Pid) and then Last_Mupdf = 0, "EndMupdf: ends the last");

   --  ---- okular over D-Bus ----
   OK := Parse ("okular", V);
   --  Two okulars, the second showing the PDF in its second tab; an
   --  Instance_ alias and a name not okular's, which mustn't be asked.
   No_Tabs;
   Tab ("org.kde.okular.Instance_1", "/okular", Pdf);
   Tab ("org.kde.okularx", "/okular", Pdf);
   Tab ("org.kde.okular-100", "/okular", "/tmp/other.pdf");
   Tab ("org.kde.okular-200", "/okular", "/tmp/x.pdf");
   Tab ("org.kde.okular-200", "/okular2", Pdf);
   Tab ("org.kde.okular-200", "/okular3", "/tmp/y.pdf");
   Reset;
   OK := Open (V, Pdf, Page, Msg) and then Msg = "";
   Want := Null_Unbounded_String;
   Line (Want, "org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames");
   Line (Want, "org.kde.okular-100 /okular org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular-100 /okular2 org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular-200 /okular org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular-200 /okular2 org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular-200 /okularshell org.kde.okular.openDocument <file:///tmp/an O'Brien %231 100%25 %3F.pdf>");
   Line (Want, "org.kde.okular-200 /okular2 org.kde.okular.goToPage <62>");
   Check.Check (OK and then Contents (Gdbus_Log) = Want,
                "okular: the tab showing the PDF found, brought forward and turned, over D-Bus");
   Check.Check (No_Viewer, "okular: none started when one shows the PDF");

   --  The tab's document as a file: URL.
   No_Tabs;
   Tab ("org.kde.okular", "/okular", Full_Url);
   Reset;
   OK := Open (V, Pdf, Page, Msg) and then Msg = "";
   Want := Null_Unbounded_String;
   Line (Want, "org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames");
   Line (Want, "org.kde.okular /okular org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular /okularshell org.kde.okular.openDocument <file:///tmp/an O'Brien %231 100%25 %3F.pdf>");
   Line (Want, "org.kde.okular /okular org.kde.okular.goToPage <62>");
   Check.Check (OK and then Contents (Gdbus_Log) = Want,
                "okular: a document given as a file: URL is found, in an okular started --unique");
   Check.Check (No_Viewer, "okular: none started");

   --  An okular, but not showing the PDF: one is started.
   No_Tabs;
   Tab ("org.kde.okular-100", "/okular", "/tmp/other.pdf");
   Tab ("org.kde.okular-100", "/okular2", "/tmp/an O'Brien #1 100% ?.pdf.bak");
   Starts (V, "<--unique> <-p> <62> </tmp/an O'Brien #1 100% ?.pdf>", "okular: started when none shows the PDF");
   Want := Null_Unbounded_String;
   Line (Want, "org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames");
   Line (Want, "org.kde.okular-100 /okular org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular-100 /okular2 org.kde.okular.currentDocument");
   Line (Want, "org.kde.okular-100 /okular3 org.kde.okular.currentDocument");
   Check.Check (Contents (Gdbus_Log) = Want, "okular: every tab asked, up to the first missing");

   No_Tabs;
   Tab ("org.kde.okular-100", "/okular", Pdf);
   Gdbus_Program := To_Unbounded_String (Missing);
   Starts (V, "<--unique> <-p> <62> </tmp/an O'Brien #1 100% ?.pdf>", "okular: started --unique without gdbus");
   Gdbus_Program := To_Unbounded_String (Fake_Gdbus);

   Check.Summary;
end Test_Viewer;
