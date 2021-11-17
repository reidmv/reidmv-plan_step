# frozen_string_literal: true

require 'delegate'

Puppet::Functions.create_function(:'plan_step', Puppet::Functions::InternalFunction) do
  dispatch :plan_step do
    scope_param
    param 'String', :step_name
    optional_param 'Hash', :options
    optional_block_param
  end

  def plan_step(scope, step_name, opts = {})
    start_at = start_at_step(scope)
    started  = if start_at.nil? || start_marker
                 true
               elsif step_name == start_at
                 if current_executor.is_a?(SkipExecutor)
                   Puppet.push_context({:bolt_executor => current_executor.real_executor})
                 end
                 mark_start
               else
                 false
               end

    unless started || current_executor.is_a?(SkipExecutor)
      Puppet.push_context({:bolt_executor => SkipExecutor.new(current_executor)})
    end

    call_function('out::message', "Plan Step: \"#{step_name}\"")
    if block_given?
      if started
        yield
      else
        opts['default_value'] || Bolt::ResultSet.new([])
      end
    end
  end

  # Returns the currently configured Bolt::Executor.
  def current_executor
    Puppet.lookup(:bolt_executor)
  end

  # Return the value of a marker set by this function if/when a plan step is
  # reached matching the start-at parameter. This will return false if the
  # marker has not been set, and true after the marker is set.
  def start_marker
    Puppet.lookup(:plan_step__start_marker) { false }
  end

  # Set the start-at marker to true. This marker indicates the user-specified
  # "start_at_step" step has been reached.
  def mark_start
    Puppet.push_context({:plan_step__start_marker => true})
  end

  # Return the string value name of the start-at step. It is assumed that the
  # user will have passed this string as a parameter named "start_at_step" to
  # the top-level plan.
  def start_at_step(scope)
    Puppet.lookup(:plan_step__start_at_step) do
      start_at = scope.bound?('start_at_step') ? scope['start_at_step'] : nil
      Puppet.push_context({:plan_step__start_at_step => start_at})
      start_at
    end
  end

  # A delegator Bolt::Executor class, which will skip execution of any/all
  # commands, scripts, tasks, uploads, downloads, and out::messages.
  class SkipExecutor < SimpleDelegator
    attr_reader :real_executor

    def initialize(obj)
      @real_executor = obj
      super(obj)
    end

    def mock_results(description, targets)
      real_executor.publish_event(type: :message, message: Bolt::Util::Format.stringify("# #{description} - SKIPPED"), level: :info)
      Bolt::ResultSet.new([])
    end

    def run_command(targets, command, options = {}, position = [])
      description = options.fetch(:description, "command '#{command}'")
      mock_results(description, targets)
    end

    def run_script(targets, script, arguments, options = {}, position = [])
      description = options.fetch(:description, "script #{script}")
      mock_results(description, targets)
    end

    def run_task(targets, task, arguments, options = {}, position = [], log_level = :info)
      description = options.fetch(:description, "task #{task.name}")
      mock_results(description, targets)
    end

    def run_task_with(target_mapping, task, options = {}, position = [])
      targets = target_mapping.keys
      description = options.fetch(:description, "task #{task.name}")
      mock_results(description, targets)
    end

    def upload_file(targets, source, destination, options = {}, position = [])
      description = options.fetch(:description, "file upload from #{source} to #{destination}")
      mock_results(description, targets)
    end

    def download_file(targets, source, destination, options = {}, position = [])
      description = options.fetch(:description, "file download from #{source} to #{destination}")
      mock_results(description, targets)
    end

    #def run_plan(scope, plan, params)
    #  require 'pry'; Kernel.binding.pry
    #  plan.call_by_name_with_scope(scope, params, true)
    #end

    def publish_event(event)
      real_executor.publish_event(event.merge(message: "# #{event[:message]} - SKIPPED"))
    end
  end
end
