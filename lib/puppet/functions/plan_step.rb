# frozen_string_literal: true

require 'delegate'

Puppet::Functions.create_function(:'plan_step', Puppet::Functions::InternalFunction) do
  dispatch :plan_step do
    scope_param
    param 'String', :step_name
    optional_param 'Boolean', :conditional
    block_param
  end

  def plan_step(scope, step_name, conditional = true)
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
    yield
  end

  def current_executor
    Puppet.lookup(:bolt_executor)
  end

  def start_marker
    Puppet.lookup(:plan_step__start_marker) { false }
  end

  def mark_start
    Puppet.push_context({:plan_step__start_marker => true})
  end

  def start_at_step(scope)
    Puppet.lookup(:plan_step__start_at_step) do
      start_at = scope.bound?('start_at_step') ? scope['start_at_step'] : nil
      Puppet.push_context({:plan_step__start_at_step => start_at})
      start_at
    end
  end

  class SkipExecutor < SimpleDelegator
    attr_reader :real_executor

    def initialize(obj)
      @real_executor = obj
      super(obj)
    end

    def mock_results(description, targets)
      __getobj__.publish_event(type: :message, message: Bolt::Util::Format.stringify("# #{description} - SKIPPED"), level: :info)
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

    def publish_event(event)
      case event[:type]
      when :message, :verbose
        __getobj__.publish_event(event.merge(message: "# #{event[:message]} - SKIPPED"))
      else
        __getobj__.publish_event(event)
      end
    end
  end
end
