From Stdlib Require Import ZArith BinNat List.
From Corelib Require FloatOps SpecFloat.
From Wasm Require Import datatypes.
From CertiRocq Require Import Common.compM Common.Pipeline_utils
  CodegenWasm.LambdaANF_to_Wasm_primints.
From MetaRocq Require Import Common.Kernames Utils.bytestring Utils.MRString.

Import ListNotations Wasm_int.


(* Primitive floats are boxed exactly like primitive integers: an 8-byte payload
   at an even address, the value being its address.  The payload is the IEEE754
   binary64 bit pattern, so it can be read either as an f64 (for the arithmetic)
   or as an i64 (for the bit-level operations) with no conversion in between. *)


(* Path of the PrimFloat module in the kernel: Corelib.Floats.PrimFloat *)
Definition primFloatModPath : Kernames.modpath :=
  Kernames.MPfile [ "PrimFloat"%bs ; "Floats"%bs ; "Corelib"%bs ].

(* Supported operators defined as data type to avoid pattern matching on kernel name (bytestrings) *)
Inductive primfloatop :=
| PrimFloatadd
| PrimFloatsub
| PrimFloatmul
| PrimFloatdiv
| PrimFloatsqrt
| PrimFloatabs
| PrimFloatopp
| PrimFloateqb
| PrimFloatltb
| PrimFloatleb
| PrimFloatcompare
| PrimFloatclassify
| PrimFloatof_uint63
| PrimFloatnormfr_mantissa
| PrimFloatfrshiftexp
| PrimFloatldshiftexp
| PrimFloatnext_up
| PrimFloatnext_down.

Definition primfloat_map : KernameMap.t primfloatop :=
  KernameMap.add (primFloatModPath, "add") PrimFloatadd
    (KernameMap.add (primFloatModPath, "sub") PrimFloatsub
    (KernameMap.add (primFloatModPath, "mul") PrimFloatmul
    (KernameMap.add (primFloatModPath, "div") PrimFloatdiv
    (KernameMap.add (primFloatModPath, "sqrt") PrimFloatsqrt
    (KernameMap.add (primFloatModPath, "abs") PrimFloatabs
    (KernameMap.add (primFloatModPath, "opp") PrimFloatopp
    (KernameMap.add (primFloatModPath, "eqb") PrimFloateqb
    (KernameMap.add (primFloatModPath, "ltb") PrimFloatltb
    (KernameMap.add (primFloatModPath, "leb") PrimFloatleb
    (KernameMap.add (primFloatModPath, "compare") PrimFloatcompare
    (KernameMap.add (primFloatModPath, "classify") PrimFloatclassify
    (KernameMap.add (primFloatModPath, "of_uint63") PrimFloatof_uint63
    (KernameMap.add (primFloatModPath, "normfr_mantissa") PrimFloatnormfr_mantissa
    (KernameMap.add (primFloatModPath, "frshiftexp") PrimFloatfrshiftexp
    (KernameMap.add (primFloatModPath, "ldshiftexp") PrimFloatldshiftexp
    (KernameMap.add (primFloatModPath, "next_up") PrimFloatnext_up
    (KernameMap.add (primFloatModPath, "next_down") PrimFloatnext_down
    (KernameMap.empty primfloatop)))))))))))))))))).


(* Ordinals of the constructors of the result types.
   Corelib.Floats.PrimFloat: Variant float_comparison := FEq | FLt | FGt | FNotComparable *)
Definition FEq_ord            := 0%N.
Definition FLt_ord            := 1%N.
Definition FGt_ord            := 2%N.
Definition FNotComparable_ord := 3%N.

(* Corelib.Floats.FloatClass:
   Variant float_class := PNormal | NNormal | PSubn | NSubn | PZero | NZero | PInf | NInf | NaN *)
Definition PNormal_ord := 0%N.
Definition NNormal_ord := 1%N.
Definition PSubn_ord   := 2%N.
Definition NSubn_ord   := 3%N.
Definition PZero_ord   := 4%N.
Definition NZero_ord   := 5%N.
Definition PInf_ord    := 6%N.
Definition NInf_ord    := 7%N.
Definition NaN_ord     := 8%N.


(* Bit patterns of the binary64 format.  Every constant below is a plain
   64-bit pattern, written in decimal because that is what [Int64.repr] takes. *)
