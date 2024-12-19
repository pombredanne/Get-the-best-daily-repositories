%{
(* Copyright International Digital Economy Academy, all rights reserved *)
[%%use
Parsing_util.(
  ( i
  , enter_next_block
  , aloc
  , label_to_expr
  , label_to_pat
  , make_field_def
  , make_field_pat
  , make_uminus
  , make_uplus
  , make_Pexpr_array
  , make_Pexpr_constant
  , make_Pexpr_ident
  , make_interps
  , make_Pexpr_interp
  , make_Pexpr_record
  , make_Pexpr_tuple
  , make_Ppat_alias
  , make_Ppat_constr
  , make_Ppat_constant
  , make_Ppat_tuple
  , make_Ptype_option
  , make_Ptype_tuple ))]
%}

%token <Lex_literal.char_literal> CHAR
%token <string> INT
%token <Lex_literal.byte_literal> BYTE
%token <Lex_literal.bytes_literal> BYTES
%token <string> FLOAT
%token <Lex_literal.string_literal> STRING
%token <string> MULTILINE_STRING
%token <Lex_literal.interp_literal> MULTILINE_INTERP
%token <Lex_literal.interp_literal> INTERP
%token <string> LIDENT
%token <string> UIDENT
%token <string> LABEL
%token <string> POST_LABEL
%token <Comment.t> COMMENT
%token NEWLINE
%token <string> INFIX1
%token <string> INFIX2
%token <string> INFIX3
%token <string> INFIX4
%token <string> AUGMENTED_ASSIGNMENT

%token EOF
%token FALSE
%token TRUE
%token PUB             "pub"
%token PRIV            "priv"
%token READONLY        "readonly"
%token IMPORT          "import"
%token EXTERN          "extern"
%token BREAK           "break"
%token CONTINUE        "continue"
%token STRUCT          "struct"
%token ENUM            "enum"
%token TRAIT           "trait"
%token DERIVE          "derive"
%token IMPL            "impl"
%token WITH            "with"
%token RAISE           "raise"
%token THROW           "throw"
%token TRY             "try"
%token CATCH           "catch"
// %token EXCEPT          "except"
%token TYPEALIAS       "typealias"
%token EQUAL           "="

%token LPAREN          "("
%token RPAREN          ")"

%token COMMA          ","
%token MINUS           "-"
%token QUESTION        "?"
%token EXCLAMATION     "!"

%token <string>DOT_LIDENT
%token <string>DOT_UIDENT
%token <int>DOT_INT
%token COLONCOLON      "::"
%token COLON           ":"
%token <bool>SEMI
%token LBRACKET        "["
%token PLUS           "+"
%token RBRACKET       "]"

%token UNDERSCORE      "_"
%token BAR             "|"

%token LBRACE          "{"
%token RBRACE          "}"

%token AMPERAMPER     "&&"
%token AMPER     "&"
%token CARET     "^"
%token BARBAR          "||"
%token <string>PACKAGE_NAME
/* Keywords */

%token AS              "as"
%token PIPE            "|>"
%token ELSE            "else"
%token FN            "fn"
%token IF             "if"
%token LET            "let"
%token CONST          "const"
%token MATCH          "match"
%token MUTABLE        "mut"
%token TYPE            "type"
%token FAT_ARROW       "=>"
%token THIN_ARROW      "->"
%token WHILE           "while"
%token RETURN          "return"
%token DOTDOT          ".."
%token RANGE_INCLUSIVE "..="
%token RANGE_EXCLUSIVE "..<"
%token ELLIPSIS        "..."
%token TEST            "test"
%token LOOP            "loop"
%token GUARD           "guard"

%token FOR             "for"
%token IN              "in"

%right BARBAR
%right AMPERAMPER

%nonassoc RANGE_EXCLUSIVE RANGE_INCLUSIVE

%left BAR
%left CARET
%left AMPER

// x.f(...) should be [Pexpr_dot_apply], not [Pexpr_apply(Pexpr_field, ...)]
// these two precedences are used to resolve this.
%nonassoc prec_field
%nonassoc LPAREN
%left INFIX1 // > < == != <= >=
%left INFIX2 // << >>
%left PLUS MINUS
%left INFIX3 // * / % 
%left INFIX4 // not used
%nonassoc prec_type
%nonassoc prec_apply_non_ident_fn
%nonassoc "!"
%nonassoc "?"
%start    structure
%start    expression


%type <Parsing_syntax.expr> expression
%type <Parsing_syntax.impls> structure
%type <Parsing_compact.semi_expr_prop > statement
%%

non_empty_list_rev(X):
  | x = X  { [x] }
  | xs = non_empty_list_rev(X) x = X { x::xs }

non_empty_list(X):
  | xs = non_empty_list_rev(X) { List.rev xs }

non_empty_list_commas_rev(X):
  | x = X  { [x] }
  | xs=non_empty_list_commas_rev(X) "," x=X { x::xs}

non_empty_list_commas_no_trailing(X):
  | xs = non_empty_list_commas_rev(X) { List.rev xs }

non_empty_list_commas( X):
  | xs = non_empty_list_commas_rev(X) ; ioption(",") {List.rev xs}

non_empty_list_commas_with_tail (X):
  | xs = non_empty_list_commas_rev(X); "," {List.rev xs}

%inline list_commas( X):
  | {[]}
  | non_empty_list_commas(X) {$1}

%inline list_commas_no_trailing(X):
  | { [] }
  | non_empty_list_commas_no_trailing(X) { $1 }

non_empty_list_commas_with_trailing_info(X):
  | xs = non_empty_list_commas_rev(X); comma=ioption(",") { (List.rev xs, Option.is_some comma) }

%inline list_commas_with_trailing_info(X):
  | {([], false)}
  | non_empty_list_commas_with_trailing_info(X) { $1 }

non_empty_list_semi_rev_aux(X):
  | x = X  { [x] }
  | xs=non_empty_list_semi_rev_aux(X) ; SEMI ;  x=X { x::xs}

%inline non_empty_list_semis_rev(X):
  | xs = non_empty_list_semi_rev_aux(X) ; ioption(SEMI) {xs}

%inline none_empty_list_semis_rev_with_trailing_info(X):
  | xs = non_empty_list_semi_rev_aux(X) ; semi=ioption(SEMI) { (xs, Option.is_some semi) }

non_empty_list_semis(X):
  | non_empty_list_semis_rev(X) {List.rev $1 }

%inline list_semis_rev(X):
  | {[]}
  | non_empty_list_semis_rev(X) {$1}

%inline list_semis(X):
  | {[]}
  | non_empty_list_semis(X){$1}

%inline id(x): x {$1}
%inline annot: ":" t=type_ {t}
%inline opt_annot: ioption(annot) {$1}

fn_label:
  | LABEL { { Parsing_syntax.label_name = $1; loc_ = i $sloc } }
;

