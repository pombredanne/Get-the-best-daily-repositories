use fennec_ast::ast::*;
use fennec_ast::sequence::TokenSeparatedSequence;
use fennec_token::T;

use crate::error::ParseError;
use crate::internal::identifier::parse_identifier;
use crate::internal::identifier::parse_local_identifier;
use crate::internal::terminator::parse_terminator;
use crate::internal::token_stream::TokenStream;
use crate::internal::utils;

pub fn parse_use<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<Use, ParseError> {
    Ok(Use {
        r#use: utils::expect_keyword(stream, T!["use"])?,
        items: parse_use_items(stream)?,
        terminator: parse_terminator(stream)?,
    })
}

pub fn parse_use_items<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<UseItems, ParseError> {
    let next = utils::peek(stream)?.kind;

    Ok(match next {
        T!["const" | "function"] => match utils::maybe_peek_nth(stream, 2)?.map(|token| token.kind) {
            Some(T!["\\"]) => UseItems::TypedList(parse_typed_use_item_list(stream)?),
            _ => UseItems::TypedSequence(parse_typed_use_item_sequence(stream)?),
        },
        _ => match utils::maybe_peek_nth(stream, 1)?.map(|token| token.kind) {
            Some(T!["\\"]) => UseItems::MixedList(parse_mixed_use_item_list(stream)?),
            _ => UseItems::Sequence(parse_use_item_sequence(stream)?),
        },
    })
}

pub fn parse_use_item_sequence<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<UseItemSequence, ParseError> {
    let start = utils::peek(stream)?.span.start;

    let mut items = Vec::new();
    let mut commas = Vec::new();
    loop {
        items.push(parse_use_item(stream)?);

        match utils::maybe_expect(stream, T![","])? {
            Some(comma) => {
                commas.push(comma);
            }
            None => break,
        }
    }

    Ok(UseItemSequence { start, items: TokenSeparatedSequence::new(items, commas) })
}

pub fn parse_typed_use_item_sequence<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<TypedUseItemSequence, ParseError> {
    let r#type = parse_use_type(stream)?;
    let mut items = Vec::new();
    let mut commas = Vec::new();
    loop {
        items.push(parse_use_item(stream)?);

        match utils::maybe_expect(stream, T![","])? {
            Some(comma) => {
                commas.push(comma);
            }
            None => break,
        }
    }

    Ok(TypedUseItemSequence { r#type, items: TokenSeparatedSequence::new(items, commas) })
}

pub fn parse_typed_use_item_list<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<TypedUseItemList, ParseError> {
    let r#type = parse_use_type(stream)?;
    let namespace = parse_identifier(stream)?;
    let namespace_separator = utils::expect_span(stream, T!["\\"])?;
    let left_brace = utils::expect_span(stream, T!["{"])?;
    let mut items = Vec::new();
    let mut commas = Vec::new();
    loop {
        let next = utils::peek(stream)?;
        if matches!(next.kind, T!["}"]) {
            break;
        }

        items.push(parse_use_item(stream)?);

        match utils::maybe_expect(stream, T![","])? {
            Some(comma) => {
                commas.push(comma);
            }
            None => break,
        }
    }
    let right_brace = utils::expect_span(stream, T!["}"])?;

    Ok(TypedUseItemList {
        r#type,
        namespace,
        namespace_separator,
        left_brace,
        items: TokenSeparatedSequence::new(items, commas),
        right_brace,
    })
}

pub fn parse_mixed_use_item_list<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<MixedUseItemList, ParseError> {
    let namespace = parse_identifier(stream)?;
    let namespace_separator = utils::expect_span(stream, T!["\\"])?;
    let left_brace = utils::expect_span(stream, T!["{"])?;
    let mut items = Vec::new();
    let mut commas = Vec::new();
    loop {
        let next = utils::peek(stream)?;
        if matches!(next.kind, T!["}"]) {
            break;
        }

        items.push(parse_maybe_typed_use_item(stream)?);

        match utils::maybe_expect(stream, T![","])? {
            Some(comma) => {
                commas.push(comma);
            }
            None => break,
        }
    }
    let right_brace = utils::expect_span(stream, T!["}"])?;

    Ok(MixedUseItemList {
        namespace,
        namespace_separator,
        left_brace,
        items: TokenSeparatedSequence::new(items, commas),
        right_brace,
    })
}

pub fn parse_maybe_typed_use_item<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<MaybeTypedUseItem, ParseError> {
    Ok(MaybeTypedUseItem { r#type: parse_optional_use_type(stream)?, item: parse_use_item(stream)? })
}

pub fn parse_optional_use_type<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<Option<UseType>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["function"]) => Some(UseType::Function(utils::expect_any_keyword(stream)?)),
        Some(T!["const"]) => Some(UseType::Const(utils::expect_any_keyword(stream)?)),
        _ => None,
    })
}

pub fn parse_use_type<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<UseType, ParseError> {
    let next = utils::peek(stream)?;

    Ok(match next.kind {
        T!["function"] => UseType::Function(utils::expect_any_keyword(stream)?),
        T!["const"] => UseType::Const(utils::expect_any_keyword(stream)?),
        _ => return Err(utils::unexpected(stream, Some(next), T!["function", "const"])),
    })
}

pub fn parse_use_item<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<UseItem, ParseError> {
    Ok(UseItem { name: parse_identifier(stream)?, alias: parse_optional_use_item_alias(stream)? })
}

pub fn parse_optional_use_item_alias<'a, 'i>(
    stream: &mut TokenStream<'a, 'i>,
) -> Result<Option<UseItemAlias>, ParseError> {
    Ok(match utils::maybe_peek(stream)?.map(|t| t.kind) {
        Some(T!["as"]) => Some(parse_use_item_alias(stream)?),
        _ => None,
    })
}

pub fn parse_use_item_alias<'a, 'i>(stream: &mut TokenStream<'a, 'i>) -> Result<UseItemAlias, ParseError> {
    let r#as = utils::expect_keyword(stream, T!["as"])?;
    let identifier = parse_local_identifier(stream)?;

    Ok(UseItemAlias { r#as, identifier })
}
