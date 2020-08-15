require 'listen/logger'

require 'thread'

require 'forwardable'

module Listen
  module Event
    class Queue
      extend Forwardable

      class Config
        def initialize(relative)
          @relative = relative
        end

        def relative?
          @relative
        end
      end

      def initialize(config)
        @event_queue = ::Queue.new
        @config = config
      end

      def <<(args)
        type, change, dir, path, options = *args
        fail "Invalid type: #{type.inspect}" unless [:dir, :file].include? type
        fail "Invalid change: #{change.inspect}" unless change.is_a?(Symbol)
        fail "Invalid path: #{path.inspect}" unless path.is_a?(String)

        safe_dir = _safe_relative_from_cwd(dir, @relative)

        Listen::Logger.debug("InvocaDebug: queuing #{[type, change, safe_dir, path, options]} to queue with depth #{@event_queue.size}")

        @event_queue.public_send(:<<, [type, change, safe_dir, path, options])
      end

      delegate empty?: :@event_queue
      delegate pop: :@event_queue
      delegate close: :@event_queue

      private

      def _safe_relative_from_cwd(dir, relative)
        if relative
          begin
            dir.relative_path_from(Pathname.pwd)
          rescue ArgumentError
            dir
          end
        else
          dir
        end
      end
    end
  end
end