parameter:
  (* binder : Type *)
  | param_binder=binder param_annot=opt_annot {
    { Parsing_syntax.param_binder; param_annot; param_kind = Positional }
  }
  (* Deprecated syntax. ~binder : Type *)
  | label=fn_label param_annot=opt_annot {
    let param_binder : Parsing_syntax.binder =
      { binder_name = label.Parsing_syntax.label_name; loc_ = Rloc.trim_first_char label.loc_ }
    in
    { Parsing_syntax.param_binder; param_annot; param_kind = Labelled }
  }
  (* Deprecated syntax. ~binder : Type = expr *)
  | label=fn_label param_annot=opt_annot "=" default=expr {
    let param_binder : Parsing_syntax.binder =
      { binder_name = label.Parsing_syntax.label_name; loc_ = Rloc.trim_first_char label.loc_ }
    in
    { Parsing_syntax.param_binder; param_annot; param_kind = Optional { default } }
  }
  (* Deprecated syntax. ~binder? : Type = expr *)
  | label=fn_label "?" param_annot=opt_annot {
    let param_binder : Parsing_syntax.binder =
      { binder_name = label.Parsing_syntax.label_name; loc_ = Rloc.trim_first_char label.loc_ }
    in
    { Parsing_syntax.param_binder; param_annot; param_kind = Question_optional }
  }
  (* binder~ : Type *)
  | binder_name=POST_LABEL param_annot=opt_annot {
    let param_binder : Parsing_syntax.binder =
      { binder_name; loc_ = Rloc.trim_last_char (i $loc(binder_name)) }
    in
    { Parsing_syntax.param_binder; param_annot; param_kind = Labelled }
  }
  (* binder~ : Type = expr *)
  | binder_name=POST_LABEL param_annot=opt_annot "=" default=expr {
    let param_binder : Parsing_syntax.binder =
      { binder_name; loc_ = Rloc.trim_last_char (i $loc(binder_name)) }
    in
    { Parsing_syntax.param_binder; param_annot; param_kind = Optional { default } }
  }
  (* binder? : Type = expr *)
  | binder_name=LIDENT "?" param_annot=opt_annot {
    let param_binder : Parsing_syntax.binder =
      { binder_name; loc_ = i $loc(binder_name) }
    in
    { Parsing_syntax.param_binder; param_annot; param_kind = Question_optional }
  }
;

%inline parameters : delimited("(",list_commas(parameter), ")") {$1}

type_parameters:
  | delimited("[",non_empty_list_commas(id(tvar_binder)), "]") { $1 }

optional_type_parameters:
  | params = option(type_parameters) {
    match params with
    | None -> []
    | Some params -> params
   }
optional_type_parameters_no_constraints:
  | params = option(delimited("[",non_empty_list_commas(id(type_decl_binder)), "]")) {
    match params with
    | None -> []
    | Some params -> params
   }
optional_type_arguments:
  | params = option(delimited("[" ,non_empty_list_commas(type_), "]")) {
    match params with
    | None -> []
    | Some params -> params
  }
fun_binder:
 | type_name=type_name "::" func_name=LIDENT {
    let binder : Parsing_syntax.binder =
      { binder_name = func_name; loc_ = i ($loc(func_name)) }
    in
    (Some type_name, binder)
  }
  | binder { (None, $1) }
fun_header:
  pub=ioption("pub") "fn"
    fun_binder=fun_binder
    has_error=optional_bang
    quants=optional_type_parameters
    ps=option(parameters)
    ts=option("->" t=return_type{t})
    {
      let type_name, f = fun_binder in
      { Parsing_syntax.type_name; name = f; has_error; quantifiers = quants;
        decl_params = ps; params_loc_=(i $loc(ps)); return_type = ts; is_pub = pub <> None; doc_ = Docstring.empty }
    }

local_type_decl:
  | "struct" tycon=luident "{" fs=list_semis(record_decl_field) "}" {
    ({ local_tycon = tycon; local_tycon_loc_ = i $loc(tycon); local_components = Ptd_record fs }: Parsing_syntax.local_type_decl) }
  | "enum" tycon=luident "{" cs=list_semis(enum_constructor) "}" {
    ({ local_tycon = tycon; local_tycon_loc_ = i $loc(tycon); local_components = Ptd_variant cs }: Parsing_syntax.local_type_decl) }

extern_fun_header:
  pub=ioption("pub")
  "extern" language=STRING "fn"
    fun_binder=fun_binder
    has_error=optional_bang
    quants=optional_type_parameters
    ps=option(parameters)
    ts=option("->" t=return_type{t})
    {
      let type_name, f = fun_binder in
      language, { Parsing_syntax.type_name; name = f; has_error; quantifiers = quants;
        decl_params = ps; params_loc_=(i $loc(ps)); return_type = ts; is_pub = pub <> None; doc_ = Docstring.empty }
    }

%inline block_expr: "{" ls=list_semis_rev(statement) "}" {Parsing_compact.compact_rev ls (i $sloc)}

%inline block_expr_with_local_types: "{" ts=list_semis(local_type_decl) ls=list_semis_rev(statement) "}"
    { (ts, Parsing_compact.compact_rev ls (if ts = [] then i $sloc else i $loc(ls))) }

expression : expr EOF { $1 }

val_header :
  | pub=ioption("pub") "let" binder=binder t=opt_annot { false, pub <> None, binder, t}
  | pub=ioption("pub") "const" binder_name=UIDENT t=opt_annot {
    true, pub <> None, { Parsing_syntax.binder_name; loc_ = i $loc(binder_name) }, t
  }

