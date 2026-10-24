with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Ova_Cg.Paths is

   package Part_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
   subtype Parts is Part_Vectors.Vector;

   use type Ada.Containers.Count_Type;

   --  Path's parts between "/"s, without empty ones and ".", each ".."
   --  taking out the part before it (one at the start of an absolute
   --  path is dropped; of a relative one, kept).
   function Split (Path : String) return Parts is
      P     : Parts;
      Start : Positive := Path'First;
      I     : Natural;
      Abs_Path : constant Boolean := Is_Absolute (Path);
   begin
      while Start <= Path'Last + 1 loop
         I := Start;
         while I <= Path'Last and then Path (I) /= '/' loop
            I := I + 1;
         end loop;
         declare
            Part : constant String := Path (Start .. I - 1);
         begin
            if Part = "" or else Part = "." then
               null;
            elsif Part = ".." and then P.Length > 0 and then P.Last_Element /= ".." then
               P.Delete_Last;
            elsif Part = ".." and then Abs_Path then
               null;
            else
               P.Append (Part);
            end if;
         end;
         Start := I + 1;
      end loop;
      return P;
   end Split;

   --  P (From ..) joined by "/", after "/" if Abs_Path.
   function Join (P : Parts; From : Positive; Abs_Path : Boolean) return String is
      R : Unbounded_String := (if Abs_Path then To_Unbounded_String ("/") else Null_Unbounded_String);
   begin
      for I in From .. P.Last_Index loop
         if I > From then
            Append (R, '/');
         end if;
         Append (R, P (I));
      end loop;
      return To_String (R);
   end Join;

   function Normalize (Path : String) return String is
      R : constant String := Join (Split (Path), 1, Is_Absolute (Path));
   begin
      return (if R = "" then "." else R);
   end Normalize;

   function Absolute (Path : String; Base : String := "") return String is
   begin
      if Path = "" then
         return "";
      elsif Is_Absolute (Path) then
         return Normalize (Path);
      elsif Is_Absolute (Base) then
         return Normalize (Base & "/" & Path);
      elsif Base = "" then
         return Normalize (Ada.Directories.Current_Directory & "/" & Path);
      else
         return Normalize (Ada.Directories.Current_Directory & "/" & Base & "/" & Path);
      end if;
   end Absolute;

   function Dir (File : String) return String is
      A : constant String := Absolute (File);
   begin
      for I in reverse A'Range loop
         if A (I) = '/' then
            return (if I = A'First then "/" else A (A'First .. I - 1));
         end if;
      end loop;
      return "/";
   end Dir;

   function Relative (Path, In_Dir : String) return String is
      P : constant Parts := Split (Absolute (Path));
      D : constant Parts := Split (Absolute (In_Dir));
      K : Natural := 0;  --  how many parts the two share
      R : Unbounded_String;
   begin
      while K < Natural (P.Length) and then K < Natural (D.Length) and then P (K + 1) = D (K + 1) loop
         K := K + 1;
      end loop;
      for I in K + 1 .. D.Last_Index loop
         if R /= Null_Unbounded_String then
            Append (R, '/');
         end if;
         Append (R, "..");
      end loop;
      if K < Natural (P.Length) then
         if R /= Null_Unbounded_String then
            Append (R, '/');
         end if;
         Append (R, Join (P, K + 1, False));
      end if;
      return (if R = Null_Unbounded_String then "." else To_String (R));
   end Relative;

   function Rebase (Path, From, To : String) return String is
   begin
      if Path = "" then
         return "";
      elsif From = "" and then not Is_Absolute (Path) then
         return Path;
      else
         return Relative (Absolute (Path, From), To);
      end if;
   end Rebase;

end Ova_Cg.Paths;
