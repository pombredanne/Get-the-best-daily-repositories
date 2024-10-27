use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::class_like::member::ClassLikeMemberSelector;
use crate::ast::expression::Expression;

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
#[serde(tag = "type", content = "value")]
pub enum ClosureCreation {
    Function(FunctionClosureCreation),
    Method(MethodClosureCreation),
    StaticMethod(StaticMethodClosureCreation),
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct FunctionClosureCreation {
    pub function: Expression,
    pub left_parenthesis: Span,
    pub ellipsis: Span,
    pub right_parenthesis: Span,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct MethodClosureCreation {
    pub object: Expression,
    pub arrow: Span,
    pub method: ClassLikeMemberSelector,
    pub left_parenthesis: Span,
    pub ellipsis: Span,
    pub right_parenthesis: Span,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct StaticMethodClosureCreation {
    pub class: Expression,
    pub double_colon: Span,
    pub method: ClassLikeMemberSelector,
    pub left_parenthesis: Span,
    pub ellipsis: Span,
    pub right_parenthesis: Span,
}

impl HasSpan for ClosureCreation {
    fn span(&self) -> Span {
        match self {
            ClosureCreation::Function(f) => f.span(),
            ClosureCreation::Method(m) => m.span(),
            ClosureCreation::StaticMethod(s) => s.span(),
        }
    }
}

impl HasSpan for FunctionClosureCreation {
    fn span(&self) -> Span {
        self.function.span().join(self.right_parenthesis)
    }
}

impl HasSpan for MethodClosureCreation {
    fn span(&self) -> Span {
        self.object.span().join(self.right_parenthesis)
    }
}

impl HasSpan for StaticMethodClosureCreation {
    fn span(&self) -> Span {
        self.class.span().join(self.right_parenthesis)
    }
}
