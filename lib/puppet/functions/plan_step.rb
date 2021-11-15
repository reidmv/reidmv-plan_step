# frozen_string_literal: true

Puppet::Functions.create_function(:'plan_step', Puppet::Functions::InternalFunction) do
  dispatch :plan_step do
    scope_param
    param 'String', :step_name
    optional_param 'Boolean', :conditional
    block_param
  end

  def plan_step(scope, step_name, conditional = true)
    topscope = scope.compiler.topscope
    start_at = start_at_step(scope)
    started  = if start_at.nil? || topscope.bound?('__plan_step_started__')
                           true
                         elsif step_name == start_at
                           topscope['__plan_step_started__'] = true
                         else
                           false
                         end

    if started
      call_function('out::message', "# Plan Step: #{step_name}")
      yield
    else
      call_function('out::message', "# Plan Step: #{step_name} - SKIPPING")
    end
  end

  # Return the best-defined "start_at_step" variable for the scope. The scope
  # doesn't have to have this variable defined directly; a parent scope's
  # version of the variable will work as well.
  def start_at_step(scope)
    return nil if scope.nil?
    return start_at_step(scope.parent) unless scope.bound?('start_at_step')
    scope['start_at_step'] || start_at_step(scope.parent)
  end
end
