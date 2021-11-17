# @api private
plan plan_step::test (
  Optional[String[1]] $start_at_step = undef,
) {
  plan_step('one')
  out::message('beginning step one')
  run_plan('plan_step::test::child', name => 'child1')

  plan_step('two') || {
    out::message('only do this if step "two" is not skipped')
    run_plan('plan_step::test::child', name => 'child2')
  }

  plan_step('three')
  out::message('beginning step three')
  run_plan('plan_step::test::child', name => 'child3')

  plan_step('four') || {
    out::message('only do this if step "four" is not skipped')
  }

  return('Plan complete')
}
