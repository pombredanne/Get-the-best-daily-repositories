use serde::Deserialize;
use serde::Serialize;
use strum::Display;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::class_like::member::ClassLikeConstantSelector;
use crate::ast::class_like::member::ClassLikeMemberSelector;
use crate::ast::expression::Expression;
use crate::ast::variable::Variable;

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord, Display)]
#[serde(tag = "type", content = "value")]
pub enum Access {
    Property(PropertyAccess),
    NullSafeProperty(NullSafePropertyAccess),
    StaticProperty(StaticPropertyAccess),
    ClassConstant(ClassConstantAccess),
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct PropertyAccess {
    pub object: Expression,
    pub arrow: Span,
    pub property: ClassLikeMemberSelector,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct NullSafePropertyAccess {
    pub object: Expression,
    pub question_mark_arrow: Span,
    pub property: ClassLikeMemberSelector,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct StaticPropertyAccess {
    pub class: Expression,
    pub double_colon: Span,
    pub property: Variable,
}

#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct ClassConstantAccess {
    pub class: Expression,
    pub double_colon: Span,
    pub constant: ClassLikeConstantSelector,
}

impl HasSpan for Access {
    fn span(&self) -> Span {
        match self {
            Access::Property(p) => p.span(),
            Access::NullSafeProperty(n) => n.span(),
            Access::StaticProperty(s) => s.span(),
            Access::ClassConstant(c) => c.span(),
        }
    }
}

impl HasSpan for PropertyAccess {
    fn span(&self) -> Span {
        self.object.span().join(self.property.span())
    }
}

impl HasSpan for NullSafePropertyAccess {
    fn span(&self) -> Span {
        self.object.span().join(self.property.span())
    }
}

impl HasSpan for StaticPropertyAccess {
    fn span(&self) -> Span {
        self.class.span().join(self.property.span())
    }
}

impl HasSpan for ClassConstantAccess {
    fn span(&self) -> Span {
        self.class.span().join(self.constant.span())
    }
}