structure : list_semis(structure_item) EOF {$1}
structure_item:
  | type_header=type_header deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_, params = type_header in
      Ptop_typedef { tycon; tycon_loc_; params; components = Ptd_abstract; type_vis; doc_ = Docstring.empty; deriving_; loc_ = aloc $sloc; }
    }
  | type_header=type_header ty=type_ deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_, params = type_header in
      Ptop_typedef { tycon; tycon_loc_; params; components = Ptd_newtype ty; type_vis; doc_ = Docstring.empty ; deriving_; loc_ = aloc $sloc }
    }
  | type_header=type_header_bang ty=option(type_) deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_ = type_header in
      let exception_decl: Parsing_syntax.exception_decl =
        match ty with | None -> No_payload | Some ty -> Single_payload ty
      in
      Ptop_typedef { tycon; tycon_loc_; params = []; components = Ptd_error exception_decl; type_vis; doc_ = Docstring.empty ; deriving_; loc_ = aloc $sloc }
    }
  | type_header=type_header_bang "{" cs=list_semis(enum_constructor) "}" deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_ = type_header in
      let exception_decl: Parsing_syntax.exception_decl = Enum_payload cs in
      Ptop_typedef { tycon; tycon_loc_; params = []; components = Ptd_error exception_decl; type_vis; doc_ = Docstring.empty ; deriving_; loc_ = aloc $sloc }
    }
  | type_header=type_alias_header "=" ty=type_ deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_, params = type_header in
      Ptop_typedef { tycon; tycon_loc_; params; components = Ptd_alias ty; type_vis; doc_ = Docstring.empty ; deriving_; loc_ = aloc $sloc }
    }
  | struct_header=struct_header "{" fs=list_semis(record_decl_field) "}" deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_, params = struct_header in
      Ptop_typedef { tycon; tycon_loc_; params; components = Ptd_record fs; type_vis; doc_ = Docstring.empty ; deriving_; loc_ = aloc $sloc}
    }
  | enum_header=enum_header "{" cs=list_semis(enum_constructor) "}" deriving_=deriving_directive_list {
      enter_next_block ();
      let type_vis, tycon, tycon_loc_, params = enum_header in
      Ptop_typedef { tycon; tycon_loc_; params; components = Ptd_variant cs; type_vis; doc_ = Docstring.empty ; deriving_; loc_ = aloc $sloc}
    }
  | val_header=val_header "=" expr = expr {
    enter_next_block ();
    let is_constant, is_pub, binder, ty = val_header in
    Ptop_letdef { binder; ty; expr; is_pub; is_constant; loc_ = aloc $sloc; doc_ = Docstring.empty }
  }
  | t=fun_header "=" mname=STRING fname=STRING {
      enter_next_block ();
      Parsing_syntax.Ptop_funcdef {
        loc_ = (aloc $sloc);
        fun_decl = t ;
        decl_body = Decl_stubs (Import {module_name = mname; func_name = fname });
      }
    }
  | t=fun_header "=" s=STRING {
      enter_next_block ();
      Parsing_syntax.Ptop_funcdef {
        loc_ = (aloc $sloc);
        fun_decl = t ;
        decl_body = Decl_stubs (Embedded { language = None; code = Code_string s });
      }
    }
  | t=fun_header "=" xs=non_empty_list(MULTILINE_STRING) {
      enter_next_block ();
      Parsing_syntax.Ptop_funcdef {
        loc_ = (aloc $sloc);
        fun_decl = t ;
        decl_body = Decl_stubs (Embedded { language = None; code = Code_multiline_string xs });
      }
    }
  | t=extern_fun_header "=" s=STRING {
      enter_next_block ();
      let language, decl = t in
      Parsing_syntax.Ptop_funcdef {
        loc_ = (aloc $sloc);
        fun_decl = decl ;
        decl_body = Decl_stubs (Embedded { language = Some language; code = Code_string s })
      }
    }
  | t=extern_fun_header "=" xs=non_empty_list(MULTILINE_STRING) {
      enter_next_block ();
      let language, decl = t in
      Parsing_syntax.Ptop_funcdef {
        loc_ = (aloc $sloc);
        fun_decl = decl ;
        decl_body = Decl_stubs (Embedded { language = Some language; code = Code_multiline_string xs });
      }
    }
  | t=fun_header body=block_expr_with_local_types {
      enter_next_block ();
      let local_types, body = body in
      Parsing_syntax.Ptop_funcdef {
        loc_ = (aloc $sloc);
        fun_decl = t;
        decl_body = Decl_body { expr=body; local_types };
      }
    }
  | vis=visibility "trait" name=luident
    supers=option(COLON separated_nonempty_list(PLUS, tvar_constraint) { $2 })
    "{" methods=list_semis(trait_method_decl) "}" {
      let trait_name : Parsing_syntax.binder = { binder_name = name; loc_ = i ($loc(name)) } in
      enter_next_block ();
      let supers =
        match supers with None -> [] | Some supers -> supers
      in
      Parsing_syntax.Ptop_trait {
        trait_name;
        trait_supers = supers;
        trait_methods = methods;
        trait_vis = vis;
        trait_loc_ = (aloc $sloc);
        trait_doc_ = Docstring.empty;
      }
    }
  | "test" name=option(loced_string) params=option(parameters) body=block_expr_with_local_types {
      enter_next_block ();
      let local_types, body = body in
      Parsing_syntax.Ptop_test {
        expr = body;
        name;
        params;
        local_types;
        loc_ = (aloc $sloc);
      }
  }
  | pub=ioption("pub")
    "impl"
      quantifiers=optional_type_parameters
      trait=type_name
    "for" self_ty=type_
    "with"
      method_name=binder
      has_error=optional_bang
      params=parameters ret_ty=ioption("->" return_type { $2 })
      body=block_expr_with_local_types
  {
    let header_loc_ = i ($startpos($2), $endpos(ret_ty)) in
    enter_next_block ();
    let local_types, body = body in
    Parsing_syntax.Ptop_impl
      { self_ty = Some self_ty
      ; trait
      ; method_name
      ; has_error
      ; quantifiers
      ; params
      ; ret_ty
      ; body
      ; is_pub = Option.is_some pub
      ; local_types
      ; header_loc_
      ; loc_ = aloc $sloc
      ; doc_ = Docstring.empty
      }
  }
  | pub=ioption("pub")
    "impl"
      quantifiers=optional_type_parameters
      trait=type_name
    "with"
      method_name=binder
      has_error=optional_bang
      params=parameters ret_ty=ioption("->" return_type { $2 })
      body=block_expr_with_local_types
  {
    let header_loc_ = i ($startpos($2), $endpos(ret_ty)) in
    enter_next_block ();
    let local_types, body = body in
    Parsing_syntax.Ptop_impl
      { self_ty = None
      ; trait
      ; method_name
      ; has_error
      ; quantifiers
      ; params
      ; ret_ty
      ; body
      ; is_pub = Option.is_some pub
      ; local_types
      ; header_loc_
      ; loc_ = aloc $sloc
      ; doc_ = Docstring.empty
      }
  }
  /*
  | pub=ioption("pub")
    "impl"
       quantifiers=optional_type_parameters
       trait=type_name
    "for" self_ty=type_
  {
    Parsing_syntax.Ptop_impl_relation
      { self_ty; trait; quantifiers; is_pub = Option.is_some pub; loc_ = i $sloc }
  }
  */

%inline visibility:
  | /* empty */ { Parsing_syntax.Vis_default }
  | "priv"      { Parsing_syntax.Vis_priv { loc_ = i $sloc } }
  | "pub" attr=pub_attr { Parsing_syntax.Vis_pub { attr; loc_ = i $sloc } }
pub_attr:
  | /* empty */ { None }
  | "(" "readonly" ")" { Some "readonly" }
  | "(" attr=LIDENT ")" { Some attr }
type_header: vis=visibility "type" tycon=luident params=optional_type_parameters_no_constraints {
  vis, tycon, i $loc(tycon), params
}
type_header_bang: vis=visibility "type" "!" tycon=luident {
  vis, tycon, i $loc(tycon)
}
type_alias_header: vis=visibility "typealias" tycon=luident params=optional_type_parameters_no_constraints {
  vis, tycon, i $loc(tycon), params
}
struct_header: vis=visibility "struct" tycon=luident params=optional_type_parameters_no_constraints {
  vis, tycon, i $loc(tycon), params
}
enum_header: vis=visibility "enum" tycon=luident params=optional_type_parameters_no_constraints {
  vis, tycon, i $loc(tycon), params
}

deriving_directive: 
  | type_name=type_name { 
      ({ type_name_ = type_name; loc_ = i $sloc; args = [] } : Parsing_syntax.deriving_directive)
    }
  | type_name=type_name "(" args=list_commas(argument) ")" { 
      ({ type_name_ = type_name; loc_ = i $sloc; args } : Parsing_syntax.deriving_directive)
    }

deriving_directive_list:
  | /* nothing */ { [] }
  | "derive" "(" list_commas(deriving_directive) ")" { $3 }

trait_method_decl:
  name=binder
  has_error=optional_bang
  quantifiers=optional_type_parameters
  "("
  params=list_commas(trait_method_param)
  ")"
  return_type=option("->" t=return_type{t})
  {
    Parsing_syntax.Trait_method {
      name;
      has_error;
      quantifiers;
      params;
      return_type;
      loc_ = i $sloc;
    }
  }

