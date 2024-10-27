use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::argument::ArgumentList;
use crate::ast::expression::Expression;
use crate::ast::keyword::Keyword;
use crate::sequence::TokenSeparatedSequence;

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
#[serde(tag = "type", content = "value")]
pub enum Construct {
    Isset(IssetConstruct),
    Empty(EmptyConstruct),
    Eval(EvalConstruct),
    Include(IncludeConstruct),
    IncludeOnce(IncludeOnceConstruct),
    Require(RequireConstruct),
    RequireOnce(RequireOnceConstruct),
    Print(PrintConstruct),
    Exit(ExitConstruct),
    Die(DieConstruct),
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct IssetConstruct {
    pub isset: Keyword,
    pub left_parenthesis: Span,
    pub values: TokenSeparatedSequence<Expression>,
    pub right_parenthesis: Span,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct EmptyConstruct {
    pub empty: Keyword,
    pub left_parenthesis: Span,
    pub value: Expression,
    pub right_parenthesis: Span,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct EvalConstruct {
    pub eval: Keyword,
    pub left_parenthesis: Span,
    pub value: Expression,
    pub right_parenthesis: Span,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct IncludeConstruct {
    pub include: Keyword,
    pub value: Expression,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct IncludeOnceConstruct {
    pub include_once: Keyword,
    pub value: Expression,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct RequireConstruct {
    pub require: Keyword,
    pub value: Expression,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct RequireOnceConstruct {
    pub require_once: Keyword,
    pub value: Expression,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct PrintConstruct {
    pub print: Keyword,
    pub value: Expression,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct ExitConstruct {
    pub exit: Keyword,
    pub arguments: Option<ArgumentList>,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct DieConstruct {
    pub die: Keyword,
    pub arguments: Option<ArgumentList>,
}

impl HasSpan for Construct {
    fn span(&self) -> Span {
        match self {
            Construct::Isset(c) => c.span(),
            Construct::Empty(c) => c.span(),
            Construct::Eval(c) => c.span(),
            Construct::Include(c) => c.span(),
            Construct::IncludeOnce(c) => c.span(),
            Construct::Require(c) => c.span(),
            Construct::RequireOnce(c) => c.span(),
            Construct::Print(c) => c.span(),
            Construct::Exit(c) => c.span(),
            Construct::Die(c) => c.span(),
        }
    }
}

impl HasSpan for IssetConstruct {
    fn span(&self) -> Span {
        self.isset.span().join(self.right_parenthesis.span())
    }
}

impl HasSpan for EmptyConstruct {
    fn span(&self) -> Span {
        self.empty.span().join(self.right_parenthesis)
    }
}

impl HasSpan for EvalConstruct {
    fn span(&self) -> Span {
        self.eval.span().join(self.right_parenthesis)
    }
}

impl HasSpan for IncludeConstruct {
    fn span(&self) -> Span {
        self.include.span().join(self.value.span())
    }
}

impl HasSpan for IncludeOnceConstruct {
    fn span(&self) -> Span {
        self.include_once.span().join(self.value.span())
    }
}

impl HasSpan for RequireConstruct {
    fn span(&self) -> Span {
        self.require.span().join(self.value.span())
    }
}

impl HasSpan for RequireOnceConstruct {
    fn span(&self) -> Span {
        self.require_once.span().join(self.value.span())
    }
}

impl HasSpan for PrintConstruct {
    fn span(&self) -> Span {
        self.print.span().join(self.value.span())
    }
}

impl HasSpan for ExitConstruct {
    fn span(&self) -> Span {
        if let Some(arguments) = &self.arguments {
            self.exit.span().join(arguments.span())
        } else {
            self.exit.span()
        }
    }
}

impl HasSpan for DieConstruct {
    fn span(&self) -> Span {
        if let Some(arguments) = &self.arguments {
            self.die.span().join(arguments.span())
        } else {
            self.die.span()
        }
    }
}
