Set Warnings "-primitive-turned-into-axiom".
From CertiRocq.Plugin Require Import CertiRocq.

From Stdlib Require Import Uint63 PrimFloat.

Open Scope float.

(* Unit tests for the primitive float operations, in the style of
   uint63_unit_tests.v. Every expected value in a comment below was
   computed by Rocq's kernel, not written by hand. *)


(* add *)
Definition add1 := 2 + 3. (* = 5 *)
CertiRocq Compile Wasm add1.
Definition add2 := 0.5 + 0.25. (* = 0.75 *)
CertiRocq Compile Wasm add2.
Definition add3 := 0.1 + 0.2. (* = 0.30000000000000004 *)
CertiRocq Compile Wasm add3.
Definition add4 := infinity + neg_infinity. (* = nan *)
CertiRocq Compile Wasm add4.
Definition add5 := 1 + nan. (* = nan *)
CertiRocq Compile Wasm add5.
Definition add6 := zero + neg_zero. (* = 0 *)
CertiRocq Compile Wasm add6.

(* sub *)
Definition sub1 := 3 - 2. (* = 1 *)
CertiRocq Compile Wasm sub1.
Definition sub2 := 0.5 - 1. (* = -0.5 *)
CertiRocq Compile Wasm sub2.
Definition sub3 := zero - zero. (* = 0 *)
CertiRocq Compile Wasm sub3.
Definition sub4 := infinity - infinity. (* = nan *)
CertiRocq Compile Wasm sub4.

(* mul *)
Definition mul1 := 2 * 3. (* = 6 *)
CertiRocq Compile Wasm mul1.
Definition mul2 := 0.5 * 0.5. (* = 0.25 *)
CertiRocq Compile Wasm mul2.
Definition mul3 := zero * infinity. (* = nan *)
CertiRocq Compile Wasm mul3.
Definition mul4 := (-1) * zero. (* = -0 *)
CertiRocq Compile Wasm mul4.

(* div *)
Definition div1 := 6 / 3. (* = 2 *)
CertiRocq Compile Wasm div1.
Definition div2 := 1 / 0. (* = infinity *)
CertiRocq Compile Wasm div2.
Definition div3 := (-1) / 0. (* = neg_infinity *)
CertiRocq Compile Wasm div3.
Definition div4 := 0 / 0. (* = nan *)
CertiRocq Compile Wasm div4.
Definition div5 := 1 / 3. (* = 0.33333333333333331 *)
CertiRocq Compile Wasm div5.

(* sqrt *)
Definition sqrt1 := sqrt 4. (* = 2 *)
CertiRocq Compile Wasm sqrt1.
Definition sqrt2 := sqrt 2. (* = 1.4142135623730951 *)
CertiRocq Compile Wasm sqrt2.
Definition sqrt3 := sqrt (-1). (* = nan *)
CertiRocq Compile Wasm sqrt3.
Definition sqrt4 := sqrt zero. (* = 0 *)
CertiRocq Compile Wasm sqrt4.
Definition sqrt5 := sqrt neg_zero. (* = -0 *)
CertiRocq Compile Wasm sqrt5.

(* opp, abs *)
Definition opp1 := - (1.5). (* = -1.5 *)
CertiRocq Compile Wasm opp1.
Definition opp2 := - zero. (* = -0 *)
CertiRocq Compile Wasm opp2.
Definition opp3 := - neg_infinity. (* = infinity *)
CertiRocq Compile Wasm opp3.
Definition abs1 := abs (-1.5). (* = 1.5 *)
CertiRocq Compile Wasm abs1.
Definition abs2 := abs neg_infinity. (* = infinity *)
CertiRocq Compile Wasm abs2.
Definition abs3 := abs neg_zero. (* = 0 *)
CertiRocq Compile Wasm abs3.

(* compare *)
Definition compare1 := 1 ?= 1. (* = FEq *)
CertiRocq Compile Wasm compare1.
Definition compare2 := 1 ?= 2. (* = FLt *)
CertiRocq Compile Wasm compare2.
Definition compare3 := 2 ?= 1. (* = FGt *)
CertiRocq Compile Wasm compare3.
Definition compare4 := nan ?= 1. (* = FNotComparable *)
CertiRocq Compile Wasm compare4.
Definition compare5 := zero ?= neg_zero. (* = FEq *)
CertiRocq Compile Wasm compare5.

(* eqb: IEEE754 equality, so nan <> nan and +0 = -0 *)
Definition eqb1 := 1 =? 1. (* = true *)
CertiRocq Compile Wasm eqb1.
Definition eqb2 := 1 =? 2. (* = false *)
CertiRocq Compile Wasm eqb2.
Definition eqb3 := nan =? nan. (* = false *)
CertiRocq Compile Wasm eqb3.
Definition eqb4 := zero =? neg_zero. (* = true *)
CertiRocq Compile Wasm eqb4.

(* ltb, leb *)
Definition ltb1 := 1 <? 2. (* = true *)
CertiRocq Compile Wasm ltb1.
Definition ltb2 := 2 <? 1. (* = false *)
CertiRocq Compile Wasm ltb2.
Definition ltb3 := 1 <? 1. (* = false *)
CertiRocq Compile Wasm ltb3.
Definition ltb4 := nan <? nan. (* = false *)
CertiRocq Compile Wasm ltb4.
Definition leb1 := 1 <=? 1. (* = true *)
CertiRocq Compile Wasm leb1.
Definition leb2 := 1 <=? 2. (* = true *)
CertiRocq Compile Wasm leb2.
Definition leb3 := 2 <=? 1. (* = false *)
CertiRocq Compile Wasm leb3.
Definition leb4 := nan <=? nan. (* = false *)
CertiRocq Compile Wasm leb4.

(* classify *)
Definition classify1 := classify 1. (* = FloatClass.PNormal *)
CertiRocq Compile Wasm classify1.
Definition classify2 := classify (-1). (* = FloatClass.NNormal *)
CertiRocq Compile Wasm classify2.
Definition classify3 := classify zero. (* = FloatClass.PZero *)
CertiRocq Compile Wasm classify3.
Definition classify4 := classify neg_zero. (* = FloatClass.NZero *)
CertiRocq Compile Wasm classify4.
Definition classify5 := classify infinity. (* = FloatClass.PInf *)
CertiRocq Compile Wasm classify5.
Definition classify6 := classify neg_infinity. (* = FloatClass.NInf *)
CertiRocq Compile Wasm classify6.
Definition classify7 := classify nan. (* = FloatClass.NaN *)
CertiRocq Compile Wasm classify7.
Definition classify8 := classify (next_up zero). (* = FloatClass.PSubn *)
CertiRocq Compile Wasm classify8.
Definition classify9 := classify (next_down neg_zero). (* = FloatClass.NSubn *)
CertiRocq Compile Wasm classify9.

(* of_uint63: rounds to nearest when the integer is not representable *)
Definition of_uint63_1 := of_uint63 0. (* = 0 *)
CertiRocq Compile Wasm of_uint63_1.
Definition of_uint63_2 := of_uint63 42. (* = 42 *)
CertiRocq Compile Wasm of_uint63_2.
Definition of_uint63_3 := of_uint63 9007199254740993. (* = 9007199254740992 *)
CertiRocq Compile Wasm of_uint63_3.
Definition of_uint63_4 := of_uint63 9223372036854775807. (* = 9.2233720368547758e+18 *)
CertiRocq Compile Wasm of_uint63_4.

(* normfr_mantissa: mantissa of a float in [0.5, 1), else 0 *)
Definition normfr_mantissa1 := normfr_mantissa 0.5. (* = 4503599627370496%uint63 *)
CertiRocq Compile Wasm normfr_mantissa1.
Definition normfr_mantissa2 := normfr_mantissa 0.75. (* = 6755399441055744%uint63 *)
CertiRocq Compile Wasm normfr_mantissa2.
Definition normfr_mantissa3 := normfr_mantissa 1. (* = 0%uint63 *)
CertiRocq Compile Wasm normfr_mantissa3.
Definition normfr_mantissa4 := normfr_mantissa (-0.5). (* = 4503599627370496%uint63 *)
CertiRocq Compile Wasm normfr_mantissa4.
Definition normfr_mantissa5 := normfr_mantissa zero. (* = 0%uint63 *)
CertiRocq Compile Wasm normfr_mantissa5.

(* frshiftexp: fraction in [0.5, 1) and exponent biased by shift = 2101 *)
Definition frshiftexp1 := frshiftexp 1. (* = (0.5, 2102%uint63) *)
CertiRocq Compile Wasm frshiftexp1.
Definition frshiftexp2 := frshiftexp 0.5. (* = (0.5, 2101%uint63) *)
CertiRocq Compile Wasm frshiftexp2.
Definition frshiftexp3 := frshiftexp 12. (* = (0.75, 2105%uint63) *)
CertiRocq Compile Wasm frshiftexp3.
Definition frshiftexp4 := frshiftexp zero. (* = (0, 0%uint63) *)
CertiRocq Compile Wasm frshiftexp4.
Definition frshiftexp5 := frshiftexp infinity. (* = (infinity, 0%uint63) *)
CertiRocq Compile Wasm frshiftexp5.
Definition frshiftexp6 := frshiftexp nan. (* = (nan, 0%uint63) *)
CertiRocq Compile Wasm frshiftexp6.

(* ldshiftexp x e = x * 2 ^ (e - 2101) *)
Definition ldshiftexp1 := ldshiftexp 1 2101. (* = 1 *)
CertiRocq Compile Wasm ldshiftexp1.
Definition ldshiftexp2 := ldshiftexp 1 2102. (* = 2 *)
CertiRocq Compile Wasm ldshiftexp2.
Definition ldshiftexp3 := ldshiftexp 1 2100. (* = 0.5 *)
CertiRocq Compile Wasm ldshiftexp3.
Definition ldshiftexp4 := ldshiftexp 0.5 2105. (* = 8 *)
CertiRocq Compile Wasm ldshiftexp4.
Definition ldshiftexp5 := ldshiftexp 1 0. (* = 0 *)
CertiRocq Compile Wasm ldshiftexp5.
Definition ldshiftexp6 := ldshiftexp 1 4000. (* = infinity *)
CertiRocq Compile Wasm ldshiftexp6.
Definition ldshiftexp7 := ldshiftexp infinity 2101. (* = infinity *)
CertiRocq Compile Wasm ldshiftexp7.

(* next_up, next_down *)
Definition next_up1 := next_up 1. (* = 1.0000000000000002 *)
CertiRocq Compile Wasm next_up1.
Definition next_up2 := next_up zero. (* = 4.9406564584124654e-324 *)
CertiRocq Compile Wasm next_up2.
Definition next_up3 := next_up neg_zero. (* = 4.9406564584124654e-324 *)
CertiRocq Compile Wasm next_up3.
Definition next_up4 := next_up neg_infinity. (* = -1.7976931348623157e+308 *)
CertiRocq Compile Wasm next_up4.
Definition next_up5 := next_up infinity. (* = infinity *)
CertiRocq Compile Wasm next_up5.
Definition next_down1 := next_down 1. (* = 0.99999999999999989 *)
CertiRocq Compile Wasm next_down1.
Definition next_down2 := next_down zero. (* = -4.9406564584124654e-324 *)
CertiRocq Compile Wasm next_down2.
Definition next_down3 := next_down infinity. (* = 1.7976931348623157e+308 *)
CertiRocq Compile Wasm next_down3.
Definition next_down4 := next_down neg_infinity. (* = neg_infinity *)
CertiRocq Compile Wasm next_down4.

(* compositions: frshiftexp/ldshiftexp round-trip, mantissa scaling *)
Definition roundtrip1 := ldshiftexp (fst (frshiftexp 12)) (snd (frshiftexp 12)). (* = 12 *)
CertiRocq Compile Wasm roundtrip1.
Definition roundtrip2 := of_uint63 (normfr_mantissa 0.5) / of_uint63 9007199254740992. (* = 0.5 *)
CertiRocq Compile Wasm roundtrip2.
