# frozen_string_literal: true

# O3sr
module O3sr
  class Logger
    attr_accessor :fields

    def initialize(name)
      @fields = { name: name }
    end

    def with_field(key, value)
      new_logger = Logger.new(@fields[:name])
      new_logger.fields = @fields.merge({ key => value })
      new_logger
    end

    def format_fields
      fields.reduce("") do |acc, (k, v)|
        acc + "#{k}=#{v} "
      end 
    end

    def with_pid
      with_field(:pid, Process.pid)
    end

    def info(s)
      l = format_fields + "level=info msg=#{s}"
      puts(l)
    end
  end
end