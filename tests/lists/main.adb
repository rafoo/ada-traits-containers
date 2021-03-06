------------------------------------------------------------------------------
--                     Copyright (C) 2016, AdaCore                          --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

pragma Ada_2012;
with Conts.Elements.Definite;
with Conts.Lists.Definite_Bounded;
with Conts.Lists.Definite_Unbounded;
with Conts.Lists.Generics;
with Conts.Lists.Indefinite_Unbounded;
with Conts.Lists.Indefinite_Unbounded_SPARK;
with Conts.Lists.Storage.Bounded;
with Support;
with Ada.Text_IO;    use Ada.Text_IO;

procedure Main is
begin

   Put_Line ("------- Definite Bounded --------------");
   declare
      package Int_Lists is new Conts.Lists.Definite_Bounded (Integer);
      package Tests is new Support
         (Image        => Integer'Image,
          Elements     => Int_Lists.Elements.Traits,
          Storage      => Int_Lists.Storage.Traits,
          Lists        => Int_Lists.Lists);
      L1, L2 : Int_Lists.List (20);
   begin
      Tests.Test (L1, L2);
   end;

   Put_Line ("------- Definite Bounded (limited) --------------");
   declare
      package E is new Conts.Elements.Definite (Integer);
      package S is new Conts.Lists.Storage.Bounded
         (E.Traits, Conts.Limited_Base);
      package Int_Lists is new Conts.Lists.Generics (S.Traits);
      package Tests is new Support
         (Image        => Integer'Image,
          Elements     => E.Traits,
          Storage      => S.Traits,
          Lists        => Int_Lists);
      L1, L2 : Int_Lists.List (20);
   begin
      Tests.Test (L1, L2);
   end;

   Put_Line ("------- Definite Unbounded --------------");
   declare
      package Int_Lists is new Conts.Lists.Definite_Unbounded (Integer);
      package Tests is new Support
         (Image        => Integer'Image,
          Elements     => Int_Lists.Elements.Traits,
          Storage      => Int_Lists.Storage.Traits,
          Lists        => Int_Lists.Lists);
      L1, L2 : Int_Lists.List;
   begin
      Tests.Test (L1, L2);
   end;

   Put_Line ("------- Indefinite Unbounded --------------");
   declare
      package Int_Lists is new Conts.Lists.Indefinite_Unbounded (Integer);
      function Image (R : Int_Lists.Constant_Returned) return String
         is (Integer'Image (R));
      package Tests is new Support
         (Image        => Image,
          Elements     => Int_Lists.Elements.Traits,
          Storage      => Int_Lists.Storage.Traits,
          Lists        => Int_Lists.Lists);
      L1, L2 : Int_Lists.List;
   begin
      Tests.Test (L1, L2);
   end;

   Put_Line ("------- Indefinite Unbounded SPARK --------------");
   declare
      package Int_Lists is new Conts.Lists.Indefinite_Unbounded_SPARK
         (Integer);
      package Tests is new Support
         (Image        => Integer'Image,
          Elements     => Int_Lists.Elements.Traits,
          Storage      => Int_Lists.Storage.Traits,
          Lists        => Int_Lists.Lists);
      L1, L2 : Int_Lists.List;
   begin
      Tests.Test (L1, L2);
   end;

end Main;