Definition f64_exp_mask          := 2047%Z.                  (* all ones in the exponent field *)
Definition f64_mant_mask         := 4503599627370495%Z.      (* 2^52 - 1 *)
Definition f64_abs_mask          := 9223372036854775807%Z.   (* 2^63 - 1, clears the sign bit *)
Definition f64_hidden_bit        := 4503599627370496%Z.      (* 2^52 *)
Definition f64_sign_mant_mask    := 9227875636482146303%Z.   (* sign bit | 2^52 - 1 *)
Definition f64_pos_inf_bits      := 9218868437227405312%Z.   (* 2047 << 52 *)
Definition f64_neg_inf_bits      := 18442240474082181120%Z.  (* sign bit | 2047 << 52 *)
Definition f64_min_subn_bits     := 1%Z.                     (* 2^-1074, the smallest positive float *)
Definition f64_neg_min_subn_bits := 9223372036854775809%Z.   (* -2^-1074 *)
Definition f64_half_exp_bits     := 4602678819172646912%Z.   (* 1022 << 52, the exponent field of [0.5, 1) *)
Definition f64_two_pow_54_bits   := 4850376798678024192%Z.   (* 2^54 *)
Definition f64_two_pow_1023_bits := 9214364837600034816%Z.   (* 2^1023 *)
Definition f64_two_pow_m969_bits := 243194379878006784%Z.    (* 2^-969 = 2^-1022 * 2^53 *)
Definition f64_exp_bias          := 1023%Z.
Definition f64_half_exp          := 1022%Z.                  (* biased exponent of a float in [0.5, 1) *)

(* [frshiftexp] / [ldshiftexp] bias the exponent by [shift = 2 * emax + prec],
   see Corelib.Floats.FloatOps. *)
Definition float_shift := 2101%Z.

(* [frshiftexp] returns (biased exponent) - f64_half_exp + float_shift *)
Definition frshiftexp_bias := 1079%Z.   (* = float_shift - f64_half_exp *)


Section TRANSLATION.

Variables glob_mem_ptr glob_tmp1 glob_tmp2 : globalidx.

Definition load_local_f64 (i : localidx) : list basic_instruction :=
  [ BI_local_get i ; BI_load T_f64 None {| memarg_offset:=0%N; memarg_align:=2%N |} ].

(* [instrs] leaves a single value of type [t] on the stack; store it at
   glob_mem_ptr, leave its address on the stack and bump glob_mem_ptr *)
Definition box_result (t : number_type) (instrs : list basic_instruction) : list basic_instruction :=
  BI_global_get glob_mem_ptr ::
  instrs ++
  [ BI_store t None {| memarg_offset:=0%N; memarg_align:=2%N |}
  ; BI_global_get glob_mem_ptr
  ] ++ increment_glob_mem_ptr glob_mem_ptr 8%N.

(* an f64 literal, given by its bit pattern: Wasm has no way to spell one otherwise *)
Definition f64_const (bits : Z) : list basic_instruction :=
  [ BI_const_num (Z_to_VAL_i64 bits) ; BI_cvtop T_f64 CVO_reinterpret T_i64 None ].

(* unboxed representation of a nullary constructor *)
Definition unboxed_ord (ord : N) : list basic_instruction :=
  [ BI_const_num (N_to_VAL_i32 (2 * ord + 1)) ].


(** ** Operations that are a single Wasm instruction *)

Definition primfloat_binop (op : binop_f) (x y : localidx) : list basic_instruction :=
  box_result T_f64 (load_local_f64 x ++ load_local_f64 y ++ [ BI_binop T_f64 (Binop_f op) ]).

Definition primfloat_unop (op : unop_f) (x : localidx) : list basic_instruction :=
  box_result T_f64 (load_local_f64 x ++ [ BI_unop T_f64 (Unop_f op) ]).

(* the argument is a uint63, so it is always in range for an unsigned conversion *)
Definition primfloat_of_uint63_instrs (x : localidx) : list basic_instruction :=
  box_result T_f64 (load_local_i64 x ++ [ BI_cvtop T_f64 CVO_convert T_i64 (Some SX_U) ]).

