use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::argument::ArgumentList;
use crate::ast::class_like::member::ClassLikeMemberSelector;
use crate::ast::expression::Expression;

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
#[serde(tag = "type", content = "value")]
pub enum Call {
    Function(FunctionCall),
    Method(MethodCall),
    NullSafeMethod(NullSafeMethodCall),
    StaticMethod(StaticMethodCall),
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct FunctionCall {
    pub function: Box<Expression>,
    pub arguments: ArgumentList,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct MethodCall {
    pub object: Box<Expression>,
    pub arrow: Span,
    pub method: ClassLikeMemberSelector,
    pub arguments: ArgumentList,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct NullSafeMethodCall {
    pub object: Box<Expression>,
    pub question_mark_arrow: Span,
    pub method: ClassLikeMemberSelector,
    pub arguments: ArgumentList,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct StaticMethodCall {
    pub class: Box<Expression>,
    pub double_colon: Span,
    pub method: ClassLikeMemberSelector,
    pub arguments: ArgumentList,
}

impl HasSpan for Call {
    fn span(&self) -> Span {
        match self {
            Call::Function(f) => f.span(),
            Call::Method(m) => m.span(),
            Call::NullSafeMethod(n) => n.span(),
            Call::StaticMethod(s) => s.span(),
        }
    }
}

impl HasSpan for FunctionCall {
    fn span(&self) -> Span {
        self.function.span().join(self.arguments.span())
    }
}

impl HasSpan for MethodCall {
    fn span(&self) -> Span {
        self.object.span().join(self.arguments.span())
    }
}

impl HasSpan for NullSafeMethodCall {
    fn span(&self) -> Span {
        self.object.span().join(self.arguments.span())
    }
}

impl HasSpan for StaticMethodCall {
    fn span(&self) -> Span {
        self.class.span().join(self.arguments.span())
    }
}
