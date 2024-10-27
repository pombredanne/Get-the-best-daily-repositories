use serde::Deserialize;
use serde::Serialize;

use fennec_span::HasSpan;
use fennec_span::Span;

use crate::ast::attribute::AttributeList;
use crate::ast::block::Block;
use crate::ast::function_like::parameter::FunctionLikeParameterList;
use crate::ast::function_like::r#return::FunctionLikeReturnTypeHint;
use crate::ast::identifier::LocalIdentifier;
use crate::ast::keyword::Keyword;
use crate::sequence::Sequence;

/// Represents a `function` declaration in PHP.
///
/// Example:
///
/// ```php
/// <?php
///
/// function foo(): string {
///    return 'bar';
/// }
/// ```
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct Function {
    pub attributes: Sequence<AttributeList>,
    pub function: Keyword,
    pub ampersand: Option<Span>,
    pub name: LocalIdentifier,
    pub parameters: FunctionLikeParameterList,
    pub return_type_hint: Option<FunctionLikeReturnTypeHint>,
    pub body: Block,
}

impl HasSpan for Function {
    fn span(&self) -> Span {
        if let Some(attribute_list) = self.attributes.first() {
            return attribute_list.span().join(self.body.span());
        }

        self.function.span().join(self.body.span())
    }
}
