namespace :zomeki do
  namespace :sys do
    desc 'Delete duplicated values. (leave only latest values.)'
    task(:clean_sequence => :environment) do
      Sys::Sequence.transaction do
        before_key = {}
        Sys::Sequence.order(name: :asc, version: :asc, id: :desc).each do |sequence|
          if before_key[:name] == sequence.name && before_key[:version] == sequence.version
            sequence.destroy
            puts "[DELETED] name: #{sequence.name}, version: #{sequence.version}"
          else
            before_key[:name], before_key[:version] = sequence.name, sequence.version
          end
        end
      end
    end

    namespace :tasks do
      desc 'Exec tasks'
      task(:exec => :environment) do
        Script.run('sys/script/tasks/exec')
      end
    end
  end
end