trait_method_param:
  | typ=type_ {
    { Parsing_syntax.tmparam_typ = typ; tmparam_label = None }
  }
  (* Deprecated. ~label : Type *)
  | label_name=LABEL ":" typ=type_ {
    let label = { Parsing_syntax.label_name; loc_ = Rloc.trim_first_char (i $loc(label_name)) } in
    { Parsing_syntax.tmparam_typ = typ; tmparam_label = Some label }
  }
  (* label~ : Type *)
  | label_name=POST_LABEL ":" typ=type_ {
    let label = { Parsing_syntax.label_name; loc_ = Rloc.trim_last_char (i $loc(label_name)) } in
    { Parsing_syntax.tmparam_typ = typ; tmparam_label = Some label }
  }

luident:
  | i=LIDENT
  | i=UIDENT { i }

qual_ident:
  | i=LIDENT { Lident(i) }
  | ps=PACKAGE_NAME id=DOT_LIDENT { Ldot({ pkg = ps; id}) }

qual_ident_simple_expr:
  /* This precedence declaration is used to disambiguate between:

     1. f(g?(...)) (error to result)
     2. f(l?=...) (forward optional argument)

     To disambiguate the two, we need to look at the token after "?" (LPAREN or EQUAL).
     But Menhir has only one token lookahead, so if reduction is needed on `g`/`l`,
     Menhir will complain for shift/reduce conflict.

     To solve this problem, here we:
     - add a specialized rule for the case of `LIDENT QUESTION LPAREN ... RPAREN`.
       Since no reduction is needed on the first LIDENT, this rule will not conflict with forwarding optional argument
     - make sure the general rule SIMPLE_EXPR QUESTION LPAREN ... RPAREN does not conflict with the specialized rule.
       This is done via the precedence declaration here.
       We assign higher precedence to shifting QUESTION than the LIDENT -> qual_ident -> simple_expr reduction chain,
       so that Menhir knows that the specialized rule has higher precedence.
  */
  | i=LIDENT %prec prec_apply_non_ident_fn { Lident(i) }
  | ps=PACKAGE_NAME id=DOT_LIDENT { Ldot({ pkg = ps; id}) }

qual_ident_ty:
  | i=luident { Lident(i) }
  | ps=PACKAGE_NAME id=DOT_LIDENT
  | ps=PACKAGE_NAME id=DOT_UIDENT { Ldot({ pkg = ps; id}) }

%inline semi_expr_semi_opt: none_empty_list_semis_rev_with_trailing_info(statement)  {
  let ls, trailing = $1 in
  (Parsing_compact.compact_rev ls (i $sloc), trailing)
}

%inline optional_bang:
  | "!" { true }
  | { false }

%inline fn_header:
  | "fn"  binder=binder has_error=optional_bang "{" { (binder, has_error) }

%inline fn_header_no_binder:
  | "fn" has_error=optional_bang "{" { has_error }

statement:
  | "let" pat=pattern ty_opt=opt_annot "=" expr=expr
    {
      let pat =
        match ty_opt with
        | None -> pat
        | Some ty ->
          Parsing_syntax.Ppat_constraint
                  {
                    pat;
                    ty;
                    loc_ =
                      Rloc.merge
                        (Parsing_syntax.loc_of_pattern pat)
                        (Parsing_syntax.loc_of_type_expression ty);
                  } in
      Stmt_let {pat; expr; loc=(i $sloc);  }}
  | "let" "mut" binder=binder ty=opt_annot "=" expr=expr
    { Stmt_letmut {binder; ty_opt=ty; expr; loc=(i $sloc)} }
  | "fn" binder=binder has_error=optional_bang params=parameters ty_opt=option("->" t=return_type {t}) block = block_expr
    {
      (* FIXME: `func` should have explicit return type in the ast *)
      let locb = i $sloc in
      let func : Parsing_syntax.func = Lambda { parameters = params; params_loc_ = (i $loc(params));body = block; return_type = ty_opt; kind_ = Lambda; has_error } in
      Parsing_compact.Stmt_func {binder; func; loc=locb}
    }
  | binder=fn_header cases=list_semis( pats=non_empty_list_commas(pattern) "=>" body=expr_statement { (pats, body) } ) "}"
    { let (binder, has_error) = binder in
      Parsing_compact.Stmt_func {binder; func = Match { cases; has_error; loc_ = i $loc(cases); fn_loc_ = i $loc(binder) }; loc=i $sloc} }
  | guard_statement { $1 }
  | expr_statement { Parsing_compact.Stmt_expr { expr = $1 } }

guard_statement: 
  | "guard" cond=infix_expr 
    { Parsing_compact.Stmt_guard { cond; otherwise=None; loc=(i $sloc) } }
  | "guard" cond=infix_expr "else" else_=block_expr 
    { Parsing_compact.Stmt_guard { cond; otherwise=Some else_; loc=(i $sloc) } }
  | "guard" "let" pat=pattern "=" expr=infix_expr
    { Parsing_compact.Stmt_guard_let { pat; expr; otherwise=None; loc=(i $sloc) } }
  | "guard" "let" pat=pattern "=" expr=infix_expr "else" "{" cases=single_pattern_cases "}"
    { Parsing_compact.Stmt_guard_let { pat; expr; otherwise=Some cases; loc=(i $sloc) } } 

%inline assignment_expr:
  | lv = left_value "=" e=expr {
    let loc_ = i $sloc in
    match lv with
    | `Var var ->
      Parsing_syntax.Pexpr_assign { var; expr = e; augmented_by = None; loc_ }
    | `Field_access (record, accessor) ->
      Parsing_syntax.Pexpr_mutate { record; accessor; field = e; augmented_by = None; loc_ }
    | `Array_access (array, index) ->
      Pexpr_array_set {array; index; value=e; loc_}
  }

%inline augmented_assignment_expr:
  | lv = left_value op=assignop e=expr {
    let loc_ = i $sloc in
    match lv with
    | `Var var ->
      Parsing_syntax.Pexpr_assign { var; expr = e; augmented_by = Some op; loc_ }
    | `Field_access (record, accessor) ->
      Parsing_syntax.Pexpr_mutate { record; accessor; field = e; augmented_by = Some op; loc_ }
    | `Array_access (array, index) ->
      Pexpr_array_augmented_set {op; array; index; value=e; loc_}
  }

%inline expr_statement:
  | "break" arg=ioption(expr) {
      Parsing_syntax.Pexpr_break { arg; loc_ = i $sloc }
    }
  | "continue" args=list_commas_no_trailing(expr) {
      Parsing_syntax.Pexpr_continue { args; loc_ = i $sloc }
    }
  | "return" expr = option(expr) { Parsing_syntax.Pexpr_return { return_value = expr; loc_ = i $sloc } }
  | "raise" expr = expr { Parsing_syntax.Pexpr_raise { err_value = expr; loc_ = i $sloc } }
  | "..." { Parsing_syntax.Pexpr_hole { loc_ = i $sloc; kind = Todo } }
  | augmented_assignment_expr
  | assignment_expr
  | expr { $1 }

while_expr:
  | "while" cond=infix_expr body=block_expr while_else=optional_else
    { Parsing_syntax.Pexpr_while { loc_=(i $sloc); loop_cond = cond; loop_body = body; while_else } }

