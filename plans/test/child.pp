# @api private
plan plan_step::test::child (
  String[1] $name,
) {
  plan_step("${name} first") || {
    run_task('service', 'localhost',
      action => status,
      name   => 'puppet',
    )
    out::message("${name} first performed")
  }

  plan_step("${name} second") || {
    out::message("${name} second performed")
  }
}
