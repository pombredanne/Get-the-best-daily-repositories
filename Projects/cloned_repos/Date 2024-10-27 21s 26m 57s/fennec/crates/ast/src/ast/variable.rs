use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_interner::StringIdentifier;
use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::expression::Expression;

/// Represents a variable.
///
/// # Examples
///
/// ```php
/// $foo
/// ${foo}
/// $$foo
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
#[serde(tag = "type", content = "value")]
pub enum Variable {
    Direct(DirectVariable),
    Indirect(IndirectVariable),
    Nested(NestedVariable),
}

/// Represents a direct variable.
///
/// A direct variable is a variable that is directly referenced by its name.
///
/// # Examples
///
/// ```php
/// $foo
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct DirectVariable {
    pub span: Span,
    pub name: StringIdentifier,
}

/// Represents an indirect variable.
///
/// An indirect variable is a variable whose name is determined by evaluating an expression at runtime.
///
/// The expression is enclosed in curly braces `{}` following a dollar sign `$`.
///
/// # Examples
///
/// ```php
/// ${foo}
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct IndirectVariable {
    pub dollar_left_brace: Span,
    pub expression: Box<Expression>,
    pub right_brace: Span,
}

/// Represents a nested variable.
///
/// A nested variable is a variable that is nested inside another variable, commonly known as a variable variable.
///
/// # Examples
///
/// ```php
/// $$foo
/// $${foo}
/// $$$foo
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct NestedVariable {
    pub dollar: Span,
    pub variable: Box<Variable>,
}

impl HasSpan for Variable {
    fn span(&self) -> Span {
        match self {
            Variable::Direct(node) => node.span(),
            Variable::Indirect(node) => node.span(),
            Variable::Nested(node) => node.span(),
        }
    }
}

impl HasSpan for DirectVariable {
    fn span(&self) -> Span {
        self.span
    }
}

impl HasSpan for IndirectVariable {
    fn span(&self) -> Span {
        Span::between(self.dollar_left_brace, self.right_brace)
    }
}

impl HasSpan for NestedVariable {
    fn span(&self) -> Span {
        Span::between(self.dollar, self.variable.span())
    }
}
