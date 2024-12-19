(*
   Copyright (C) 2024 International Digital Economy Academy.
   This program is licensed under the MoonBit Public Source
   License as published by the International Digital Economy Academy,
   either version 1 of the License, or (at your option) any later
   version. This program is distributed in the hope that it will be
   useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the MoonBit
   Public Source License for more details. You should have received a
   copy of the MoonBit Public Source License along with this program. If
   not, see
   <https://www.moonbitlang.com/licenses/moonbit-public-source-license-v1>.
*)


module Type_path = Basic_type_path

type impl = {
  trait : Type_path.t;
  self_ty : Stype.t;
  ty_params : Tvar_env.t;
  is_pub : bool;
  loc_ : Loc.t;
}

include struct
  let _ = fun (_ : impl) -> ()

  let sexp_of_impl =
    (fun {
           trait = trait__002_;
           self_ty = self_ty__004_;
           ty_params = ty_params__006_;
           is_pub = is_pub__008_;
           loc_ = loc___010_;
         } ->
       let bnds__001_ = ([] : _ Stdlib.List.t) in
       let bnds__001_ =
         let arg__011_ = Loc.sexp_of_t loc___010_ in
         (S.List [ S.Atom "loc_"; arg__011_ ] :: bnds__001_ : _ Stdlib.List.t)
       in
       let bnds__001_ =
         let arg__009_ = Moon_sexp_conv.sexp_of_bool is_pub__008_ in
         (S.List [ S.Atom "is_pub"; arg__009_ ] :: bnds__001_ : _ Stdlib.List.t)
       in
       let bnds__001_ =
         let arg__007_ = Tvar_env.sexp_of_t ty_params__006_ in
         (S.List [ S.Atom "ty_params"; arg__007_ ] :: bnds__001_
           : _ Stdlib.List.t)
       in
       let bnds__001_ =
         let arg__005_ = Stype.sexp_of_t self_ty__004_ in
         (S.List [ S.Atom "self_ty"; arg__005_ ] :: bnds__001_
           : _ Stdlib.List.t)
       in
       let bnds__001_ =
         let arg__003_ = Type_path.sexp_of_t trait__002_ in
         (S.List [ S.Atom "trait"; arg__003_ ] :: bnds__001_ : _ Stdlib.List.t)
       in
       S.List bnds__001_
      : impl -> S.t)

  let _ = sexp_of_impl
end

module H = Basic_hashf.Make (struct
  type t = Type_path.t * Type_path.t

  include struct
    let _ = fun (_ : t) -> ()

    let sexp_of_t =
      (fun (arg0__012_, arg1__013_) ->
         let res0__014_ = Type_path.sexp_of_t arg0__012_
         and res1__015_ = Type_path.sexp_of_t arg1__013_ in
         S.List [ res0__014_; res1__015_ ]
        : t -> S.t)

    let _ = sexp_of_t

    let equal =
      (fun a__016_ b__017_ ->
         let t__018_, t__019_ = a__016_ in
         let t__020_, t__021_ = b__017_ in
         Stdlib.( && )
           (Type_path.equal t__018_ t__020_)
           (Type_path.equal t__019_ t__021_)
        : t -> t -> bool)

    let _ = equal

    let (hash_fold_t : Ppx_base.state -> t -> Ppx_base.state) =
     fun hsv arg ->
      let e0, e1 = arg in
      let hsv = Type_path.hash_fold_t hsv e0 in
      let hsv = Type_path.hash_fold_t hsv e1 in
      hsv

    let _ = hash_fold_t

    let (hash : t -> Ppx_base.hash_value) =
      let func arg =
        Ppx_base.get_hash_value
          (let hsv = Ppx_base.create () in
           hash_fold_t hsv arg)
      in
      fun x -> func x

    let _ = hash
  end
end)

type t = impl H.t

include struct
  let _ = fun (_ : t) -> ()
  let sexp_of_t = (fun x__022_ -> H.sexp_of_t sexp_of_impl x__022_ : t -> S.t)
  let _ = sexp_of_t
end

let make () = H.create 17
let find_impl (impls : t) ~trait ~type_name = H.find_opt impls (trait, type_name)

let add_impl (impls : t) ~trait ~type_name impl =
  H.add impls (trait, type_name) impl

let update (impls : t) ~trait ~type_name f =
  H.update_if_exists impls (trait, type_name) f

let iter (impls : t) f =
  H.iter2 impls (fun (trait, type_name) impl -> f ~trait ~type_name impl)

let get_pub_impls (impls : t) =
  H.to_array_filter_map impls (fun (_, impl) ->
      if impl.is_pub then Some impl else None)