single_pattern_cases:
| cases=list_semis(pat=pattern "=>" body=expr_statement { (pat, body) } ) { cases }

%inline catch_keyword:
  | "catch" "{"  | "{" { false, i $sloc }
  | "catch" "!" "{" { true, i $sloc }

%inline else_keyword:
  | "else" "{" { i $sloc }

try_expr:
  | "try" body=expr catch_keyword=catch_keyword catch=single_pattern_cases "}"
    { let catch_all, catch_loc_ = catch_keyword in
      Parsing_syntax.Pexpr_try { loc_=(i $sloc); body; catch; catch_all; try_else = None;
                                 else_loc_ = Rloc.no_location; try_loc_ = i $loc($1); catch_loc_ } }
  | "try" body=expr catch_keyword=catch_keyword catch=single_pattern_cases "}"
    else_loc_=else_keyword try_else=single_pattern_cases "}"
    { let catch_all, catch_loc_ = catch_keyword in
      Parsing_syntax.Pexpr_try { loc_=(i $sloc); body; catch; catch_all; try_else = Some try_else;
                                 else_loc_; try_loc_ = i $loc($1); catch_loc_ } }

if_expr:
  | "if"  b=infix_expr ifso=block_expr "else" ifnot=block_expr 
  | "if"  b=infix_expr ifso=block_expr "else" ifnot=if_expr { Pexpr_if {loc_=(i $sloc);  cond=b; ifso; ifnot =  Some ifnot} } 
  | "if"  b=infix_expr ifso=block_expr {Parsing_syntax.Pexpr_if {loc_=(i $sloc); cond = b; ifso; ifnot =None}}  

%inline match_header:
  | "match" e=infix_expr "{" { e }

match_expr:
  | e=match_header mat=non_empty_list_semis( pattern "=>" expr_statement {($1,$3)})  "}"  {
    Pexpr_match {loc_=(i $sloc);  expr = e ; cases =  mat; match_loc_ = i $loc(e)} }
  | e=match_header "}" { Parsing_syntax.Pexpr_match { loc_ = (i $sloc) ; expr = e ; cases =  []; match_loc_ = i $loc(e)}}

%inline loop_header:
  | "loop" args=non_empty_list_commas_no_trailing(expr) "{" { args }

loop_expr:
  | args=loop_header
      body=list_semis(
        pats=non_empty_list_commas(pattern) "=>" body=expr_statement {
          (pats, body)
        }
      )
    "}" { Parsing_syntax.Pexpr_loop { args; body; loc_ = i $sloc; loop_loc_ = i $loc(args) } }

for_binders:
  | binders=list_commas_no_trailing(b=binder "=" e=expr { (b, e) }) { binders }

optional_else:
  | "else" else_=block_expr { Some else_ }
  | { None }

for_expr:
  | "for" binders = for_binders SEMI
          condition = option(infix_expr) SEMI
          continue_block = list_commas_no_trailing(b=binder "=" e=expr { (b, e) })
          body = block_expr
          for_else = optional_else
    { Parsing_syntax.Pexpr_for {loc_ = i $sloc; binders; condition; continue_block; body; for_else } }
  | "for" binders = for_binders body = block_expr for_else=optional_else
    { Parsing_syntax.Pexpr_for {loc_ = i $sloc; binders; condition = None; continue_block = []; body; for_else } }

foreach_expr:
  | "for" binders=non_empty_list_commas(foreach_binder) "in" expr=expr
      body=block_expr
      else_block=optional_else
   {
     Parsing_syntax.Pexpr_foreach { binders; expr; body; else_block; loc_ = i $sloc }
   }

foreach_binder :
  | binder { Some $1 }
  | "_" { None }

expr: 
  | loop_expr
  | for_expr
  | foreach_expr
  | while_expr
  | try_expr 
  | if_expr 
  | match_expr 
  | pipe_expr {$1}

pipe_expr: 
  | lhs=pipe_expr "|>" rhs=infix_expr {
    Parsing_syntax.Pexpr_pipe { lhs; rhs; loc_ = i $sloc }
  }
  | infix_expr { $1 }

infix_expr:
  | lhs=infix_expr op=infixop rhs=infix_expr {
     Pexpr_infix{ op  ; lhs ; rhs ; loc_ = i($sloc)}
  }
  | postfix_expr { $1 } 

postfix_expr:
  | expr=prefix_expr "as" trait=type_name {
      Pexpr_as { expr; trait; loc_ = i $sloc }
    }
  | prefix_expr { $1 }

prefix_expr:
  | op=id(PLUS {"+"}) e=prefix_expr { make_uplus ~loc_:(i $sloc) op e }
  | op=id(MINUS{"-"}) e=prefix_expr { make_uminus ~loc_:(i $sloc) op e }
  | simple_expr { $1 }

