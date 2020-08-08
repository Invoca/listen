require 'English'

require 'listen/version'

require 'listen/backend'

require 'listen/silencer'
require 'listen/silencer/controller'

require 'listen/queue_optimizer'

require 'listen/fsm'

require 'listen/event/loop'
require 'listen/event/queue'
require 'listen/event/config'

require 'listen/listener/config'

module Listen
  # This object is what's return by `Listen.to`. So it's the public interface for `start`, `stop`, `pause` etc.

  class Listener
    # Initializes the directories listener.
    #
    # @param [String] directory the directories to listen to
    # @param [Hash] options the listen options (see Listen::Listener::Options)
    #
    # @yield [modified, added, removed] the changed files
    # @yieldparam [Array<String>] modified the list of modified files
    # @yieldparam [Array<String>] added the list of added files
    # @yieldparam [Array<String>] removed the list of removed files
    #
    def initialize(*dirs, **options, &block)
      @dirs = dirs
      @config = Config.new(options)
      @block = block
      @active_listener = nil
      @silencer_controller = Silencer::Controller.new(Silencer.new, @config.silencer_rules) # Is this used?
    end

    def start
      @active_listener ||= ActiveListener.new(@dirs, @config.relative, &@block)
    end

    def pause
      @active_listener&.pause
    end

    def stop
      @active_listener&.stop
      @active_listener = nil
    end

    def paused?
      @active_listener&.paused?
    end

    def stopped?
      !@active_listener
    end

    def ignore(regexps)
      @silencer_controller.append_ignores(regexps)
    end

    def ignore!(regexps)
      @silencer_controller.replace_with_bang_ignores(regexps)
    end

    def only(regexps)
      @silencer_controller.replace_with_only(regexps)
    end
  end

  class ActiveListener
    def initialize(dirs, config_relative, &block)
      @processor = nil
      queue = Event::Queue.new(config_relative) { @processor.wakeup_on_event }

      silencer = Silencer.new

      @pconfig = Event::Config.new(
        self,
        queue,
        QueueOptimizer.new(QueueOptimizer::Config.new(@backend, silencer)),
        @backend.min_delay_between_events,
        &block)

      @processor = Event::Loop.new(@pconfig)

      @state = :started

      @backend = Backend.new(dirs, queue, silencer, @config)
    end

    # If paused, resumes invoking callbacks
    def start
      state == :paused or raise ArgumentError, "can't start from state #{state}"

      Listen::Logger.debug("InvocaDebug: Listener#start about to transition :started state: #{state}")
      @processor.resume
      @state = :started
    end

    # Stops both listening for events and processing them
    def stop
      @backend.stop # should be before @processor.teardown to halt events ASAP
      @backend = nil
      @processor.stop
      @processor = nil
      @state = nil
    end

    # Stops frontend callbacks (messages pile up)
    def pause
      # Not implemented
      @processor.pause
      @state = :paused
    end

    # processing means callbacks are called
    def processing?
      @state == :started
    end

    def paused?
      @state == :paused
    end
  end
end
