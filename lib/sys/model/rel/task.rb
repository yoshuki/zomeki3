module Sys::Model::Rel::Task
  extend ActiveSupport::Concern

  included do
    has_many :tasks, class_name: 'Sys::Task', dependent: :destroy, as: :processable
    after_save :save_tasks

    scope :with_task_name, ->(name) {
      tasks = Sys::Task.arel_table
      joins(:tasks).where(tasks[:name].eq(name))
    }
  end

  def find_task_by_name(name)
    tasks.find_by(name: name).try!(:process_at)
  end

  # setter always returns supplied argument
  def in_tasks=(values)
    values = (values.kind_of?(Hash) ? values : {}).with_indifferent_access
    values.each {|k, v| task_schedules[k] = v }
  end

  def in_tasks
    tasks.inject(task_schedules) do |result, task|
      next result unless task.process_at
      result.tap {|r| r[task.name] = task.process_at.strftime('%Y-%m-%d %H:%M') }
    end
  end

  private

  def task_schedules
    @task_schedules ||= {}.with_indifferent_access
  end

  def save_tasks
    return true unless @task_schedules.kind_of?(Hash)

    schedules = @task_schedules
    @task_schedules = nil

    schedules.each do |key, value|
      tasks.where(name: key).each(&:destroy)
      next if value.blank?
      tasks.create(name: key, process_at: value, site_id: Core.site.try(:id))
    end
  end
end
