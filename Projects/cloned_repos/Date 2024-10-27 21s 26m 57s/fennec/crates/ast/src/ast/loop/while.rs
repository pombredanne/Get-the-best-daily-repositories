use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::expression::Expression;
use crate::ast::keyword::Keyword;
use crate::ast::statement::Statement;
use crate::ast::terminator::Terminator;
use crate::sequence::Sequence;

/// Represents a while statement in PHP.
///
/// Example:
///
/// ```php
/// <?php
///
/// $i = 0;
/// while ($i < 10) {
///   echo $i;
///   $i++;
/// }
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct While {
    pub r#while: Keyword,
    pub left_parenthesis: Span,
    pub condition: Expression,
    pub right_parenthesis: Span,
    pub body: WhileBody,
}

/// Represents the body of a while statement.
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
pub enum WhileBody {
    Statement(Statement),
    ColonDelimited(WhileColonDelimitedBody),
}

/// Represents a colon-delimited body of a while statement.
///
/// Example:
///
/// ```php
/// <?php
///
/// $i = 0;
/// while ($i < 10):
///   echo $i;
///   $i++;
/// endwhile;
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct WhileColonDelimitedBody {
    pub colon: Span,
    pub statements: Sequence<Statement>,
    pub end_while: Keyword,
    pub terminator: Terminator,
}

impl HasSpan for While {
    fn span(&self) -> Span {
        self.r#while.span().join(self.body.span())
    }
}

impl HasSpan for WhileBody {
    fn span(&self) -> Span {
        match self {
            WhileBody::Statement(statement) => statement.span(),
            WhileBody::ColonDelimited(body) => body.span(),
        }
    }
}

impl HasSpan for WhileColonDelimitedBody {
    fn span(&self) -> Span {
        self.colon.join(self.terminator.span())
    }
}