(* eqb / ltb / leb: the Wasm relops are the IEEE754 ones, like the Rocq primitives *)
Definition primfloat_boolean_comparison (op : relop_f) (x y : localidx) : list basic_instruction :=
  load_local_f64 x ++ load_local_f64 y ++
  [ BI_relop T_f64 (Relop_f op)
  ; BI_if (BT_valtype (Some (T_num T_i32)))
      (unboxed_ord true_ord)
      (unboxed_ord false_ord)
  ].


(** ** Bit-level accessors *)

Definition f64_exponent_field (x : localidx) : list basic_instruction :=
  load_local_i64 x ++
  [ BI_const_num (Z_to_VAL_i64 52) ; BI_binop T_i64 (Binop_i (BOI_shr SX_U))
  ; BI_const_num (Z_to_VAL_i64 f64_exp_mask) ; BI_binop T_i64 (Binop_i BOI_and) ].

Definition f64_mantissa_field (x : localidx) : list basic_instruction :=
  load_local_i64 x ++
  [ BI_const_num (Z_to_VAL_i64 f64_mant_mask) ; BI_binop T_i64 (Binop_i BOI_and) ].

(* the sign bit, which is set for -0 and for negative NaNs too *)
Definition f64_is_negative (x : localidx) : list basic_instruction :=
  load_local_i64 x ++
  [ BI_const_num (Z_to_VAL_i64 0) ; BI_relop T_i64 (Relop_i (ROI_lt SX_S)) ].

Definition if_negative (x : localidx) (neg pos : list basic_instruction) : list basic_instruction :=
  f64_is_negative x ++ [ BI_if (BT_valtype (Some (T_num T_i32))) neg pos ].


(** ** compare *)

Definition primfloat_compare_instrs (x y : localidx) : list basic_instruction :=
  load_local_f64 x ++ load_local_f64 y ++
  [ BI_relop T_f64 (Relop_f ROF_lt)
  ; BI_if (BT_valtype (Some (T_num T_i32)))
      (unboxed_ord FLt_ord)
      (load_local_f64 x ++ load_local_f64 y ++
       [ BI_relop T_f64 (Relop_f ROF_gt)
       ; BI_if (BT_valtype (Some (T_num T_i32)))
           (unboxed_ord FGt_ord)
           (load_local_f64 x ++ load_local_f64 y ++
            [ BI_relop T_f64 (Relop_f ROF_eq)
            ; BI_if (BT_valtype (Some (T_num T_i32)))
                (unboxed_ord FEq_ord)
                (* neither <, > nor =: at least one operand is a NaN *)
                (unboxed_ord FNotComparable_ord)
            ])
       ])
  ].


(** ** classify *)

Definition primfloat_classify_instrs (x : localidx) : list basic_instruction :=
  f64_exponent_field x ++
  [ BI_const_num (Z_to_VAL_i64 f64_exp_mask) ; BI_relop T_i64 (Relop_i ROI_eq)
  ; BI_if (BT_valtype (Some (T_num T_i32)))
      (* exponent field all ones: infinity or NaN *)
      (f64_mantissa_field x ++
       [ BI_testop T_i64 TO_eqz
       ; BI_if (BT_valtype (Some (T_num T_i32)))
           (if_negative x (unboxed_ord NInf_ord) (unboxed_ord PInf_ord))
           (unboxed_ord NaN_ord)
       ])
      (f64_exponent_field x ++
       [ BI_testop T_i64 TO_eqz
       ; BI_if (BT_valtype (Some (T_num T_i32)))
           (* exponent field zero: zero or subnormal *)
           (f64_mantissa_field x ++
            [ BI_testop T_i64 TO_eqz
            ; BI_if (BT_valtype (Some (T_num T_i32)))
                (if_negative x (unboxed_ord NZero_ord) (unboxed_ord PZero_ord))
                (if_negative x (unboxed_ord NSubn_ord) (unboxed_ord PSubn_ord))
            ])
           (if_negative x (unboxed_ord NNormal_ord) (unboxed_ord PNormal_ord))
       ])
  ].


(** ** normfr_mantissa

    The mantissa of a float in [0.5, 1), i.e. one whose biased exponent is
    f64_half_exp, with the hidden bit made explicit; 0 for every other float. *)

