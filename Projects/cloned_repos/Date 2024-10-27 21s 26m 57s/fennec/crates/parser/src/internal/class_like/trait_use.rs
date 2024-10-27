use fennec_ast::ast::*;
use fennec_ast::sequence::Sequence;
use fennec_ast::sequence::TokenSeparatedSequence;
use fennec_token::T;

use crate::error::ParseError;
use crate::internal::identifier::parse_identifier;
use crate::internal::identifier::parse_local_identifier;
use crate::internal::modifier::parse_optional_visibility_modifier;
use crate::internal::terminator::parse_terminator;
use crate::internal::token_stream::TokenStream;
use crate::internal::utils;

pub fn parse_trait_use<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<TraitUse, ParseError> {
    Ok(TraitUse {
        r#use: utils::expect_keyword(stream, T!["use"])?,
        trait_names: {
            let mut traits = Vec::new();
            let mut commas = Vec::new();
            loop {
                let next = utils::peek(stream)?;
                if matches!(next.kind, T!["{" | ";" | "?>"]) {
                    break;
                }

                traits.push(parse_identifier(stream)?);

                match utils::peek(stream)?.kind {
                    T![","] => {
                        commas.push(utils::expect_any(stream)?);
                    }
                    _ => {
                        break;
                    }
                }
            }

            TokenSeparatedSequence::new(traits, commas)
        },
        specification: parse_trait_use_specification(stream)?,
    })
}

pub fn parse_trait_use_specification<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<TraitUseSpecification, ParseError> {
    let next = utils::peek(stream)?;
    Ok(match next.kind {
        T![";" | "?>"] => TraitUseSpecification::Abstract(TraitUseAbstractSpecification(parse_terminator(stream)?)),
        _ => TraitUseSpecification::Concrete(TraitUseConcreteSpecification {
            left_brace: utils::expect_span(stream, T!["{"])?,
            adaptations: {
                let mut adaptations = Vec::new();
                loop {
                    let next = utils::peek(stream)?;
                    if next.kind == T!["}"] {
                        break;
                    }

                    adaptations.push(parse_trait_use_adaptation(stream)?);
                }
                Sequence::new(adaptations)
            },
            right_brace: utils::expect_span(stream, T!["}"])?,
        }),
    })
}

pub fn parse_trait_use_adaptation<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<TraitUseAdaptation, ParseError> {
    Ok(match parse_trait_use_method_reference(stream)? {
        TraitUseMethodReference::Absolute(reference) => {
            let next = utils::peek(stream)?;
            match next.kind {
                T!["as"] => TraitUseAdaptation::Alias(TraitUseAliasAdaptation {
                    method_reference: TraitUseMethodReference::Absolute(reference),
                    r#as: utils::expect_keyword(stream, T!["as"])?,
                    visibility: parse_optional_visibility_modifier(stream)?,
                    alias: match utils::maybe_peek(stream)?.map(|t| t.kind) {
                        Some(T![";" | "?>"]) => None,
                        _ => Some(parse_local_identifier(stream)?),
                    },
                    terminator: parse_terminator(stream)?,
                }),
                T!["insteadof"] => TraitUseAdaptation::Precedence(TraitUsePrecedenceAdaptation {
                    method_reference: reference,
                    insteadof: utils::expect_any_keyword(stream)?,
                    trait_names: {
                        let mut items = Vec::new();
                        let mut commas = Vec::new();
                        loop {
                            if matches!(utils::peek(stream)?.kind, T![";" | "?>"]) {
                                break;
                            }

                            items.push(parse_identifier(stream)?);

                            match utils::peek(stream)?.kind {
                                T![","] => {
                                    commas.push(utils::expect_any(stream)?);
                                }
                                _ => {
                                    break;
                                }
                            }
                        }

                        TokenSeparatedSequence::new(items, commas)
                    },
                    terminator: parse_terminator(stream)?,
                }),
                _ => return Err(utils::unexpected(stream, Some(next), T!["as", "insteadof"])),
            }
        }
        method_reference @ TraitUseMethodReference::Identifier(_) => {
            TraitUseAdaptation::Alias(TraitUseAliasAdaptation {
                method_reference,
                r#as: utils::expect_keyword(stream, T!["as"])?,
                visibility: parse_optional_visibility_modifier(stream)?,
                alias: match utils::maybe_peek(stream)?.map(|t| t.kind) {
                    Some(T![";" | "?>"]) => None,
                    _ => Some(parse_local_identifier(stream)?),
                },
                terminator: parse_terminator(stream)?,
            })
        }
    })
}

pub fn parse_trait_use_method_reference<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<TraitUseMethodReference, ParseError> {
    Ok(match utils::maybe_peek_nth(stream, 1)?.map(|t| t.kind) {
        Some(T!["::"]) => TraitUseMethodReference::Absolute(parse_trait_use_absolute_method_reference(stream)?),
        _ => TraitUseMethodReference::Identifier(parse_local_identifier(stream)?),
    })
}

pub fn parse_trait_use_absolute_method_reference<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<TraitUseAbsoluteMethodReference, ParseError> {
    Ok(TraitUseAbsoluteMethodReference {
        trait_name: parse_identifier(stream)?,
        double_colon: utils::expect_span(stream, T!["::"])?,
        method_name: parse_local_identifier(stream)?,
    })
}
