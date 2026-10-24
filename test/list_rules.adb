--  Prints Ova_Cg.Rules' items as "PAGE<TAB>NAME", in the book's order,
--  for make check-pages.

with Ada.Characters.Latin_1;
with Ada.Text_IO;
with Ova_Cg.Rules; use Ova_Cg.Rules;

procedure List_Rules is
begin
   for K in Kind loop
      for I in 0 .. Count (K) - 1 loop
         declare
            It : constant Item := Get (K, I);
            P  : constant String := Positive'Image (It.Page);
         begin
            Ada.Text_IO.Put_Line (P (P'First + 1 .. P'Last) & Ada.Characters.Latin_1.HT & Name_Of (It));
         end;
      end loop;
   end loop;
end List_Rules;
