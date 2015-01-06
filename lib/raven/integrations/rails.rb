require 'raven'
require 'rails'

module Raven
  class Rails < ::Rails::Railtie
    initializer "raven.use_rack_middleware" do |app|
      app.config.middleware.insert 0, "Raven::Rack"
    end

    initializer 'raven.action_controller' do
      ActiveSupport.on_load :action_controller do
        require 'raven/integrations/rails/controller_methods'
        include Raven::Rails::ControllerMethods
      end
    end

    config.after_initialize do
      Raven.configure(true) do |config|
        config.logger ||= ::Rails.logger
        config.project_root ||= ::Rails.root
      end

      if Raven.configuration.catch_debugged_exceptions
        if defined?(::ActionDispatch::DebugExceptions)
          require 'raven/integrations/rails/middleware/debug_exceptions_catcher'
          ::ActionDispatch::DebugExceptions.send(:include, Raven::Rails::Middleware::DebugExceptionsCatcher)
        elsif defined?(::ActionDispatch::ShowExceptions)
          require 'raven/integrations/rails/middleware/debug_exceptions_catcher'
          ::ActionDispatch::ShowExceptions.send(:include, Raven::Rails::Middleware::DebugExceptionsCatcher)
        end
      end
    end

    rake_tasks do
      require 'raven/integrations/tasks'
    end
  end

  StacktraceInterface::Frame.class_eval do
    def filename_with_rails
      return nil if self.abs_path.nil?

      rails_root = ::Rails.root.realpath.to_s.chomp(File::SEPARATOR)
      if self.abs_path.start_with?(rails_root)
        return self.abs_path[rails_root.size+1 .. -1]
      end

      filename_without_rails
    end

    alias_method :filename_without_rails, :filename
    alias_method :filename, :filename_with_rails
  end
end