Definition primfloat_normfr_mantissa_instrs (x : localidx) : list basic_instruction :=
  box_result T_i64
    (f64_exponent_field x ++
     [ BI_const_num (Z_to_VAL_i64 f64_half_exp) ; BI_relop T_i64 (Relop_i ROI_eq)
     ; BI_if (BT_valtype (Some (T_num T_i64)))
         (f64_mantissa_field x ++
          [ BI_const_num (Z_to_VAL_i64 f64_hidden_bit) ; BI_binop T_i64 (Binop_i BOI_or) ])
         [ BI_const_num (Z_to_VAL_i64 0) ]
     ]).


(** ** frshiftexp

    Splits x into a fraction in [0.5, 1) and an exponent biased by float_shift,
    returning the pair.  NaN, the infinities and the zeros are returned
    unchanged with exponent 0. *)

(* glob_tmp1 := the bits of x, glob_tmp2 := 0 *)
Definition frshiftexp_unchanged (x : localidx) : list basic_instruction :=
  load_local_i64 x ++
  [ BI_global_set glob_tmp1
  ; BI_const_num (Z_to_VAL_i64 0) ; BI_global_set glob_tmp2 ].

Definition primfloat_frshiftexp_instrs (x : localidx) : list basic_instruction :=
  f64_exponent_field x ++
  [ BI_const_num (Z_to_VAL_i64 f64_exp_mask) ; BI_relop T_i64 (Relop_i ROI_eq)
  ; BI_if (BT_valtype None)
      (* infinity or NaN *)
      (frshiftexp_unchanged x)
      (load_local_i64 x ++
       [ BI_const_num (Z_to_VAL_i64 f64_abs_mask) ; BI_binop T_i64 (Binop_i BOI_and)
       ; BI_testop T_i64 TO_eqz
       ; BI_if (BT_valtype None)
           (* +0 or -0 *)
           (frshiftexp_unchanged x)
           (* finite and nonzero: glob_tmp1 := bits of a normal float with the same
              significand as x, glob_tmp2 := the correction its scaling introduced *)
           (f64_exponent_field x ++
            [ BI_testop T_i64 TO_eqz
            ; BI_if (BT_valtype None)
                (* subnormal: scaling by 2^54 is exact and makes it normal *)
                (load_local_f64 x ++ f64_const f64_two_pow_54_bits ++
                 [ BI_binop T_f64 (Binop_f BOF_mul)
                 ; BI_cvtop T_i64 CVO_reinterpret T_f64 None
                 ; BI_global_set glob_tmp1
                 ; BI_const_num (Z_to_VAL_i64 (-54)) ; BI_global_set glob_tmp2 ])
                (frshiftexp_unchanged x)
            ] ++
            (* exponent := biased exponent of glob_tmp1 + frshiftexp_bias + correction *)
            [ BI_global_get glob_tmp1
            ; BI_const_num (Z_to_VAL_i64 52) ; BI_binop T_i64 (Binop_i (BOI_shr SX_U))
            ; BI_const_num (Z_to_VAL_i64 f64_exp_mask) ; BI_binop T_i64 (Binop_i BOI_and)
            ; BI_const_num (Z_to_VAL_i64 frshiftexp_bias) ; BI_binop T_i64 (Binop_i BOI_add)
            ; BI_global_get glob_tmp2 ; BI_binop T_i64 (Binop_i BOI_add)
            ; BI_global_set glob_tmp2
            (* fraction := sign and significand of glob_tmp1, exponent field of [0.5, 1) *)
            ; BI_global_get glob_tmp1
            ; BI_const_num (Z_to_VAL_i64 f64_sign_mant_mask) ; BI_binop T_i64 (Binop_i BOI_and)
            ; BI_const_num (Z_to_VAL_i64 f64_half_exp_bits) ; BI_binop T_i64 (Binop_i BOI_or)
            ; BI_global_set glob_tmp1
            ])
       ])
  ] ++ make_product glob_mem_ptr glob_tmp1 glob_tmp2.


(** ** ldshiftexp

    x * 2 ^ (e - float_shift).  Follows the usual scalbn implementation: bring
    the exponent into a range where 2 ^ n is a representable float by peeling
    off at most two extreme factors, which keeps every intermediate rounding
    correct (in particular, the final n < -53 rules out double rounding in the
    subnormal range). *)

