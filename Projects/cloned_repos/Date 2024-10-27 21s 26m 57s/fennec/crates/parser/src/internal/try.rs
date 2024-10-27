use fennec_ast::ast::*;
use fennec_ast::sequence::Sequence;
use fennec_token::T;

use crate::error::ParseError;
use crate::internal::block::parse_block;
use crate::internal::token_stream::TokenStream;
use crate::internal::type_hint::parse_type_hint;
use crate::internal::utils;
use crate::internal::variable::parse_direct_variable;

pub fn parse_try<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<Try, ParseError> {
    Ok(Try {
        r#try: utils::expect_keyword(stream, T!["try"])?,
        block: parse_block(stream)?,
        catch_clauses: {
            let mut catch_clauses = vec![];
            while let Some(clause) = parse_optional_try_catch_clause(stream)? {
                catch_clauses.push(clause);
            }

            Sequence::new(catch_clauses)
        },
        finally_clause: parse_optional_try_finally_clause(stream)?,
    })
}

pub fn parse_optional_try_catch_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<TryCatchClause>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["catch"]) => {
            let catch = utils::expect_any_keyword(stream)?;
            let left_parenthesis = utils::expect_span(stream, T!["("])?;
            let hint = parse_type_hint(stream)?;
            let variable = match utils::peek(stream)?.kind {
                T!["$variable"] => Some(parse_direct_variable(stream)?),
                _ => None,
            };
            let right_parenthesis = utils::expect_span(stream, T![")"])?;
            let block = parse_block(stream)?;

            Some(TryCatchClause { catch, left_parenthesis, hint, variable, right_parenthesis, block })
        }
        _ => None,
    })
}

pub fn parse_optional_try_finally_clause<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<TryFinallyClause>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["finally"]) => {
            Some(TryFinallyClause { finally: utils::expect_any_keyword(stream)?, block: parse_block(stream)? })
        }
        _ => None,
    })
}
