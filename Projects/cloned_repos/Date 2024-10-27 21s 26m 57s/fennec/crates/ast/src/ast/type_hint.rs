use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::identifier::Identifier;
use crate::ast::identifier::LocalIdentifier;
use crate::ast::keyword::Keyword;

/// Represents a type statement.
///
/// A type statement specifies the type of a parameter, property, constant, or return value.
///
/// # Examples
///
/// ```php
/// int
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
#[serde(tag = "type", content = "value")]
pub enum Hint {
    Identifier(Identifier),
    Parenthesized(ParenthesizedHint),
    Nullable(NullableHint),
    Union(UnionHint),
    Intersection(IntersectionHint),
    Null(Keyword),
    True(Keyword),
    False(Keyword),
    Array(Keyword),
    Callable(Keyword),
    Static(Keyword),
    Self_(Keyword),
    Parent(Keyword),
    Void(LocalIdentifier),
    Never(LocalIdentifier),
    Float(LocalIdentifier),
    Bool(LocalIdentifier),
    Integer(LocalIdentifier),
    String(LocalIdentifier),
    Object(LocalIdentifier),
    Mixed(LocalIdentifier),
    Iterable(LocalIdentifier),
}

/// Represents a parenthesized type hint.
///
/// # Examples
///
/// ```php
/// <?php
///
/// function(): string|(Foo&Bar) {
///    return 'hello';
/// }
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct ParenthesizedHint {
    pub left_parenthesis: Span,
    pub hint: Box<Hint>,
    pub right_parenthesis: Span,
}

/// Represents a union type statement
///
/// A union type is a type that is a union of multiple type hints separated by a pipe (`|`) character.
///
/// # Examples
///
/// ```php
/// int|string
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct UnionHint {
    pub left: Box<Hint>,
    pub pipe: Span,
    pub right: Box<Hint>,
}

/// Represents an intersection type.
///
/// An intersection type is a type that is an intersection of multiple type hints separated by an ampersand (`&`) character.
///
/// # Examples
///
/// ```php
/// ArrayAccess&Countable
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct IntersectionHint {
    pub left: Box<Hint>,
    pub ampersand: Span,
    pub right: Box<Hint>,
}

/// Represents a nullable type.
///
/// A nullable type is a type that is preceded by a question mark (`?`) character.
///
/// # Examples
///
/// ```php
/// ?string
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct NullableHint {
    pub question_mark: Span,
    pub hint: Box<Hint>,
}

impl Hint {
    /// Returns `true` if the type hint is a standalone type hint.
    ///
    /// Standalone type hints are type hints that cannot be wrapped inside another type hint.
    pub fn is_standalone(&self) -> bool {
        matches!(self, Self::Mixed(_) | Self::Never(_) | Self::Void(_) | Self::Nullable(_))
    }

    pub fn is_complex(&self) -> bool {
        matches!(self, Self::Union(_) | Self::Intersection(_) | Self::Parenthesized(_) | Self::Nullable(_))
    }

    /// Returns `true` if the type hint is a nullable type hint.
    ///
    /// A nullable type hint is a type hint that is preceded by a question mark (`?`) character.
    pub fn is_nullable(&self) -> bool {
        matches!(self, Self::Nullable(_))
    }

    /// Returns `true` if the type is a bottom type.
    ///
    /// A bottom type is a type that has no instances.
    pub fn is_bottom(&self) -> bool {
        matches!(self, Self::Never(_) | Self::Void(_))
    }

    /// Returns `true` if the type can be intersected with another type.
    pub fn is_intersectable(&self) -> bool {
        matches!(self, Self::Identifier(_) | Self::Parenthesized(_) | Self::Intersection(_))
    }

    /// Returns `true` if the type can be unioned with another type.
    pub fn is_unionable(&self) -> bool {
        if let Hint::Intersection(_) = self {
            return false;
        }

        !self.is_standalone()
    }

    /// Returns `true` if the type can be wrapped in parentheses.
    pub fn is_parenthesizable(&self) -> bool {
        matches!(self, Self::Union(_) | Self::Intersection(_))
    }

    /// Returns `true` if the type is a scalar type.
    ///
    /// A scalar type is a type that represents a single value.
    pub fn is_scalar(&self) -> bool {
        if let Hint::Union(union) = self {
            return union.left.is_scalar() && union.right.is_scalar();
        }

        matches!(self, Self::Bool(_) | Self::Float(_) | Self::Integer(_) | Self::String(_))
    }
}

impl HasSpan for Hint {
    fn span(&self) -> Span {
        match &self {
            Hint::Identifier(identifier) => identifier.span(),
            Hint::Parenthesized(parenthesized) => parenthesized.span(),
            Hint::Nullable(nullable) => nullable.span(),
            Hint::Union(union) => union.span(),
            Hint::Intersection(intersection) => intersection.span(),
            Hint::Null(keyword)
            | Hint::True(keyword)
            | Hint::Static(keyword)
            | Hint::Callable(keyword)
            | Hint::Self_(keyword)
            | Hint::Parent(keyword)
            | Hint::Array(keyword)
            | Hint::False(keyword) => keyword.span(),
            Hint::Void(identifier)
            | Hint::Never(identifier)
            | Hint::Float(identifier)
            | Hint::Bool(identifier)
            | Hint::Integer(identifier)
            | Hint::String(identifier)
            | Hint::Object(identifier)
            | Hint::Mixed(identifier)
            | Hint::Iterable(identifier) => identifier.span(),
        }
    }
}

impl HasSpan for ParenthesizedHint {
    fn span(&self) -> Span {
        self.left_parenthesis.join(self.right_parenthesis)
    }
}

impl HasSpan for UnionHint {
    fn span(&self) -> Span {
        self.left.span().join(self.right.span())
    }
}

impl HasSpan for IntersectionHint {
    fn span(&self) -> Span {
        self.left.span().join(self.right.span())
    }
}

impl HasSpan for NullableHint {
    fn span(&self) -> Span {
        Span::between(self.question_mark, self.hint.span())
    }
}
