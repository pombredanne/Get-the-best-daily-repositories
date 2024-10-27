use fennec_ast::ast::*;
use fennec_ast::sequence::TokenSeparatedSequence;
use fennec_token::T;

use crate::error::ParseError;
use crate::internal::expression::parse_expression;
use crate::internal::token_stream::TokenStream;
use crate::internal::utils;

pub fn parse_match<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<Match, ParseError> {
    Ok(Match {
        r#match: utils::expect_keyword(stream, T!["match"])?,
        left_parenthesis: utils::expect_span(stream, T!["("])?,
        expression: parse_expression(stream)?,
        right_parenthesis: utils::expect_span(stream, T![")"])?,
        left_brace: utils::expect_span(stream, T!["{"])?,
        arms: {
            let mut arms = vec![];
            let mut commas = vec![];
            loop {
                if matches!(utils::peek(stream)?.kind, T!["}"]) {
                    break;
                }

                arms.push(parse_match_arm(stream)?);

                match utils::peek(stream)?.kind {
                    T![","] => {
                        commas.push(utils::expect_any(stream)?);
                    }
                    _ => {
                        break;
                    }
                }
            }

            TokenSeparatedSequence::new(arms, commas)
        },
        right_brace: utils::expect_span(stream, T!["}"])?,
    })
}

pub fn parse_match_arm<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<MatchArm, ParseError> {
    Ok(match utils::peek(stream)?.kind {
        T!["default"] => MatchArm::Default(parse_match_default_arm(stream)?),
        _ => MatchArm::Expression(parse_match_expression_arm(stream)?),
    })
}

pub fn parse_match_expression_arm<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<MatchExpressionArm, ParseError> {
    Ok(MatchExpressionArm {
        conditions: {
            let mut conditions = vec![];
            let mut commas = vec![];
            loop {
                if matches!(utils::peek(stream)?.kind, T!["=>"]) {
                    break;
                }

                conditions.push(parse_expression(stream)?);

                match utils::peek(stream)?.kind {
                    T![","] => {
                        commas.push(utils::expect_any(stream)?);
                    }
                    _ => {
                        break;
                    }
                }
            }

            TokenSeparatedSequence::new(conditions, commas)
        },
        arrow: utils::expect_span(stream, T!["=>"])?,
        expression: parse_expression(stream)?,
    })
}

pub fn parse_match_default_arm<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<MatchDefaultArm, ParseError> {
    Ok(MatchDefaultArm {
        default: utils::expect_keyword(stream, T!["default"])?,
        arrow: utils::expect_span(stream, T!["=>"])?,
        expression: parse_expression(stream)?,
    })
}
