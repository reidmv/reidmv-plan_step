plan plan_step::test (
  Optional[String[1]] $start_at_step = undef,
) {
  plan_step('one') || {
    out::message('beginning nested plan child1')
    run_plan('plan_step::test::child', name => 'child1')
    out::message('finished nested plan child1')
  }

  plan_step('two') || {
    out::message('Step 2 performed!')
  }

  plan_step('three') || {
    out::message('beginning nested plan child3')
    run_plan('plan_step::test::child', name => 'child3')
    out::message('finished nested plan child3')
  }

  plan_step('four') || {
    out::message('Step 4 performed!')
  }

  return('Plan complete')
}
