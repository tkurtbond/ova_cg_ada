
package body Ova_Cg.Spawn is

   use Interfaces;
   use type Interfaces.C.char;

   --  ova_cg_spawn.c's.  An out parameter of an elementary type is
   --  passed as a pointer (RM B.3 (68)), and a char_array as its first
   --  element's address.
   function C_Detached (Buf : C.char_array; N : Integer_32; Pid : out Integer_32)
     return Integer_32
     with Import, Convention => C, External_Name => "ova_cg_spawn_detached";
   function C_Capture (Buf : C.char_array; N : Integer_32; Fd, Pid : out Integer_32)
     return Integer_32
     with Import, Convention => C, External_Name => "ova_cg_spawn_capture";
   function C_Read (Fd : Integer_32; Buf : out C.char_array; Len : Integer_64) return Integer_64
     with Import, Convention => C, External_Name => "ova_cg_spawn_read";
   function C_Finish (Fd, Pid : Integer_32) return Integer_32
     with Import, Convention => C, External_Name => "ova_cg_spawn_finish";
   function C_Start_Time (Pid : Integer_32) return Integer_64
     with Import, Convention => C, External_Name => "ova_cg_spawn_start_time";
   function C_Terminate (Pid : Integer_32; Start : Integer_64) return Integer_32
     with Import, Convention => C, External_Name => "ova_cg_spawn_terminate";
   function C_On_Path (Name : C.char_array) return Integer_32
     with Import, Convention => C, External_Name => "ova_cg_spawn_on_path";
   procedure C_Error_Text (Err : Integer_32; Buf : out C.char_array; Len : Integer_32)
     with Import, Convention => C, External_Name => "ova_cg_spawn_error_text";
   function C_Session (Pid : Integer_32) return Integer_32
     with Import, Convention => C, External_Name => "ova_cg_spawn_session";

   --  ---- Argument vectors ----

   procedure Clear (A : in out Args) is
   begin
      A.Len := 0;
      A.N := 0;
      A.Overflow := False;
   end Clear;

   procedure Add (A : in out Args; S : String) is
   begin
      if A.Overflow or else A.Len + S'Length + 1 > Max_Args then
         A.Overflow := True;
      else
         for Ch of S loop
            A.Buf (C.size_t (A.Len)) := C.To_C (Ch);
            A.Len := A.Len + 1;
         end loop;
         A.Buf (C.size_t (A.Len)) := C.nul;
         A.Len := A.Len + 1;
         A.N := A.N + 1;
      end if;
   end Add;

   procedure Add (A : in out Args; S : Unbounded_String) is
   begin
      Add (A, To_String (S));
   end Add;

   function Count (A : Args) return Natural is (A.N);

   function Arg (A : Args; I : Natural) return String is
      P : Natural := 0;
      R : Unbounded_String;
   begin
      if I >= A.N then
         return "";
      end if;
      for K in 1 .. I loop
         while A.Buf (C.size_t (P)) /= C.nul loop
            P := P + 1;
         end loop;
         P := P + 1;
      end loop;
      while A.Buf (C.size_t (P)) /= C.nul loop
         Append (R, C.To_Ada (A.Buf (C.size_t (P))));
         P := P + 1;
      end loop;
      return To_String (R);
   end Arg;

   --  ---- Running ----

   function Pid (P : Process) return Integer is (P.Pid);

   function Detached (A : Args; P : out Process) return Integer is
      Got : Integer_32 := 0;
      Err : Integer_32;
   begin
      P := (Pid => 0, Start => -1);
      if A.Overflow then
         return E2BIG;
      end if;
      Err := C_Detached (A.Buf, Integer_32 (A.N), Got);
      if Err = 0 then
         P.Pid := Integer (Got);
         --  The program may already have ended; then Start is -1, and
         --  Terminate_Process leaves the pid alone.
         P.Start := C_Start_Time (Got);
      end if;
      return Integer (Err);
   end Detached;

   function Capture (A : Args; Output : out Unbounded_String; Status : out Integer)
     return Integer
   is
      Fd, Pid : Integer_32 := 0;
      Err     : Integer_32;
      Got     : Integer_64;
      Chunk   : C.char_array (0 .. 4095);
   begin
      Output := Null_Unbounded_String;
      Status := -1;
      if A.Overflow then
         return E2BIG;
      end if;
      Err := C_Capture (A.Buf, Integer_32 (A.N), Fd, Pid);
      if Err = 0 then
         loop
            Got := C_Read (Fd, Chunk, Chunk'Length);
            exit when Got <= 0;
            for K in 0 .. C.size_t (Got) - 1 loop
               Append (Output, C.To_Ada (Chunk (K)));
            end loop;
         end loop;
         Status := Integer (C_Finish (Fd, Pid));
      end if;
      return Integer (Err);
   end Capture;

   --  ---- Processes ----

   procedure None (P : out Process) is
   begin
      P := (Pid => 0, Start => -1);
   end None;

   function Alive (P : Process) return Boolean is
     (P.Pid > 0 and then P.Start >= 0 and then C_Start_Time (Integer_32 (P.Pid)) = P.Start);

   function Terminate_Process (P : in out Process) return Boolean is
      OK : constant Boolean := P.Pid > 0 and then C_Terminate (Integer_32 (P.Pid), P.Start) = 0;
   begin
      None (P);
      return OK;
   end Terminate_Process;

   function Session (Pid : Integer) return Integer is (Integer (C_Session (Integer_32 (Pid))));

   --  ---- Finding programs ----

   function On_Path (Name : String) return Boolean is (C_On_Path (C.To_C (Name)) /= 0);

   function Error_Text (Err : Integer) return String is
      S : C.char_array (0 .. 255);
   begin
      C_Error_Text (Integer_32 (Err), S, S'Length);
      return C.To_Ada (S);
   end Error_Text;

end Ova_Cg.Spawn;