(* glob_tmp1 *= 2 ^ scale, glob_tmp2 += delta *)
Definition ldshiftexp_scale (scale_bits delta : Z) : list basic_instruction :=
  [ BI_global_get glob_tmp1 ; BI_cvtop T_f64 CVO_reinterpret T_i64 None ] ++
  f64_const scale_bits ++
  [ BI_binop T_f64 (Binop_f BOF_mul)
  ; BI_cvtop T_i64 CVO_reinterpret T_f64 None
  ; BI_global_set glob_tmp1
  ; BI_global_get glob_tmp2
  ; BI_const_num (Z_to_VAL_i64 delta) ; BI_binop T_i64 (Binop_i BOI_add)
  ; BI_global_set glob_tmp2
  ].

(* while glob_tmp2 is beyond [limit], scale it back; after [depth] rounds, saturate *)
Fixpoint ldshiftexp_adjust (test : relop_i) (limit scale_bits delta : Z) (depth : nat)
  : list basic_instruction :=
  [ BI_global_get glob_tmp2
  ; BI_const_num (Z_to_VAL_i64 limit) ; BI_relop T_i64 (Relop_i test)
  ; BI_if (BT_valtype None)
      (match depth with
       | O => [ BI_const_num (Z_to_VAL_i64 limit) ; BI_global_set glob_tmp2 ]
       | S depth' =>
           ldshiftexp_scale scale_bits delta ++
           ldshiftexp_adjust test limit scale_bits delta depth'
       end)
      []
  ].

Definition primfloat_ldshiftexp_instrs (x y : localidx) : list basic_instruction :=
  (* glob_tmp1 := the bits of x, glob_tmp2 := e - float_shift *)
  load_local_i64 x ++ [ BI_global_set glob_tmp1 ] ++
  load_local_i64 y ++
  [ BI_const_num (Z_to_VAL_i64 float_shift) ; BI_binop T_i64 (Binop_i BOI_sub)
  ; BI_global_set glob_tmp2 ] ++
  (* e is a uint63, so glob_tmp2 >= -float_shift and only the upper end can run away *)
  ldshiftexp_adjust (ROI_gt SX_S) 1023    f64_two_pow_1023_bits (-1023) 2 ++
  ldshiftexp_adjust (ROI_lt SX_S) (-1022) f64_two_pow_m969_bits 969     2 ++
  box_result T_f64
    [ BI_global_get glob_tmp1 ; BI_cvtop T_f64 CVO_reinterpret T_i64 None
    (* 2 ^ glob_tmp2, which is now a normal float *)
    ; BI_global_get glob_tmp2
    ; BI_const_num (Z_to_VAL_i64 f64_exp_bias) ; BI_binop T_i64 (Binop_i BOI_add)
    ; BI_const_num (Z_to_VAL_i64 52) ; BI_binop T_i64 (Binop_i BOI_shl)
    ; BI_cvtop T_f64 CVO_reinterpret T_i64 None
    ; BI_binop T_f64 (Binop_f BOF_mul)
    ].


(** ** next_up / next_down

    Away from zero the neighbour is one step in the bit pattern, which crosses
    the subnormal/normal boundary and the finite/infinite one by itself; only
    NaN, the infinity the step would run past, and the zeros need a case. *)

Definition f64_is_nan (x : localidx) : list basic_instruction :=
  load_local_f64 x ++ load_local_f64 x ++ [ BI_relop T_f64 (Relop_f ROF_ne) ].

(* true for both +0 and -0 *)
Definition f64_is_zero (x : localidx) : list basic_instruction :=
  load_local_f64 x ++ f64_const 0 ++ [ BI_relop T_f64 (Relop_f ROF_eq) ].

Definition f64_bits_eq (x : localidx) (bits : Z) : list basic_instruction :=
  load_local_i64 x ++
  [ BI_const_num (Z_to_VAL_i64 bits) ; BI_relop T_i64 (Relop_i ROI_eq) ].

Definition f64_bits_step (x : localidx) (op : binop_i) : list basic_instruction :=
  load_local_i64 x ++
  [ BI_const_num (Z_to_VAL_i64 1) ; BI_binop T_i64 (Binop_i op) ].

(* [fixpoint_bits] is the infinity that is its own neighbour, [zero_result] the
   neighbour of the zeros, [pos_step] / [neg_step] the step to take on a float
   with the sign bit clear / set *)
