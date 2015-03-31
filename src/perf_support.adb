with Ada.Containers.Doubly_Linked_Lists;
with Ada.Containers.Indefinite_Doubly_Linked_Lists;
with Ada.Calendar;       use Ada.Calendar;
with Ada.Text_IO;        use Ada.Text_IO;
with Conts.Lists.Definite_Unbounded;
with Conts.Lists.Indefinite_Unbounded;
with Conts.Lists.Indefinite_Unbounded_SPARK;
with Conts.Lists.Definite_Bounded;
with Conts.Lists.Definite_Bounded_Limited;
with Conts.Algorithms;
with Conts.Adaptors;     use Conts.Adaptors;
with Taggeds;
with Interfaces.C.Strings;
with Memory;

--  The tests all use a subprogram with a class-wide parameter, to force the
--  use of dynamic dispatching and simulate real applications.

package body Perf_Support is

   function Greater_Than_3 (P : Integer) return Boolean is (P > 3)
      with Inline => True;

   function Starts_With_Str (S : String) return Boolean is
      (S (S'First) = 's');
   pragma Inline (Starts_With_Str);

   procedure Print_Separator (Self : in out Output);

   ------------
   -- Output --
   ------------

   procedure Reset (Self : in out Output) is
   begin
      Self.Finish_Line;
      Self.Fill_Ref := 0.0;
      Self.Loop_Ref := 0.0;
   end Reset;

   procedure Print_Header (Self : in out Output) is
   begin
      Self.Start_Line ("");
      Self.Print_Not_Run ("fill");
      Self.Print_Not_Run ("explicit");
      Self.Print_Not_Run ("for..of");
      Self.Print_Not_Run ("count_if");
      Self.Print_Not_Run ("copy");
      Self.Print_Not_Run ("allocate");
      Self.Print_Not_Run ("allocs");
      Self.Print_Not_Run ("reallocs");
      Self.Print_Not_Run ("frees");
      New_Line;
      Self.Column := -1;
   end Print_Header;

   procedure Start_Line
      (Self : in out Output; Title : String; Fewer_Items : Boolean := False) is
   begin
      Self.Finish_Line;
      Memory.Reset;
      Self.Column := 1;
      Put (Title & (Title'Length + 1 .. 10 => ' '));
      Print_Separator (Self);
      Self.Fewer_Items := Fewer_Items;
   end Start_Line;

   procedure Finish_Line (Self : in out Output) is
   begin
      if Self.Column /= -1 then
         while Self.Column < 10 loop
            Self.Print_Not_Run;
         end loop;
         Print_Not_Run (Self, Memory.Frees'Img);
         Self.Column := -1;
         if Items_Count /= Small_Items_Count and then Self.Fewer_Items then
            Put_Line (" fewer items");
         else
            New_Line;
         end if;
      end if;
   end Finish_Line;

   procedure Print_Separator (Self : in out Output) is
   begin
      if Self.Column = 1
         or else Self.Column = 2
         or else Self.Column = 5
         or else Self.Column = 6
         or else Self.Column = 10
      then
         Put (Character'Val (16#E2#)
              & Character'Val (16#95#)
              & Character'Val (16#91#));
      else
         Put ('|');
      end if;
      Self.Column := Self.Column + 1;
   end Print_Separator;

   procedure Print_Time
      (Self : in out Output; D : Duration; Extra : String := "")
   is
      Ref : Duration;
   begin
      if Self.Show_Percent then
         if Self.Column = 2 then
            if Self.Fill_Ref = 0.0 then
               Self.Fill_Ref := D;
            end if;
            Ref := Self.Fill_Ref;
         else
            if Self.Loop_Ref = 0.0 then
               Self.Loop_Ref := D;
            end if;
            Ref := Self.Loop_Ref;
         end if;

         declare
            S : constant String := Integer'Image
               (Integer (Float'Floor (Float (D) / Float (Ref) * 100.0))) & '%';
         begin
            Put (S & Extra & (S'Length + Extra'Length + 1 .. 8 => ' '));
         end;

      else
         declare
            S   : constant String := D'Img;
            Sub : constant String :=
               S (S'First .. Integer'Min (S'Last, S'First + 7));
         begin
            Put (Sub & Extra & (Sub'Length + Extra'Length + 1 .. 8 => ' '));
         end;
      end if;

      Print_Separator (Self);
   end Print_Time;

   procedure Print_Not_Run (Self : in out Output; Extra : String := "") is
   begin
      Put (Extra & (Extra'Length + 1 .. 8 => ' '));
      Print_Separator (Self);
   end Print_Not_Run;

   procedure Print_Size (Self : in out Output; Size : Natural) is
      procedure Local_Print (S : String);
      procedure Local_Print (S : String) is
      begin
         Put (S (S'First + 1 .. S'Last) & (S'Length .. 8 => ' '));
         Print_Separator (Self);
      end Local_Print;

      Actual_Size : constant Natural := Size + Natural (Memory.Live);
   begin
      if Actual_Size >= 1_000_000 then
         --  Approximate a kb as 1000 bytes, easier to compare
         Local_Print (Integer'Image (Actual_Size / 1000) & "kb");
      else
         Local_Print (Integer'Image (Actual_Size) & "b");
      end if;

      Print_Not_Run (Self, Memory.Allocs'Img);
      Print_Not_Run (Self, Memory.Reallocs'Img);
   end Print_Size;

   procedure Print_From_C (D : Interfaces.C.double);
   pragma Export (C, Print_From_C, "_ada_print_time");
   procedure Print_From_C (D : Interfaces.C.double) is
   begin
      Stdout.Print_Time (Duration (D));
   end Print_From_C;

   procedure Start_Line_C (Title : Interfaces.C.Strings.chars_ptr);
   pragma Export (C, Start_Line_C, "_ada_start_line");
   procedure Start_Line_C (Title : Interfaces.C.Strings.chars_ptr) is
   begin
      Stdout.Start_Line (Interfaces.C.Strings.Value (Title));
   end Start_Line_C;

   -------------------------------
   -- Test_Lists_Int_Indefinite --
   -------------------------------

   procedure Test_Lists_Int_Indefinite is
      package Lists is new Conts.Lists.Indefinite_Unbounded
         (Element_Type   => Integer,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List iuc");

         Start := Clock;
         for C in 1 .. Items_Count - 2 loop
            V2.Append (2);
         end loop;
         V2.Append (5);
         V2.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if V2.Element (It) > 3 then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V2 loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start, Extra => "(1)");
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (V2, Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);
      end Do_Test;

      V : Lists.List;

   begin
      Do_Test (V);
   end Test_Lists_Int_Indefinite;

   -------------------------------------
   -- Test_Lists_Int_Indefinite_SPARK --
   -------------------------------------

   procedure Test_Lists_Int_Indefinite_SPARK is
      package Lists is new Conts.Lists.Indefinite_Unbounded_SPARK
         (Element_Type   => Integer,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List isl");

         Start := Clock;
         for C in 1 .. Items_Count - 2 loop
            V2.Append (2);
         end loop;
         V2.Append (5);
         V2.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if V2.Element (It) > 3 then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V2 loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start, Extra => "(1)");
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (V2, Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
            V_Copy.Clear;   --  explicit deallocation is needed
         end;

         Stdout.Print_Size (V2'Size);

         V2.Clear;   --  explicit deallocation is needed
      end Do_Test;

      V : Lists.List;

   begin
      Do_Test (V);
   end Test_Lists_Int_Indefinite_SPARK;

   --------------------
   -- Test_Lists_Int --
   --------------------

   procedure Test_Lists_Int is
      package Lists is new Conts.Lists.Definite_Unbounded
         (Element_Type   => Integer,
          Enable_Asserts => False);
      use Lists, Lists.Lists;   --  second is for Ada95 notation
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List duc");

         Start := Clock;
         for C in 1 .. Items_Count - 2 loop
            V2.Append (2);
         end loop;
         V2.Append (5);    --  testing withe prefix notation
         Append (V2, 6);   --  testing with Ada95 notation
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if V2.Element (It) > 3 then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V2 loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start, Extra => "(1)");
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (V2, Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);
      end Do_Test;

      V : Lists.List;
   begin
      Do_Test (V);
   end Test_Lists_Int;

   --------------------------------
   -- Test_Lists_Bounded_Limited --
   --------------------------------

   procedure Test_Lists_Bounded_Limited is
      package Lists is new Conts.Lists.Definite_Bounded_Limited
         (Element_Type   => Integer,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List dbl", Fewer_Items => True);

         Start := Clock;
         for C in 1 .. Small_Items_Count - 2 loop
            V2.Append (2);
         end loop;
         V2.Append (5);
         V2.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if V2.Element (It) > 3 then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V2 loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start, Extra => "(1)");
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (V2, Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List (Capacity => Small_Items_Count);
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);

         V2.Clear;   --  Need explicit deallocation, this is limited
      end Do_Test;

      V : Lists.List (Capacity => Small_Items_Count);
   begin
      Do_Test (V);
   end Test_Lists_Bounded_Limited;

   ------------------------
   -- Test_Lists_Bounded --
   ------------------------

   procedure Test_Lists_Bounded is
      package Lists is new Conts.Lists.Definite_Bounded
         (Element_Type   => Integer,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List dbc", Fewer_Items => True);

         Start := Clock;
         for C in 1 .. Small_Items_Count - 2 loop
            V2.Append (2);
         end loop;
         V2.Append (5);
         V2.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if V2.Element (It) > 3 then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V2 loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start, Extra => "(1)");
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (V2, Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List (Capacity => Small_Items_Count);
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);

         V2.Clear;   --  Need explicit deallocation, this is limited
      end Do_Test;

      V : Lists.List (Capacity => Small_Items_Count);
   begin
      Do_Test (V);
   end Test_Lists_Bounded;

   ---------------------------
   -- Test_Lists_Str_Access --
   ---------------------------

   procedure Test_Lists_Str_Access is
      package Lists is new Conts.Lists.Indefinite_Unbounded
         (Element_Type   => String,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward_Stored);

      function Starts_With_Str
         (S : Lists.Cursors.Stored_Element_Type) return Boolean
         is (S (S'First) = 's');
      pragma Inline (Starts_With_Str);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It    : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List iuc 3");

         Start := Clock;
         for C in 1 .. Items_Count loop
            V2.Append ("str1");
         end loop;
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if Starts_With_Str (V2.Stored_Element (It).all) then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         --  Start := Clock;
         --  Co := 0;
         --  for E of V2 loop  -- GNAT: unconstrained subtype not allowed
         --     if Starts_With_Str (E) then
         --        Co := Co + 1;
         --     end if;
         --  end loop;
         --  Print_Time (Clock - Start);
         --  if Co /= Items_Count then
         --     raise Program_Error;
         --  end if;
         Stdout.Print_Not_Run ("(2)");

         Start := Clock;
         Co := Count_If (V2, Starts_With_Str'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);
      end Do_Test;

      V : Lists.List;
   begin
      Do_Test (V);
   end Test_Lists_Str_Access;

   ------------------------------
   -- Test_Lists_Str_Reference --
   ------------------------------

   procedure Test_Lists_Str_Reference is
      package Lists is new Conts.Lists.Indefinite_Unbounded
         (Element_Type   => String,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward_Reference);

      function Ref_Starts_With_Str
         (S : Lists.Cursors.Reference_Type) return Boolean
         is (S (S.E'First) = 's');
      pragma Inline (Ref_Starts_With_Str);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It    : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List iuc 4");

         Start := Clock;
         for C in 1 .. Items_Count loop
            V2.Append ("str1");
         end loop;
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if Ref_Starts_With_Str (V2.Reference (It)) then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         --  Start := Clock;
         --  Co := 0;
         --  for E of V2 loop  -- GNAT: unconstrained subtype not allowed
         --     if Starts_With_Str (E) then
         --        Co := Co + 1;
         --     end if;
         --  end loop;
         --  Print_Time (Clock - Start);
         --  if Co /= Items_Count then
         --     raise Program_Error;
         --  end if;
         Stdout.Print_Not_Run ("(2)");

         Start := Clock;
         Co := Count_If (V2, Ref_Starts_With_Str'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);
      end Do_Test;

      V : Lists.List;
   begin
      Do_Test (V);
   end Test_Lists_Str_Reference;

   --------------------
   -- Test_Lists_Str --
   --------------------

   procedure Test_Lists_Str is
      package Lists is new Conts.Lists.Indefinite_Unbounded
         (Element_Type   => String,
          Enable_Asserts => False);
      use Lists;
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Lists.Cursors.Forward);

      procedure Do_Test (V2 : in out Lists.List'Class);
      procedure Do_Test (V2 : in out Lists.List'Class) is
         It    : Lists.Cursor;
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("List iuc");

         Start := Clock;
         for C in 1 .. Items_Count loop
            V2.Append ("str1");
         end loop;
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V2.First;
         while V2.Has_Element (It) loop
            if Starts_With_Str (V2.Element (It)) then
               Co := Co + 1;
            end if;
            It := V2.Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         --  Start := Clock;
         --  Co := 0;
         --  for E of V2 loop  -- GNAT: unconstrained subtype not allowed
         --     if Starts_With_Str (E) then
         --        Co := Co + 1;
         --     end if;
         --  end loop;
         --  Print_Time (Clock - Start);
         --  if Co /= Items_Count then
         --     raise Program_Error;
         --  end if;
         Stdout.Print_Not_Run ("(2)");

         Start := Clock;
         Co := Count_If (V2, Starts_With_Str'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (V2);
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V2'Size);
      end Do_Test;

      V : Lists.List;
   begin
      Do_Test (V);
   end Test_Lists_Str;

   ----------------------
   -- Test_Ada2012_Str --
   ----------------------

   procedure Test_Ada2012_Str is
      package Lists is new Ada.Containers.Indefinite_Doubly_Linked_Lists
         (String);
      use Lists;
      package Adaptors is new Indefinite_List_Adaptors (Lists);
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Adaptors.Cursors.Forward);

      procedure Do_Test (V : in out Lists.List'Class);
      procedure Do_Test (V : in out Lists.List'Class) is
         Start : Time;
         It    : Lists.Cursor;
         Co    : Natural;
      begin
         Stdout.Start_Line ("Ada iu");

         Start := Clock;
         for C in 1 .. Items_Count loop
            V.Append ("str1");
         end loop;
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V.First;
         while Has_Element (It) loop
            if Starts_With_Str (Element (It)) then  --  secondary stack
               Co := Co + 1;
            end if;
            Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V loop
            if Starts_With_Str (E) then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         Start := Clock;
         --  ??? Why do we need a cast here
         Co := Count_If (List (V), Starts_With_Str'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= Items_Count then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (Lists.List (V));
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V'Size);
      end Do_Test;

      V  : Lists.List;
   begin
      Do_Test (V);
   end Test_Ada2012_Str;

   ---------------------
   -- Test_Arrays_Int --
   ---------------------

   procedure Test_Arrays_Int is
      type Int_Array is array (Integer range <>) of Integer;
      package Adaptors is new Array_Adaptors
         (Index_Type   => Integer,
          Element_Type => Integer,
          Array_Type   => Int_Array);
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Adaptors.Cursors.Forward);

      V     : Int_Array (1 .. Small_Items_Count);
      Start : Time;
      Co    : Natural;
   begin
      Stdout.Start_Line ("Array", Fewer_Items => True);

      Start := Clock;
      for C in 1 .. Small_Items_Count - 2 loop
         V (C) := 2;
      end loop;
      V (V'Last - 1) := 5;
      V (V'Last) := 6;
      Stdout.Print_Time (Clock - Start);

      Start := Clock;
      Co := 0;
      for It in V'Range loop
         if V (It) > 3 then
            Co := Co + 1;
         end if;
      end loop;
      Stdout.Print_Time (Clock - Start);
      if Co /= 2 then
         raise Program_Error;
      end if;

      Start := Clock;
      Co := 0;
      for E of V loop
         if E > 3 then
            Co := Co + 1;
         end if;
      end loop;
      Stdout.Print_Time (Clock - Start);
      if Co /= 2 then
         raise Program_Error;
      end if;

      Start := Clock;
      Co := Count_If (V, Greater_Than_3'Access);
      Stdout.Print_Time (Clock - Start);
      if Co /= 2 then
         raise Program_Error;
      end if;

      Start := Clock;
      declare
         V_Copy : Int_Array := V;
         pragma Unreferenced (V_Copy);
      begin
         Stdout.Print_Time (Clock - Start);
      end;

      Stdout.Print_Size (V'Size);
   end Test_Arrays_Int;

   ----------------------
   -- Test_Ada2012_Int --
   ----------------------

   procedure Test_Ada2012_Int is
      package Lists is new Ada.Containers.Doubly_Linked_Lists (Integer);
      use Lists;
      package Adaptors is new List_Adaptors (Lists);
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Adaptors.Cursors.Forward);

      procedure Do_Test (V : in out Lists.List'Class);
      procedure Do_Test (V : in out Lists.List'Class) is
         Start : Time;
         It    : Lists.Cursor;
         Co    : Natural;
      begin
         Stdout.Start_Line ("Ada du");

         Start := Clock;
         for C in 1 .. Items_Count - 2 loop
            V.Append (2);
         end loop;
         V.Append (5);
         V.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V.First;
         while Has_Element (It) loop
            if Element (It) > 3 then
               Co := Co + 1;
            end if;
            Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (List (V), Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (Lists.List (V));
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V'Size);
      end Do_Test;

      V  : Lists.List;
   begin
      Do_Test (V);
   end Test_Ada2012_Int;

   ---------------------------------
   -- Test_Ada2012_Int_Indefinite --
   ---------------------------------

   procedure Test_Ada2012_Int_Indefinite is
      package Lists is new Ada.Containers.Indefinite_Doubly_Linked_Lists
         (Integer);
      use Lists;
      package Adaptors is new Indefinite_List_Adaptors (Lists);
      function Count_If is new Conts.Algorithms.Count_If
         (Cursors => Adaptors.Cursors.Forward);

      procedure Do_Test (V : in out Lists.List'Class);
      procedure Do_Test (V : in out Lists.List'Class) is
         Start : Time;
         It    : Lists.Cursor;
         Co    : Natural;
      begin
         Stdout.Start_Line ("Ada iu");

         Start := Clock;
         for C in 1 .. Items_Count - 2 loop
            V.Append (2);
         end loop;
         V.Append (5);
         V.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         It := V.First;
         while Has_Element (It) loop
            if Element (It) > 3 then
               Co := Co + 1;
            end if;
            Next (It);
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := 0;
         for E of V loop
            if E > 3 then
               Co := Co + 1;
            end if;
         end loop;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         Co := Count_If (List (V), Greater_Than_3'Access);
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Start := Clock;
         declare
            V_Copy : Lists.List;
         begin
            V_Copy.Assign (Lists.List (V));
            Stdout.Print_Time (Clock - Start);
         end;

         Stdout.Print_Size (V'Size);
      end Do_Test;

      V  : Lists.List;
   begin
      Do_Test (V);
   end Test_Ada2012_Int_Indefinite;

   ---------------------
   -- Test_Tagged_Int --
   ---------------------

   procedure Test_Tagged_Int is
      package Lists is new Taggeds (Integer);
      use Lists;

      procedure Do_Test (V : in out Lists.List'Class);
      procedure Do_Test (V : in out Lists.List'Class) is
         Start : Time;
         Co    : Natural;
      begin
         Stdout.Start_Line ("Tagged");

         Start := Clock;
         for C in 1 .. Items_Count - 2 loop
            V.Append (2);
         end loop;
         V.Append (5);
         V.Append (6);
         Stdout.Print_Time (Clock - Start);

         Start := Clock;
         Co := 0;
         declare
            It  : Lists.List_Cursor'Class := List_Cursor (V.First);
            --  Casting to List_Cursor here halves the time to run the
            --  loop by avoiding dynamic dispatching.
         begin
            while It.Has_Element loop
               if It.Element > 3 then
                  Co := Co + 1;
               end if;
               It.Next;
            end loop;
         end;
         Stdout.Print_Time (Clock - Start);
         if Co /= 2 then
            raise Program_Error;
         end if;

         Stdout.Print_Not_Run;  --  for..of
         Stdout.Print_Not_Run;  --  count_if
         Stdout.Print_Not_Run;  --  copy
         Stdout.Print_Size (V'Size);
      end Do_Test;

      V : Lists.List;
   begin
      Do_Test (V);
   end Test_Tagged_Int;

end Perf_Support;
