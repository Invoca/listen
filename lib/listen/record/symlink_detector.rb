require 'set'

module Listen
  # @private api
  class Record
    class SymlinkDetector
      WIKI = 'https://github.com/guard/listen/wiki/Duplicate-directory-errors'.freeze

      SYMLINK_LOOP_ERROR = <<-EOS.freeze
        ** ERROR: directory is already being watched! **

        Directory: %s

        is already being watched through: %s

        MORE INFO: #{WIKI}
      EOS

      class Error < RuntimeError; end

      def initialize
        @real_dirs = Set.new
      end

      def verify_unwatched!(entry)
        real_path = entry.real_path
        @real_dirs.add?(real_path) or _fail(entry.sys_path, real_path)
      end

      private

      def _fail(symlinked, real_path)
        warn format(SYMLINK_LOOP_ERROR, symlinked, real_path)
        raise Error, 'Failed due to looped symlinks'
      end
    end
  end
end
