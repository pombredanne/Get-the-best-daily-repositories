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


module Vec = Basic_vec
module Token_triple = Lex_token_triple
module Menhir_token = Lex_menhir_token
module Vec_token = Lex_vec_token

type triple = Token_triple.t
type t = { mutable cur : int; tokens : triple array; start : int; len : int }

let dummy_segment = { cur = 0; tokens = [||]; start = 0; len = 0 }

let get_start_pos t =
  let _, spos, _ = t.tokens.(t.start) in
  spos

let sexp_of_t (x : t) =
  let start = x.start in
  let len = x.len in
  let beg_line =
    let _, spos, _ = x.tokens.(start) in
    spos.pos_lnum
  in
  let end_line =
    let _, _, epos = x.tokens.(start + len - 1) in
    epos.pos_lnum
  in
  let s =
    Stdlib.String.concat ""
      [
        "seg:";
        Int.to_string start;
        "-";
        Int.to_string len;
        " (line ";
        Int.to_string beg_line;
        " to ";
        Int.to_string end_line;
        ")";
      ]
  in
  S.Atom s

let reset t = t.cur <- t.start

let from ~start ~len (vec : Vec_token.t) =
  { cur = start; tokens = Vec.unsafe_internal_array vec; start; len }

let rec next ?(comment = false) tokens : triple =
  if tokens.cur = tokens.start + tokens.len then
    let _, _, posb = tokens.tokens.(tokens.cur - 1) in
    (EOF, posb, posb)
  else
    let ((tok, _, _) as triple) = tokens.tokens.(tokens.cur) in
    tokens.cur <- tokens.cur + 1;
    match tok with
    | NEWLINE -> next ~comment tokens
    | COMMENT _ when not comment -> next ~comment tokens
    | _ -> triple

let rec next_with_lexbuf_update tokens (lexbuf : Lexing.lexbuf) :
    Menhir_token.token =
  if tokens.cur = tokens.start + tokens.len then (
    let _, posa, posb = tokens.tokens.(tokens.cur - 1) in
    lexbuf.lex_start_p <- posa;
    lexbuf.lex_curr_p <- posb;
    EOF)
  else
    let tok, posa, posb = tokens.tokens.(tokens.cur) in
    tokens.cur <- tokens.cur + 1;
    match tok with
    | COMMENT _ | NEWLINE -> next_with_lexbuf_update tokens lexbuf
    | _ ->
        lexbuf.lex_start_p <- posa;
        lexbuf.lex_curr_p <- posb;
        tok

let peek ?(comment = false) tokens : triple =
  let prv = tokens.cur in
  let triple = next ~comment tokens in
  tokens.cur <- prv;
  triple

let skip ?(comment = false) tokens = ignore (next ~comment tokens)

let peek_nth tokens n : triple =
  let prv = tokens.cur in
  let rec loop nth =
    let triple = next ~comment:false tokens in
    if nth = 0 then triple else loop (nth - 1)
  in
  let triple = loop n in
  tokens.cur <- prv;
  triple

let toplevel_segments ?(start = 0) (tokens : Vec_token.t) : t list =
  let rec get_slice_points index (topmost_related_comment : int option) acc =
    let tok, loca, _ = Vec.get tokens index in
    let left_aligned = loca.pos_cnum = loca.pos_bol in
    match tok with
    | PUB | PRIV | TYPE | STRUCT | ENUM | FN | LET | CONST | TRAIT | TEST | IMPL
    | EXTERN | TYPEALIAS
      when left_aligned ->
        let point =
          match topmost_related_comment with
          | Some top_index -> top_index
          | None -> index
        in
        get_slice_points (index + 1) None (point :: acc)
    | EOF -> List.rev (index :: acc)
    | COMMENT _ ->
        let topmost_related_comment =
          match topmost_related_comment with
          | None when left_aligned -> Some index
          | Some _ when not left_aligned -> None
          | _ -> topmost_related_comment
        in
        let next =
          if index + 2 < Vec.length tokens then index + 2 else index + 1
        in
        get_slice_points next topmost_related_comment acc
    | _ -> get_slice_points (index + 1) None acc
  in
  let rec slice ps =
    match ps with
    | l :: (r :: _ as remain) ->
        if r - l > 0 then
          let seg = from ~start:l ~len:(r - l) tokens in
          seg :: slice remain
        else slice remain
    | _ -> []
  in
  get_slice_points start None [ start ] |> slice

let next_segment_head t =
  let rec go i =
    match Basic_arr.get_opt t.tokens i with
    | None -> None
    | Some (tok, _, _) as triple -> (
        match tok with
        | EOF -> None
        | NEWLINE | COMMENT _ -> go (i + 1)
        | _ -> triple)
  in
  go (t.start + t.len)
