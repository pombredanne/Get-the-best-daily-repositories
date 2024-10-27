use fennec_ast::*;
use fennec_reporting::*;
use fennec_span::HasSpan;
use fennec_walker::Walker;

use crate::context::LintContext;
use crate::rule::Rule;

const GLOBALS_VARIABLE: &'static str = "$GLOBALS";

#[derive(Clone, Debug)]
pub struct NoGlobalRule;

impl Rule for NoGlobalRule {
    fn get_name(&self) -> &'static str {
        "no-global"
    }

    fn get_default_level(&self) -> Option<Level> {
        Some(Level::Error)
    }
}

impl<'a> Walker<LintContext<'a>> for NoGlobalRule {
    fn walk_in_global<'ast>(&self, global: &'ast Global, context: &mut LintContext<'a>) {
        let mut issue = Issue::new(context.level(), "unsafe use of `global`")
            .with_annotation(Annotation::primary(global.global.span))
            .with_note("the `global` keyword introduces global state into your function, making it harder to reason about and test.")
            .with_note("it can also lead to unexpected behavior and make your code more prone to errors.")
            .with_note("consider using dependency injection or other techniques to manage state and avoid relying on global variables.")
            .with_help("refactor your code to avoid using the `global` keyword.");

        for variable in global.variables.iter() {
            issue = issue.with_annotation(Annotation::secondary(variable.span()))
        }

        context.report(issue);
    }

    fn walk_in_direct_variable<'ast>(&self, direct_variable: &'ast DirectVariable, context: &mut LintContext<'a>) {
        let name = context.interner.lookup(direct_variable.name);
        if !GLOBALS_VARIABLE.eq(name) {
            return;
        }

        let issue = Issue::new(context.level(), "unsafe use of `$GLOBAL` variable")
            .with_annotation(Annotation::primary(direct_variable.span))
            .with_note("accessing the `$GLOBALS` array directly can lead to similar issues as using the `global` keyword.")
            .with_note("it can make your code harder to understand, test, and maintain due to the implicit global state.")
            .with_note("consider using dependency injection or other techniques to manage state and avoid relying on global variables.")
            .with_help("refactor your code to avoid using the `$GLOBALS` variable directly.");

        context.report(issue);
    }
}
