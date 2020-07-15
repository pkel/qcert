type s
type t

val create: unit -> s
val close_import: s -> t

type type_

val i32: type_
val i64: type_
val f32: type_
val f64: type_

type instr

val unreachable : instr
val nop : instr
val i32_const : int32 -> instr
val i32_const' : int -> instr

type cmp_op = Ge | Gt | Le | Lt

val i32s_cmp : cmp_op -> instr
val i32u_cmp : cmp_op -> instr
val i64s_cmp : cmp_op -> instr
val i64u_cmp : cmp_op -> instr
val f32_cmp : cmp_op -> instr
val f64_cmp : cmp_op -> instr

val eq : type_ -> instr
val add : type_ -> instr
val mul : type_ -> instr

val i32_and : instr
val i64_and : instr
val i32_or : instr
val i64_or : instr

(** {2} local variables *)

val local_get : int -> instr
val local_set : int -> instr
val local_tee : int -> instr

(** {2} control structure *)

val if_ :
  ?params: type_ list ->
  ?result: type_ list ->
  instr list -> instr list -> instr

val loop:
  ?params: type_ list ->
  ?result: type_ list -> instr list -> instr

val br: int -> instr
val br_if: int -> instr

val return : instr

(** {2} functions *)

type func

val func: t ->
  ?params: type_ list ->
  ?result: type_ list ->
  ?locals: type_ list ->
  instr list -> func

val import_func: s ->
  ?params: type_ list ->
  ?result: type_ list ->
  string -> string -> func

val call: func -> instr

(** {2} module *)

type 'a export = string * 'a

type interface =
  { start: func option
  ; funcs: func export list
  }

val module_to_spec: t -> interface -> Wasm.Ast.module_
