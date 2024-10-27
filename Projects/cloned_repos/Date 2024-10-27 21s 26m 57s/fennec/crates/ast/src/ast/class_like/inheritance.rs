use serde::Deserialize;
use serde::Serialize;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::identifier::Identifier;
use crate::ast::keyword::Keyword;
use crate::sequence::TokenSeparatedSequence;

/// Represents `implements` keyword with one or more types.
///
/// # Example
///
/// ```php
/// <?php
///
/// final class Foo implements Bar, Baz {}
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct Implements {
    pub implements: Keyword,
    pub types: TokenSeparatedSequence<Identifier>,
}

/// Represents `extends` keyword with one or more types.
///
/// # Example
///
/// ```php
/// <?php
///
/// interface Foo extends Bar, Baz {}
/// ```
///
/// ```php
/// <?php
///
/// class Foo extends Bar {}
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct Extends {
    pub extends: Keyword,
    pub types: TokenSeparatedSequence<Identifier>,
}

impl HasSpan for Implements {
    fn span(&self) -> Span {
        let span = self.implements.span();

        Span::between(span, self.types.span(span.end))
    }
}

impl HasSpan for Extends {
    fn span(&self) -> Span {
        let span = self.extends.span();

        Span::between(span, self.types.span(span.end))
    }
}
