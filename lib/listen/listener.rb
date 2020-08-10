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
  class Listener
    # TODO: move the state machine's methods private
    include Listen::FSM

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
    def initialize(*dirs, &block)
      options = dirs.last.is_a?(Hash) ? dirs.pop : {}

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Config.new")

      @config = Config.new(options)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Event::Queue::Config.new")

      eq_config = Event::Queue::Config.new(@config.relative?)
      queue = Event::Queue.new(eq_config)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Silencer.new")

      silencer = Silencer.new
      rules = @config.silencer_rules

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Silencer::Controller.new")

      @silencer_controller = Silencer::Controller.new(silencer, rules)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Backend.new")

      @backend = Backend.new(dirs, queue, silencer, @config)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call QueueOptimizer::Config.new")

      optimizer_config = QueueOptimizer::Config.new(@backend, silencer)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Event::Config.new")

      pconfig = Event::Config.new(
        self,
        queue,
        QueueOptimizer.new(optimizer_config),
        @backend.min_delay_between_events,
        &block)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call Event::Loop.new")

      @processor = Event::Loop.new(pconfig)

      Listen::Logger.debug("InvocaDebug: Listener#initialize about to call super")

      super() # FSM
    end

    start_state :initializing

    state :initializing, to: [:backend_started, :stopped]

    state :backend_started, to: [:processing_events, :stopped] do
      backend.start
    end

    state :processing_events, to: [:paused, :stopped] do
      processor.start
    end

    state :paused, to: [:processing_events, :stopped] do
      processor.pause
    end

    state :stopped, to: [:backend_started] do
      backend.stop # should be before processor.stop to halt events ASAP
      processor.stop
    end

    # Starts processing events and starts adapters
    # or resumes invoking callbacks if paused
    def start
      case state
      when :initializing
        transition :backend_started
        transition :processing_events
      when :paused
        transition :processing_events
      else
        raise ArgumentError, "cannot start from state #{state.inspect}"
      end
    end

    # Stops both listening for events and processing them
    def stop
      transition :stopped
    end

    # Stops invoking callbacks (messages pile up)
    def pause
      transition :paused
    end

    # processing means callbacks are called
    def processing?
      state == :processing_events
    end

    def paused?
      state == :paused
    end

    def stopped?
      state == :stopped
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

    private

    attr_reader :processor
    attr_reader :backend
  end
end
