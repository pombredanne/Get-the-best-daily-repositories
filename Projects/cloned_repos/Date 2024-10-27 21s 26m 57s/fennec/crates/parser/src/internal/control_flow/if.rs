use fennec_ast::ast::*;
use fennec_ast::sequence::Sequence;
use fennec_token::T;

use crate::error::ParseError;
use crate::internal::expression::parse_expression;
use crate::internal::statement::parse_statement;
use crate::internal::terminator::parse_terminator;
use crate::internal::token_stream::TokenStream;
use crate::internal::utils;

pub fn parse_if<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<If, ParseError> {
    Ok(If {
        r#if: utils::expect_keyword(stream, T!["if"])?,
        left_parenthesis: utils::expect_span(stream, T!["("])?,
        condition: parse_expression(stream)?,
        right_parenthesis: utils::expect_span(stream, T![")"])?,
        body: parse_if_body(stream)?,
    })
}

pub fn parse_if_body<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<IfBody, ParseError> {
    Ok(match utils::peek(stream)?.kind {
        T![":"] => IfBody::ColonDelimited(parse_if_colon_delimited_body(stream)?),
        _ => IfBody::Statement(parse_if_statement_body(stream)?),
    })
}

pub fn parse_if_statement_body<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<IfStatementBody, ParseError> {
    Ok(IfStatementBody {
        statement: parse_statement(stream)?,
        else_if_clauses: {
            let mut else_if_clauses = vec![];
            while let Some(else_if_clause) = parse_optional_if_statement_body_else_if_clause(stream)? {
                else_if_clauses.push(else_if_clause);
            }

            Sequence::new(else_if_clauses)
        },
        else_clause: parse_optional_if_statement_body_else_clause(stream)?,
    })
}

pub fn parse_optional_if_statement_body_else_if_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<IfStatementBodyElseIfClause>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["elseif"]) => Some(parse_if_statement_body_else_if_clause(stream)?),
        _ => None,
    })
}

pub fn parse_if_statement_body_else_if_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<IfStatementBodyElseIfClause, ParseError> {
    Ok(IfStatementBodyElseIfClause {
        elseif: utils::expect_keyword(stream, T!["elseif"])?,
        left_parenthesis: utils::expect_span(stream, T!["("])?,
        condition: parse_expression(stream)?,
        right_parenthesis: utils::expect_span(stream, T![")"])?,
        statement: parse_statement(stream)?,
    })
}

pub fn parse_optional_if_statement_body_else_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<IfStatementBodyElseClause>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["else"]) => Some(parse_if_statement_body_else_clause(stream)?),
        _ => None,
    })
}

pub fn parse_if_statement_body_else_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<IfStatementBodyElseClause, ParseError> {
    Ok(IfStatementBodyElseClause {
        r#else: utils::expect_keyword(stream, T!["else"])?,
        statement: parse_statement(stream)?,
    })
}

pub fn parse_if_colon_delimited_body<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<IfColonDelimitedBody, ParseError> {
    Ok(IfColonDelimitedBody {
        colon: utils::expect_span(stream, T![":"])?,
        statements: {
            let mut statements = Vec::new();
            loop {
                if matches!(utils::peek(stream)?.kind, T!["elseif" | "else" | "endif"]) {
                    break;
                }

                statements.push(parse_statement(stream)?);
            }

            Sequence::new(statements)
        },
        else_if_clauses: {
            let mut else_if_clauses = Vec::new();
            while let Some(else_if_clause) = parse_optional_if_colon_delimited_body_else_if_clause(stream)? {
                else_if_clauses.push(else_if_clause);
            }

            Sequence::new(else_if_clauses)
        },
        else_clause: parse_optional_if_colon_delimited_body_else_clause(stream)?,
        endif: utils::expect_keyword(stream, T!["endif"])?,
        terminator: parse_terminator(stream)?,
    })
}

pub fn parse_optional_if_colon_delimited_body_else_if_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<IfColonDelimitedBodyElseIfClause>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["elseif"]) => Some(parse_if_colon_delimited_body_else_if_clause(stream)?),
        _ => None,
    })
}

pub fn parse_if_colon_delimited_body_else_if_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<IfColonDelimitedBodyElseIfClause, ParseError> {
    Ok(IfColonDelimitedBodyElseIfClause {
        r#elseif: utils::expect_keyword(stream, T!["elseif"])?,
        left_parenthesis: utils::expect_span(stream, T!["("])?,
        condition: parse_expression(stream)?,
        right_parenthesis: utils::expect_span(stream, T![")"])?,
        colon: utils::expect_span(stream, T![":"])?,
        statements: {
            let mut statements = Vec::new();
            loop {
                if matches!(utils::peek(stream)?.kind, T!["elseif" | "else" | "endif"]) {
                    break;
                }

                statements.push(parse_statement(stream)?);
            }

            Sequence::new(statements)
        },
    })
}

pub fn parse_optional_if_colon_delimited_body_else_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<IfColonDelimitedBodyElseClause>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["else"]) => Some(parse_if_colon_delimited_body_else_clause(stream)?),
        _ => None,
    })
}

pub fn parse_if_colon_delimited_body_else_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<IfColonDelimitedBodyElseClause, ParseError> {
    Ok(IfColonDelimitedBodyElseClause {
        r#else: utils::expect_keyword(stream, T!["else"])?,
        colon: utils::expect_span(stream, T![":"])?,
        statements: {
            let mut statements = Vec::new();
            loop {
                if matches!(utils::peek(stream)?.kind, T!["endif"]) {
                    break;
                }

                statements.push(parse_statement(stream)?);
            }
            Sequence::new(statements)
        },
    })
}
