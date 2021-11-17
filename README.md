# plan\_step

This module provides Bolt with the ability to define _plan steps_, which when used, permit plans to start executing not at the beginning but instead at a particular named step.

## Table of Contents

1. [Description](#description)
1. [Usage](#usage)
1. [Limitations](#limitations)

## Description

When testing, troubleshooting, or resuming a plan after a mid-way failure, it is often desirable to start execution of the plan not from the beginning, but from somewhere in the middle—perhaps to resume execution at a step which previously failed, for example, after fixing the cause of the failure.

Bolt does not (yet?) have this capability natively. This module provides a function to provide the basic capability.

## Usage

### Using `start_at_step` when running plans

If a plan uses `plan_step`, you can start it at a named step.

If you don't include a `start_at_step` parameter, the plan will start from the beginning. It will print out the names of steps as it goes, in case you want to resume at one of them later.

```
[user@host:~] % bolt plan run my::cool_plan
Plan Step: "begin"
lost in space
Plan Step: "danger-will-robinson"
...
```

To resume at a named step, include the `start_at_step` parameter.

```
[user@host:~] % bolt plan run my::cool_plan start_at_step="danger-will-robinson"
# Plan Step: "begin" - SKIPPED
# lost in space - SKIPPED
Plan Step: "danger-will-robinson"
...
```

### Writing plans that use `plan_step`

Writing a plan that uses `plan_step` might look something like this:

```puppet
plan my::cool_plan (
  Optional[String] $start_at_step,
) {
  plan_step('begin')
  out::message('lost in space')

  plan_step('danger-will-robinson')
  run_task('spaceship::shields_up', $targets)
  run_task('spaceship::fire_lasers', $targets)

  plan_step('lower-shields')
  run_task('shields::shields_down', $targets)

  return('all done')
}
```

Breaking it down, there are four important parts to using `plan_step` in a plan.

#### Include the `start_at_step` plan parameter

Your resumable plan should include an optional String parameter named `start_at_step`. Passing a value for this parameter is what tells Bolt to start at the specified step, rather than at the beginning.

```puppet
plan my::cool_plan (
  Optional[String] $start_at_step,
```

#### Define the very first step

Any code in your plan that happens before an invocation of the `plan_step` function cannot be skipped. Therefore, you should make a call to `plan_step` the very first line of code in your plan.

```puppet
plan_step('begin')
```

#### Include another `plan_step` wherever you need one

The `plan_step` function calls are your markers that define where you can start or resume the plan from. Whenever you need to be able to start at a given point, include a new step name there.

```puppet
plan_step('danger-will-robinson')
run_task('spaceship::shields_up', $targets)
run_task('spaceship::fire_lasers', $targets)

plan_step('lower-shields')
run_task('shields::shields_down', $targets)
```

#### Pay attention to Puppet code that relies on ResultSets

When starting at a middle plan step, plan code is still evaluated to get to that step. Nothing that executes on a target will be run, but if you have code that sets variables or analyzes results, it needs to be written in a way that's safe when there are no results, or starting at the step you want it to might not work.

Bolt functions like `run_task`, `run_command`, `run_script`, `upload_file`, and so forth will no-op and return an empty ResultSet until the start-at step is reached. If other code doesn't like that, it could cause the plan to fail, and be unable to start at the desired step.

If you have code that should not be executed at all, if the relevant step is being skipped, use a code block as part of your step. Note that if you do this, the _entire_ code block will be skipped, if that step of the plan is skipped. The `plan_step` can be configured to return a default value, in that case.

```puppet
$value = plan_step('special-code', default_value => 'did not jump') || {
  $jumps = run_task('spaceship::hyperjump', $targets)
  $jumps.first['jump-result']
}
```

## Limitations

Function calls besides Bolt-specific action executions will always be performed. Be careful of including custom function calls that have side effects, as they will not be skipped.

In this verison of `plan_step`, Bolt `apply` blocks will not be skipped. This should be fixed in future versions.
