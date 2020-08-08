module Listen
  @logger = nil

  class << self
    attr_accessor :logger

    def setup_default_logger_if_unset
      @logger ||= ::Logger.new(STDERR).tap do |logger|
        debugging = ENV['LISTEN_GEM_DEBUGGING']
        logger.level =
          case debugging.to_s
          when /2/
            ::Logger::DEBUG
          when /true|yes|1/i
            ::Logger::INFO
          else
            ::Logger::ERROR
          end
      end
    end
  end

  module Logger
    class << self
      [:fatal, :error, :warn, :info, :debug].each do |meth|
        define_method(meth) do |*args, &block|
          Listen.logger.public_send(meth, *args, &block) if Listen.logger
        end
      end
    end
  end
end
