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


exception SyntaxError of string

let cut_at s (c : char) =
  try
    let i = String.rindex s c in
    let fst = String.sub s 0 i in
    let snd =
      if i + 1 = String.length s then ""
      else String.sub s (i + 1) (String.length s - i - 1)
    in
    (fst, snd)
  with Not_found ->
    raise
      (SyntaxError
         (Stdlib.String.concat ""
            [ "MOONC_INTERNAL_PARAMS: missing '"; Char.escaped c; "' in "; s ]))

let parse_args params =
  if String.equal params "" then ([], [])
  else
    let before, after = cut_at params '|' in
    let before =
      String.split_on_char ',' before
      |> List.filter (fun s -> not (String.equal s ""))
      |> List.map (fun kv ->
             let k, v = cut_at kv '=' in
             (String.trim k, String.trim v))
    in
    let after =
      String.split_on_char ',' after
      |> List.filter (fun s -> not (String.equal s ""))
      |> List.map (fun kv ->
             let k, v = cut_at kv '=' in
             (String.trim k, String.trim v))
    in
    (before, after)

let exec_args (params : (string * string) list) =
  let exec param =
    match param with
    | "plain_wat", tag ->
        if String.equal tag "1" then
          Driver_config.Common_Opt.wat_plain_mode := true;
        if String.equal tag "0" then
          Driver_config.Common_Opt.wat_plain_mode := false
    | _ -> ()
  in
  List.iter exec params

let moonc_internal_params () =
  match Sys.getenv_opt "MOONC_INTERNAL_PARAMS" with None -> "" | Some s -> s