Definition primfloat_next_instrs (x : localidx) (fixpoint_bits zero_result : Z)
  (pos_step neg_step : binop_i) : list basic_instruction :=
  box_result T_i64
    (f64_is_nan x ++
     [ BI_if (BT_valtype (Some (T_num T_i64)))
         (load_local_i64 x)
         (f64_bits_eq x fixpoint_bits ++
          [ BI_if (BT_valtype (Some (T_num T_i64)))
              (load_local_i64 x)
              (f64_is_zero x ++
               [ BI_if (BT_valtype (Some (T_num T_i64)))
                   [ BI_const_num (Z_to_VAL_i64 zero_result) ]
                   (f64_is_negative x ++
                    [ BI_if (BT_valtype (Some (T_num T_i64)))
                        (f64_bits_step x neg_step)
                        (f64_bits_step x pos_step) ])
               ])
          ])
     ]).

Definition primfloat_next_up_instrs (x : localidx) : list basic_instruction :=
  primfloat_next_instrs x f64_pos_inf_bits f64_min_subn_bits BOI_add BOI_sub.

Definition primfloat_next_down_instrs (x : localidx) : list basic_instruction :=
  primfloat_next_instrs x f64_neg_inf_bits f64_neg_min_subn_bits BOI_sub BOI_add.


(** ** Dispatch *)

Definition translate_primitive_float_unary_op (op : primfloatop) (x : localidx)
  : error (list basic_instruction) :=
  match op with
  | PrimFloatsqrt            => Ret (primfloat_unop UOF_sqrt x)
  | PrimFloatabs             => Ret (primfloat_unop UOF_abs x)
  | PrimFloatopp             => Ret (primfloat_unop UOF_neg x)
  | PrimFloatclassify        => Ret (primfloat_classify_instrs x)
  | PrimFloatof_uint63       => Ret (primfloat_of_uint63_instrs x)
  | PrimFloatnormfr_mantissa => Ret (primfloat_normfr_mantissa_instrs x)
  | PrimFloatfrshiftexp      => Ret (primfloat_frshiftexp_instrs x)
  | PrimFloatnext_up         => Ret (primfloat_next_up_instrs x)
  | PrimFloatnext_down       => Ret (primfloat_next_down_instrs x)
  | _ => Err "Unknown primitive float unary operator"
  end.

Definition translate_primitive_float_binary_op (op : primfloatop) (x y : localidx)
  : error (list basic_instruction) :=
  match op with
  | PrimFloatadd         => Ret (primfloat_binop BOF_add x y)
  | PrimFloatsub         => Ret (primfloat_binop BOF_sub x y)
  | PrimFloatmul         => Ret (primfloat_binop BOF_mul x y)
  | PrimFloatdiv         => Ret (primfloat_binop BOF_div x y)
  | PrimFloateqb         => Ret (primfloat_boolean_comparison ROF_eq x y)
  | PrimFloatltb         => Ret (primfloat_boolean_comparison ROF_lt x y)
  | PrimFloatleb         => Ret (primfloat_boolean_comparison ROF_le x y)
  | PrimFloatcompare     => Ret (primfloat_compare_instrs x y)
  | PrimFloatldshiftexp  => Ret (primfloat_ldshiftexp_instrs x y)
  | _ => Err "Unknown primitive float binary operator"
  end.

End TRANSLATION.


(** ** Float literals

    The binary64 bit pattern of a primitive float, via its spec_float view
    (which is what the kernel exposes, see Corelib.Floats.FloatOps).
    [S754_finite s m e] denotes m * 2^e, with m < 2^52 exactly for the
    subnormals, whose biased exponent is 0. *)

Definition bits_of_primfloat (f : PrimFloat.float) : Z :=
  let sign_bit (s : bool) := if s then 9223372036854775808%Z (* 2^63 *) else 0%Z in
  match FloatOps.Prim2SF f with
  | SpecFloat.S754_zero s     => sign_bit s
  | SpecFloat.S754_infinity s => Z.add (sign_bit s) f64_pos_inf_bits
  (* the kernel identifies all NaNs, so any NaN pattern will do *)
  | SpecFloat.S754_nan        => 9221120237041090560%Z (* 0x7FF8000000000000 *)
  | SpecFloat.S754_finite s m e =>
      Z.add (sign_bit s)
        (if (Z.pos m <? f64_hidden_bit)%Z
         then Z.pos m
         else Z.add (Z.mul (Z.add e 1075) f64_hidden_bit) (Z.sub (Z.pos m) f64_hidden_bit))
  end.
