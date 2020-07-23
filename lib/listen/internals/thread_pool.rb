require 'listen/logger'

module Listen
  # @private api
  module Internals
    module ThreadPool
      def self.add(&block)
        calling_stack = caller.dup
        Thread.new do
          begin
            Listen::Logger.debug("InvocaDebug: thread starting")
            block.call
            Listen::Logger.debug("InvocaDebug: thread stopping cleanly")
          rescue Exception => ex # we want to rescue ALL exceptions since we are at the top of a thread
            Listen::Logger.fatal("Listen gem thread exception: #{ex.class.name}: #{ex.message}\n#{ex.backtrace.join("\n")}\n" +
                                 "ThreadPool.add called from:\n#{calling_stack.join("\n")}"
            )
          end
        end.tap { |thread| (@threads ||= Queue.new) << thread }
      end

      def self.stop
        return unless @threads ||= nil
        return if @threads.empty? # return to avoid using possibly stubbed Queue

        killed = Queue.new
        # You can't kill a read on a descriptor in JRuby, so let's just
        # ignore running threads (listen rb-inotify waiting for disk activity
        # before closing)  pray threads die faster than they are created...
        limit = RUBY_ENGINE == 'jruby' ? [1] : []

        killed << @threads.pop.kill until @threads.empty?
        until killed.empty?
          th = killed.pop
          th.join(*limit) unless th[:listen_blocking_read_thread]
        end
      end
    end
  end
end
