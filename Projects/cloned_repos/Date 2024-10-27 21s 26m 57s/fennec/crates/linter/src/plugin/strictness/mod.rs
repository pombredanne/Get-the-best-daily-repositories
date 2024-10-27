use crate::plugin::strictness::rules::no_assignment_in_condition::NoAssignmentInConditionRule;
use crate::plugin::strictness::rules::require_constant_type::RequireConstantTypeRule;
use crate::plugin::strictness::rules::require_identity_comparison::RequireIdentityComparisonRule;
use crate::plugin::strictness::rules::require_parameter_type::RequireParameterTypeRule;
use crate::plugin::strictness::rules::require_property_type::RequirePropertyTypeRule;
use crate::plugin::strictness::rules::require_return_type::RequireReturnTypeRule;
use crate::plugin::strictness::rules::require_strict_types::RequireStrictTypesRule;

use crate::plugin::Plugin;
use crate::rule::Rule;

pub mod rules;

#[derive(Debug)]
pub struct StrictnessPlugin;

impl Plugin for StrictnessPlugin {
    fn get_name(&self) -> &'static str {
        "strictness"
    }

    fn is_enabled_by_default(&self) -> bool {
        true
    }

    fn get_rules(&self) -> Vec<Box<dyn Rule>> {
        vec![
            Box::new(NoAssignmentInConditionRule),
            Box::new(RequireConstantTypeRule),
            Box::new(RequireParameterTypeRule),
            Box::new(RequirePropertyTypeRule),
            Box::new(RequireReturnTypeRule),
            Box::new(RequireStrictTypesRule),
            Box::new(RequireIdentityComparisonRule),
        ]
    }
}
