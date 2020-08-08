require 'thread'

require 'timeout'
require 'listen/event/processor'

module Listen
  module Event
    # Caller stores instance in @processor. Why not call it Processor?
    class Loop
      class Error < RuntimeError; end
      class Error::NotStarted < Error; end

      def initialize(config)
        @config = config
        @state = :paused
        @reasons = ::Queue.new # @wakeup_reasons

        @wait_thread = Internals::ThreadPool.add do
          process_events(config)
        end

        Listen::Logger.debug('Waiting for processing to start...')
        @mutex.synchronize do
          if @state != :processing
            @processing.wait
          end
        end
        Listen::Logger.debug('...processing started')
      end

      def wakeup_on_event
        if processing? && @wait_thread.alive?
          _wakeup(:event)
        end
      end

      private \
      def processing?
        @state == :processing
      end

      def resume
        _wakeup(:resume)
      end

      def pause
        # TODO: works?
        raise NotImplementedError
      end

      def stop
        if @wait_thread.alive?
          _wakeup(:teardown)
          @wait_thread.join
        end

        @wait_thread = nil
      end

      private

      attr_reader :config

      def process_events(config)
        processor = Event::Processor.new(config, @reasons) # @wakeup_reasons

        @mutex.synchronize do
          @state = :processing
          @processing.signal
        end

        processor.loop_for(config.min_delay_between_events)

      rescue StandardError => ex
        _nice_error(ex)
      end

      # Apparently unused?

      # def _sleep(*args)
      #   Kernel.sleep(*args)
      # end

      def _nice_error(ex)
        indent = "\n -- "
        msg = format(
          'exception while processing events: %s Backtrace:%s%s',
          ex,
          indent,
          ex.backtrace * indent
        )
        Listen::Logger.error(msg)
      end

      def _wakeup(reason)
        @reasons << reason # @wakeup_reasons
        @wait_thread.wakeup
      end
    end
  end
end
