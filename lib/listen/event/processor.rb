require 'listen/logger'

module Listen
  module Event
    class Processor
      def initialize(config, reasons)
        @config = config
        @listener = config.listener
        @reasons = reasons # @wakeup_reasons
        _reset_no_unprocessed_events
      end

      # TODO: implement this properly instead of checking the state at arbitrary
      # points in time
      def loop_for(latency)
        @latency = latency

        loop do
          Listen::Logger.debug("InvocaDebug: about to _wait_until_events")
          _wait_until_events
          Listen::Logger.debug("InvocaDebug: about to _wait_until_events_calm_down")
          _wait_until_events_calm_down
          Listen::Logger.debug("InvocaDebug: about to _wait_until_no_longer_paused")
          _wait_until_no_longer_paused
          Listen::Logger.debug("InvocaDebug: about to _process_changes")
          _process_changes
        end
      catch :stopped
        Listen::Logger.debug('Processing stopped')
      end

      private

      def _wait_until_events_calm_down
        loop do
          now = _timestamp

          # Assure there's at least latency between callbacks to allow
          # for accumulating changes
          diff = _deadline - now
          diff <= 0 and break

          # give events a bit of time to accumulate so they can be
          # compressed/optimized
          _sleep(:waiting_until_latency, diff)
        end
      end

      def _wait_until_no_longer_paused
        # TODO: may not be a good idea?
        while @listener.paused?
          _sleep(:waiting_for_unpause)
        end
      end

      def _check_stopped
        if @listener.stopped?
          _flush_wakeup_reasons
          throw :stopped
        end
      end

      def _sleep(_local_reason, *args)
        _check_stopped
        sleep_duration = @config.sleep(*args)
        _check_stopped

        _flush_wakeup_reasons do |reason|
          next if reason != :event # wakeup_reason
          unless @listener.paused?
            _remember_time_of_first_unprocessed_event
          end
        end

        sleep_duration
      end

      def _remember_time_of_first_unprocessed_event
        @first_unprocessed_event_time ||= _timestamp
      end

      def _reset_no_unprocessed_events
        @first_unprocessed_event_time = nil
      end

      def _deadline
        @first_unprocessed_event_time + @latency
      end

      def _wait_until_events
        # TODO: long sleep may not be a good idea?
        _sleep(:waiting_for_events) while @config.event_queue.empty?
        @first_unprocessed_event_time ||= _timestamp
      end

      def _flush_wakeup_reasons
        until @reasons.empty? # @wakeup_reasons
          reason = @reasons.pop
          yield reason if block_given?
        end
      end

      def _timestamp
        @config.timestamp
      end

      # for easier testing without sleep loop
      def _process_changes
        _reset_no_unprocessed_events

        changes = []
        changes << @config.event_queue.pop until @config.event_queue.empty?

        Listen::Logger.debug("InvocaDebug: _process_changes popped #{changes.size}")

        if @config.callable?
          hash = @config.optimize_changes(changes)
          result = [hash[:modified], hash[:added], hash[:removed]]
          if result.all?(&:empty?)
            Listen::Logger.debug("InvocaDebug: _process_changes returning because #{changes.inspect} optimized to empty")
          end

          block_start = _timestamp
          @config.call(*result)
          Listen::Logger.debug "Callback took #{_timestamp - block_start} sec"
        end
      end
    end
  end
end
