use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::block::Block;
use crate::ast::identifier::Identifier;
use crate::ast::keyword::Keyword;
use crate::ast::statement::Statement;
use crate::ast::terminator::Terminator;

use crate::sequence::Sequence;

/// Represents a PHP `namespace` declaration.
///
/// # Examples
///
/// ```php
/// <?php
///
/// namespace Foo\Bar {
///    // ...
/// }
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct Namespace {
    pub namespace: Keyword,
    pub name: Option<Identifier>,
    pub body: NamespaceBody,
}

/// Represents the body of a PHP `namespace` declaration.
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
pub enum NamespaceBody {
    Implicit(NamespaceImplicitBody),
    BraceDelimited(Block),
}

/// Represents an implicit body of a PHP `namespace` declaration.
///
/// # Examples
///
/// ```php
/// <?php
///
/// namespace Foo\Bar;
///
/// // ...
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct NamespaceImplicitBody {
    pub terminator: Terminator,
    pub statements: Sequence<Statement>,
}

impl Namespace {
    pub fn statements(&self) -> &Sequence<Statement> {
        match &self.body {
            NamespaceBody::Implicit(body) => &body.statements,
            NamespaceBody::BraceDelimited(body) => &body.statements,
        }
    }
}

impl HasSpan for Namespace {
    fn span(&self) -> Span {
        self.namespace.span().join(self.body.span())
    }
}

impl HasSpan for NamespaceBody {
    fn span(&self) -> Span {
        match self {
            NamespaceBody::Implicit(body) => body.span(),
            NamespaceBody::BraceDelimited(body) => body.span(),
        }
    }
}

impl HasSpan for NamespaceImplicitBody {
    fn span(&self) -> Span {
        self.terminator.span().join(self.statements.span(self.terminator.span().end))
    }
}