%inline left_value:
 | var=var { `Var var }
 | record=simple_expr  acc=accessor {
     `Field_access (record, acc)
 }
 | obj=simple_expr  "[" ind=expr "]" {
    `Array_access (obj, ind)
 }

%inline constr:
  | name = UIDENT {
     { Parsing_syntax.constr_name = { name; loc_ = i $loc(name) }
     ; extra_info = No_extra_info
     ; loc_=(i $loc)
     }
    }
  | pkg=PACKAGE_NAME constr_name=DOT_UIDENT {
      { Parsing_syntax.constr_name = { name = constr_name; loc_ = i $loc(constr_name) }
      ; extra_info = Package pkg
      ; loc_= i $sloc
      }
    }
  /* TODO: two tokens or one token here? */
  | type_name=qual_ident_ty "::" constr_name=UIDENT {
      { Parsing_syntax.constr_name = { name = constr_name; loc_ = i $loc(constr_name) }
      ; extra_info = Type_name { name = type_name; loc_ = i $loc(type_name) }
      ; loc_= i $sloc
      }
    }

%inline apply_attr:
  | { Parsing_syntax.No_attr }
  | "!" { Parsing_syntax.Exclamation }
  | "?" { Parsing_syntax.Question }

simple_expr:
  | "{" x=record_defn "}" {
      let (fs, trailing) = x in
      make_Pexpr_record ~loc_:(i $sloc) ~trailing None (fs)
    }
  | type_name=type_name COLONCOLON "{" x=list_commas_with_trailing_info(record_defn_single) "}" {
      let (fs, trailing) = x in
      let trailing = if trailing then Parsing_syntax.Trailing_comma else Parsing_syntax.Trailing_none in
      make_Pexpr_record ~loc_:(i $sloc) ~trailing (Some type_name) fs
    }
  | type_name=ioption(terminated(type_name, COLONCOLON)) "{" ".." oe=expr "}" {
      Pexpr_record_update { type_name; record=oe; fields=[]; loc_=i $sloc }
    }
  | type_name=ioption(terminated(type_name, COLONCOLON)) "{" ".." oe=expr "," fs=list_commas(record_defn_single) "}" {
      Pexpr_record_update { type_name; record=oe; fields=fs; loc_=i $sloc }
    }
  | "{" x=semi_expr_semi_opt "}" {
      match x with
      | Parsing_syntax.Pexpr_ident { id = { var_name = Lident str; loc_ }; _ } as expr, trailing ->
         let label = { Parsing_syntax.label_name = str; loc_ } in
         let field = make_field_def ~loc_:(i $sloc) label expr true in
         let trailing = if trailing then Parsing_syntax.Trailing_semi else Parsing_syntax.Trailing_none in
         make_Pexpr_record ~loc_:(i $sloc) ~trailing None [field]
      | expr, _ -> Pexpr_group { expr; group = Group_brace; loc_ = i $sloc }
    }
  | "{" elems=list_commas(map_expr_elem) "}" {
      Parsing_syntax.Pexpr_map { elems; loc_ = i $sloc }
    }
  | "fn" has_error=optional_bang ps=parameters ty_opt=option("->" t=return_type {t}) f=block_expr
    { Pexpr_function {loc_=i $sloc; func = Lambda {parameters = ps; has_error; params_loc_ = (i $loc(ps));body = f ; return_type = ty_opt; kind_ = Lambda }} }
  | has_error=fn_header_no_binder cases=list_semis( pats=non_empty_list_commas(pattern) "=>" body=expr_statement { (pats, body) } ) "}"
    { Pexpr_function {loc_=i $sloc; func = Match { cases; has_error; loc_ = i $loc(cases); fn_loc_ = i $loc(has_error) }} }
  | e = atomic_expr {e}
  | "_" { Pexpr_hole { loc_ = (i $sloc) ; kind = Incomplete } }
  | var_name=qual_ident_simple_expr { make_Pexpr_ident ~loc_:(i $sloc) { var_name; loc_ = i $sloc } }
  | c=constr { Parsing_syntax.Pexpr_constr {loc_ = (i $sloc); constr = c} }
  | func=LIDENT "?" "(" args=list_commas(argument) ")" {
    let func : Parsing_syntax.expr =
      let loc_ = i $loc(func) in
      Pexpr_ident { id = { var_name = Lident func; loc_ }; loc_ }
    in
    Pexpr_apply { func; args; loc_ = i $sloc; attr = Question }
  }
  | func=simple_expr attr=apply_attr "(" args=list_commas(argument) ")" {
    Pexpr_apply { func; args; loc_ = i $sloc; attr }
  }
  | array=simple_expr  "[" index=expr "]" {
    Pexpr_array_get { array; index; loc_ = i $sloc }
  }
  | array=simple_expr  "[" start_index = ioption(expr) ":" end_index = ioption(expr) "]" {
    Pexpr_array_get_slice { array; start_index; end_index; loc_ = i $sloc; index_loc_ = (i ($startpos($2), $endpos($6))) }
  }
  | self=simple_expr meth=DOT_LIDENT attr=apply_attr "(" args=list_commas(argument) ")" {
    let method_name : Parsing_syntax.label =
      { label_name = meth; loc_ = i ($loc(meth)) }
    in
    Pexpr_dot_apply { self; method_name; args; return_self = false; attr; loc_ = (i $sloc) };
  }
  | self=simple_expr ".." meth=LIDENT attr=apply_attr "(" args=list_commas(argument) ")" {
    let method_name : Parsing_syntax.label =
      { label_name = meth; loc_ = i ($loc(meth)) }
    in
    Pexpr_dot_apply { self; method_name; args; return_self = true; attr; loc_ = (i $sloc) };
  }
  | record=simple_expr accessor=accessor %prec prec_field {
    Pexpr_field { record; accessor; loc_ = (i $sloc) }}
  | type_name=qual_ident_ty "::" meth=LIDENT {
    let type_name : Parsing_syntax.type_name =
      { name = type_name; loc_ = i ($loc(type_name)) }
    in
    let method_name: Parsing_syntax.label =
      { label_name = meth; loc_ = i ($loc(meth)) } in
    Pexpr_method { type_name; method_name; loc_ = i $sloc }
  }
  | "("  bs=list_commas(expr) ")" {
    match bs with
    | [] -> Pexpr_unit {loc_ = i $sloc; faked = false}
    | [expr] -> Pexpr_group { expr; group = Group_paren; loc_ = i $sloc }
    | _ -> make_Pexpr_tuple ~loc_:(i $sloc) bs
  }
  | "(" expr=expr ty=annot ")"
    { Parsing_syntax.Pexpr_constraint {loc_=(i $sloc); expr; ty} }
  | "[" es = list_commas(spreadable_elem) "]" { (make_Pexpr_array ~loc_:(i $sloc) es) }

%inline label:
  name = LIDENT { { Parsing_syntax.label_name = name; loc_=(i $loc) } }
%inline accessor:
  | name = DOT_LIDENT {
    if name = "_"
    then Parsing_syntax.Newtype
    else Parsing_syntax.Label { label_name = name; loc_ = (i $loc) }
  }
  | index = DOT_INT { Parsing_syntax.Index { tuple_index = index; loc_ = (i $loc) } }
%inline binder:
  name = LIDENT { { Parsing_syntax.binder_name = name; loc_=(i $loc) } }
%inline tvar_binder:
  | name = luident {
      { Parsing_syntax.tvar_name = name; tvar_constraints = []; loc_=(i $loc) }
  }
  | name = luident COLON constraints = separated_nonempty_list(PLUS, tvar_constraint) {
      { Parsing_syntax.tvar_name = name; tvar_constraints = constraints; loc_ = (i $loc(name)) }
  }
%inline type_decl_binder:
  | name = luident { { Parsing_syntax.tvar_name = Some name; loc_=(i $loc) } }
  | "_" { { Parsing_syntax.tvar_name = None; loc_ = (i $loc) } }
%inline tvar_constraint:
  | qual_ident_ty { { Parsing_syntax.tvc_trait = $1; loc_ = i $sloc } }
  /* special case for Error? */
  | id=UIDENT "?" { { Parsing_syntax.tvc_trait = Lident (id ^ "?"); loc_ = i $sloc } }
%inline var:
  name = qual_ident { { Parsing_syntax.var_name = name; loc_=(i $loc) } }
%inline type_name:
  name = qual_ident_ty { { Parsing_syntax.name; loc_ = i $loc } }

%inline multiline_string:
  | MULTILINE_STRING { Parsing_syntax.Multiline_string $1 }
  | MULTILINE_INTERP { Parsing_syntax.Multiline_interp (make_interps $1) }

%inline atomic_expr:
  | simple_constant { make_Pexpr_constant ~loc_:(i $sloc) $1 }
  | non_empty_list(multiline_string) { 
      Parsing_syntax.Pexpr_multiline_string { loc_=(i $sloc); elems=($1) } 
    }
  | INTERP { (make_Pexpr_interp ~loc_:(i $sloc) ($1)) }

%inline simple_constant:
  | TRUE { Parsing_syntax.Const_bool true }
  | FALSE { Parsing_syntax.Const_bool false }
  | BYTE { Parsing_syntax.Const_byte $1 }
  | BYTES { Parsing_syntax.Const_bytes $1 }
  | CHAR { Parsing_syntax.Const_char $1 }
  | INT { Parsing_util.make_int $1 }
  | FLOAT { Parsing_util.make_float $1 }
  | STRING { Parsing_syntax.Const_string $1 }

%inline map_syntax_key:
  | simple_constant { $1 }
  | MINUS INT { Parsing_util.make_int ("-" ^ $2) }
  | MINUS FLOAT { Parsing_syntax.Const_double ("-" ^ $2) }

%inline loced_string:
  | STRING { {Rloc.v = $1; loc_ = i $sloc}}

%inline assignop:
  | AUGMENTED_ASSIGNMENT { {Parsing_syntax.var_name = Lident $1; loc_ = i $sloc} }

%inline infixop:
  | INFIX4
  | INFIX3
  | INFIX2
  | INFIX1 { {Parsing_syntax.var_name = Lident $1; loc_ = i $sloc} }
  | PLUS { {Parsing_syntax.var_name = Lident "+"; loc_ = i $sloc} }
  | MINUS  { {Parsing_syntax.var_name = Lident "-"; loc_ = i $sloc} }
  | AMPER { {Parsing_syntax.var_name = Lident "&"; loc_ = i $sloc} }
  | CARET { {Parsing_syntax.var_name = Lident "^"; loc_ = i $sloc} }
  | BAR { {Parsing_syntax.var_name = Lident "|"; loc_ = i $sloc} }
  | AMPERAMPER { {Parsing_syntax.var_name = Lident "&&"; loc_ = i $sloc} }
  | BARBAR { {Parsing_syntax.var_name = Lident "||"; loc_ =  i $sloc} }
  | RANGE_EXCLUSIVE { {Parsing_syntax.var_name = Lident "..<"; loc_ =  i $sloc} }
  | RANGE_INCLUSIVE { {Parsing_syntax.var_name = Lident "..="; loc_ =  i $sloc} }

%inline optional_question:
  | "?" { Some(i $sloc) }
  | /* empty */ { None }

argument:
  (* label=expr *)
  | label=label is_question=optional_question "=" arg_value=expr {
    let arg_kind = 
      match is_question with
      | Some question_loc -> Parsing_syntax.Labelled_option { label; question_loc }
      | None -> Labelled label
    in
    { Parsing_syntax.arg_value; arg_kind }
  }
  (* Deprecated syntax. `~label` or `~label?`  *)
  | label=fn_label is_question=optional_question {
    let arg_value = Parsing_util.label_to_expr ~loc_:(Rloc.trim_first_char (i $loc(label))) label in
    let arg_kind = 
      match is_question with
      | Some question_loc -> Parsing_syntax.Labelled_option_pun { label; question_loc }
      | None -> Labelled_pun label
    in
    { Parsing_syntax.arg_value; arg_kind }
  }
  (* expr *)
  | arg_value=expr { { Parsing_syntax.arg_value; arg_kind = Positional } }
  (* label~ *)
  | label=POST_LABEL {
    let label = { Parsing_syntax.label_name = label; loc_ = i $loc(label) } in
    let arg_value = Parsing_util.label_to_expr ~loc_:(Rloc.trim_last_char (i $loc(label))) label in
    { Parsing_syntax.arg_value; arg_kind = Labelled_pun label }
  }
  (* label? *)
  | id=LIDENT "?" {
    let loc_ = i $loc(id) in
    let label = { Parsing_syntax.label_name = id; loc_ } in
    let arg_value = make_Pexpr_ident ~loc_ { var_name = Lident id; loc_ } in
    { Parsing_syntax.arg_value; arg_kind = Labelled_option_pun { label; question_loc = i $loc($2) }}
  }
  

%inline spreadable_elem:
  | expr=expr { Parsing_syntax.Elem_regular expr }
  | ".." expr=expr { Parsing_syntax.Elem_spread {expr; loc_=(i $sloc)} }

%inline map_expr_elem:
  | key=map_syntax_key ":" expr=expr {
    Parsing_syntax.Map_expr_elem
      { key
      ; expr
      ; key_loc_ = i $loc(key)
      ; loc_ = i $sloc
      }
  }

pattern:
  | p=pattern "as" b=binder { (make_Ppat_alias ~loc_:(i $sloc) (p, b)) }
  | or_pattern { $1 }

or_pattern:
  | pat1=range_pattern "|" pat2=or_pattern { Parsing_syntax.Ppat_or {loc_=(i $sloc);  pat1 ; pat2 } }
  | range_pattern { $1 }

range_pattern:
  | lhs=simple_pattern "..<" rhs=simple_pattern {
      Parsing_syntax.Ppat_range { lhs; rhs; inclusive = false; loc_ = i $sloc }
    }
  | lhs=simple_pattern "..=" rhs=simple_pattern {
      Parsing_syntax.Ppat_range { lhs; rhs; inclusive = true; loc_ = i $sloc }
    }
  | simple_pattern { $1 }

simple_pattern:
  | TRUE { (make_Ppat_constant  ~loc_:(i $sloc) (Const_bool true)) }
  | FALSE { (make_Ppat_constant ~loc_:(i $sloc) (Const_bool false)) }
  | CHAR { make_Ppat_constant ~loc_:(i $sloc) (Const_char $1) }
  | INT { (make_Ppat_constant ~loc_:(i $sloc) (Parsing_util.make_int $1)) }
  | FLOAT { (make_Ppat_constant ~loc_:(i $sloc) (Const_double $1)) }
  | "-" INT { (make_Ppat_constant ~loc_:(i $sloc) (Parsing_util.make_int ("-" ^ $2))) }
  | "-" FLOAT { (make_Ppat_constant ~loc_:(i $sloc) (Const_double ("-" ^ $2))) }
  | STRING { (make_Ppat_constant ~loc_:(i $sloc) (Const_string $1)) }
  | UNDERSCORE { Ppat_any {loc_ = i $sloc } }
  | b=binder  { Ppat_var b }
  | constr=constr ps=option("(" t=constr_pat_arguments ")" {t}){
    let (args, is_open) =
      match ps with
      | None -> (None, false)
      | Some (args, is_open) -> (Some args, is_open)
    in
    make_Ppat_constr ~loc_:(i $sloc) (constr, args, is_open)
  }
  | "(" pattern ")" { $2 }
  | "(" p = pattern "," ps=non_empty_list_commas(pattern) ")"  {make_Ppat_tuple ~loc_:(i $sloc) (p::ps)}
  | "(" pat=pattern  ty=annot ")" { Parsing_syntax.Ppat_constraint {loc_=(i $sloc);  pat; ty } }
  | "[" pats=array_sub_patterns "]" { Ppat_array { loc_=(i $sloc); pats} }
  | "{" "}" { Parsing_syntax.Ppat_record { fields = []; is_closed = true; loc_ = i $sloc } }
  | "{" p=non_empty_fields_pat "}" { let (fps, is_closed) = p in (Parsing_syntax.Ppat_record { fields=fps; is_closed; loc_=(i $sloc) }) }
  | "{" elems=non_empty_map_elems_pat "}" { Parsing_syntax.Ppat_map { elems; loc_ = i $sloc } }

%inline dotdot_with_binder:
  | ".." b=option("as" b=binder { b }) { b }

array_sub_patterns:
  | { Closed([]) }
  | b=dotdot_with_binder ioption(",") { Open([], [], b) }
  | ps=non_empty_list_commas(pattern) { Closed(ps) }
  | b=dotdot_with_binder "," ps=non_empty_list_commas(pattern) { Open([], ps, b) }// .. a,b,c
  | ps=non_empty_list_commas_with_tail(pattern) b=dotdot_with_binder ioption(",") { Open(ps, [], b) }//a,b,c .. | a,b,c ..,
  | ps1=non_empty_list_commas_with_tail(pattern) b=dotdot_with_binder "," ps2=non_empty_list_commas(pattern) { Open(ps1, ps2, b) }

return_type:
  | t=type_ %prec prec_type { (t, No_error_typ) }
  | t1=type_ "!" { (t1, Default_error_typ { loc_ = i $loc($2) }) }
  | t1=type_ "!" t2=type_ { (t1, Error_typ {ty = t2}) }

type_:
  | ty=type_ "?" { make_Ptype_option ~loc_:(i $sloc) ~constr_loc:(i $loc($2)) ty }
  | "(" t=type_ "," ts=non_empty_list_commas(type_) ")" { (make_Ptype_tuple ~loc_:(i $sloc) (t::ts)) }
  | "(" t=type_ "," ts=non_empty_list_commas(type_) ")" "->" rty=return_type {
    let (ty_res, ty_err) = rty in
    Ptype_arrow{loc_ = i $sloc ; ty_arg = t::ts ; ty_res; ty_err }
  }
  | "(" ")" "->" rty=return_type { let (ty_res, ty_err) = rty in Ptype_arrow{loc_ = i $sloc ; ty_arg = [] ; ty_res; ty_err}}
  | "(" t=type_ ")" rty=option("->" t2=return_type {t2})
      {
        match rty with
        | None -> t
        | Some rty ->
          let (ty_res, ty_err) = rty in
          Ptype_arrow{loc_=i($sloc); ty_arg=[t]; ty_res; ty_err}
      }
  // | "(" type_ ")" { $2 }
  | id=qual_ident_ty params=optional_type_arguments {
    Ptype_name {loc_ = (i $sloc) ;  constr_id = {lid=id;loc_=(i $loc(id))} ; tys =  params} }
  | "_" { Parsing_syntax.Ptype_any {loc_ = i $sloc } }


record_decl_field:
  | field_vis=visibility mutflag=option("mut") name=LIDENT ":" ty=type_ {
    {Parsing_syntax.field_name = {Parsing_syntax.label = name; loc_ = i $loc(name)}; field_ty = ty; field_mut = mutflag <> None; field_vis; field_loc_ = i $sloc;}
  }

constructor_param:
  | mut=option("mut") ty=type_ {
    { Parsing_syntax.cparam_typ = ty; cparam_mut = Option.is_some mut; cparam_label = None }
  }
  (* Deprecated syntax. mut ~label : Type *)
  | mut=option("mut") label_name=LABEL ":" typ=type_ {
    let label : Parsing_syntax.label = { label_name; loc_ = Rloc.trim_first_char (i $loc(label_name)) } in
    { Parsing_syntax.cparam_typ = typ; cparam_mut = Option.is_some mut; cparam_label = Some label }
  }
  (* mut label~ : Type *)
  | mut=option("mut") label_name=POST_LABEL ":" typ=type_ {
    let label : Parsing_syntax.label = { label_name; loc_ = Rloc.trim_last_char (i $loc(label_name)) } in
    { Parsing_syntax.cparam_typ = typ; cparam_mut = Option.is_some mut; cparam_label = Some label }
  }

enum_constructor:
  | id=UIDENT opt=option("("  ts=non_empty_list_commas(constructor_param)")" { ts }) {
    let constr_name : Parsing_syntax.constr_name = { name = id; loc_ = i $loc(id) } in
    {Parsing_syntax.constr_name; constr_args = opt; constr_loc_ = i $sloc;}
  }

record_defn:
  /* ending comma is required for single field {a,} for resolving the ambiguity between record punning {a} and block {a} */
  | l=label_pun "," x=list_commas_with_trailing_info(record_defn_single) {
      let (fs, trailing) = x in
      let trailing =
        if fs = [] || trailing then Parsing_syntax.Trailing_comma else Parsing_syntax.Trailing_none
      in
      (l::fs, trailing)
    }
  | l=labeled_expr comma=option(",") {
      ([l], if Option.is_some comma then Parsing_syntax.Trailing_comma else Parsing_syntax.Trailing_none)
    }
  /* rule out {r1: r1 r2} */
  | l=labeled_expr "," x=non_empty_list_commas_with_trailing_info(record_defn_single) {
      match x with
      | (fs, true) -> (l::fs, Parsing_syntax.Trailing_comma)
      | (fs, false) -> (l::fs, Parsing_syntax.Trailing_none)
    }

record_defn_single:
  | labeled_expr
  | label_pun {$1}

%inline labeled_expr:
  | l=label ":" e=expr {make_field_def ~loc_:(i $sloc) l e false}
%inline label_pun:
  | l=label {make_field_def ~loc_:(i $sloc) l (label_to_expr ~loc_:(i $sloc) l) true}

(* A field pattern list is a nonempty list of label-pattern pairs or punnings, optionally
   followed with an underscore, separated-or-terminated with commas. *)
non_empty_fields_pat:
  | fps=non_empty_list_commas(fields_pat_single) { fps, true }
  | fps=non_empty_list_commas_with_tail(fields_pat_single) ".." ioption(",") { fps, false }

fields_pat_single:
  | fpat_labeled_pattern
  | fpat_label_pun {$1}

%inline fpat_labeled_pattern:
  | l=label ":" p=pattern {make_field_pat ~loc_:(i $sloc) l p false}

%inline fpat_label_pun:
  | l=label {make_field_pat ~loc_:(i $sloc) l (label_to_pat ~loc_:(i $sloc) l) true}

non_empty_map_elems_pat:
  | non_empty_list_commas(map_elem_pat) { $1 }

%inline map_elem_pat:
  | key=map_syntax_key question=ioption("?") ":" pat=pattern {
    Parsing_syntax.Map_pat_elem
      { key
      ; pat
      ; match_absent = Option.is_some question
      ; key_loc_ = i $loc(key)
      ; loc_ = i $sloc
      }
  }

constr_pat_arguments:
  | constr_pat_argument ioption(",") { ([ $1 ], false) }
  | ".." ioption(",") { ([], true) }
  | arg=constr_pat_argument "," rest=constr_pat_arguments {
    let (args, is_open) = rest in
    (arg :: args, is_open)
  }

constr_pat_argument:
  (* label=pattern *)
  | label=label "=" pat=pattern {
    Parsing_syntax.Constr_pat_arg { pat; kind = Labelled label }
  }
  (* Deprecated syntax. ~label *)
  | label=fn_label {
    let pat = Parsing_util.label_to_pat ~loc_:(Rloc.trim_first_char (i $sloc)) label in
    Parsing_syntax.Constr_pat_arg { pat; kind = Labelled_pun label }
  }
  (* label~ *)
  | id=POST_LABEL {
    let loc_ = i $loc(id) in
    let label = { Parsing_syntax.label_name = id; loc_ } in
    let pat = Parsing_util.label_to_pat ~loc_:(Rloc.trim_last_char loc_) label in
    Parsing_syntax.Constr_pat_arg { pat; kind = Labelled_pun label }
  }
  (* pattern *)
  | pat=pattern { Parsing_syntax.Constr_pat_arg { pat; kind = Positional } }
