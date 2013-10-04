module Rfd
  class Item
    include Comparable
    attr_reader :name
    attr_accessor :index

    def initialize(dir: nil, name: nil)
      @dir, @name, @marked = dir, name, false
    end

    def path
      @path ||= File.join @dir, @name
    end

    def basename
      @basename ||= File.basename name, extname
    end

    def extname
      @extname ||= File.extname name
    end

    def full_display_name
      n = @name.dup
      n << " -> #{target}" if symlink?
      n
    end

    def display_name
      n = full_display_name
      if mb_size(n) <= 43
        n
      else
        if symlink?
          mb_left n, 42
        else
          "#{mb_left(basename, 42 - extname.length)}…#{extname}"
        end
      end
    end

    def stat
      @stat ||= File.lstat path
    end

    def color
      if symlink?
        FFI::NCurses::COLOR_MAGENTA
      elsif hidden?
        FFI::NCurses::COLOR_GREEN
      elsif directory?
        FFI::NCurses::COLOR_CYAN
      elsif executable?
        FFI::NCurses::COLOR_RED
      else
        FFI::NCurses::COLOR_WHITE
      end
    end

    def size
      directory? ? 0 : stat.size
    end

    def size_or_dir
      directory? ? '<DIR>' : size.to_s
    end

    def atime
      stat.atime.strftime('%Y-%m-%d %H:%M:%S')
    end

    def ctime
      stat.ctime.strftime('%Y-%m-%d %H:%M:%S')
    end

    def mtime
      stat.mtime.strftime('%Y-%m-%d %H:%M:%S')
    end

    def mode
      m = stat.mode
      ret = directory? ? 'd' : symlink? ? 'l' : '-'
      [(m & 0700) / 64, (m & 070) / 8, m & 07].inject(ret) do |str, s|
        str << "#{s & 4 == 4 ? 'r' : '-'}#{s & 2 == 2 ? 'w' : '-'}#{s & 1 == 1 ? 'x' : '-'}"
      end
      if m & 04000 != 0
        ret[3] = directory? ? 's' : 'S'
      end
      if m & 02000 != 0
        ret[6] = directory? ? 's' : 'S'
      end
      if m & 01000 == 512
        ret[-1] = directory? ? 't' : 'T'
      end
      ret
    end

    def directory?
      stat.directory?
    end

    def symlink?
      stat.symlink?
    end

    def hidden?
      name.start_with?('.') && (name != '.') && (name != '..')
    end

    def executable?
      stat.executable?
    end

    def target
      File.readlink path if symlink?
    end

    def read
      File.read path
    end

    def toggle_mark
      @marked = !@marked
      current_mark
    end

    def marked?
      @marked
    end

    def current_mark
      marked? ? '*' : ' '
    end

    def mb_left(str, size)
      len = 0
      index = str.each_char.with_index do |c, i|
        break i if len + mb_char_size(c) > size
        len += mb_size c
      end
      str[0, index]
    end

    def mb_char_size(c)
      c == '…' ? 1 : c.bytesize == 1 ? 1 : 2
    end

    def mb_size(str)
      str.each_char.inject(0) {|l, c| l += mb_char_size(c)}
    end

    def mb_ljust(str, size)
      "#{str}#{' ' * [0, size - mb_size(str)].max}"
    end

    def to_s
      "#{current_mark}#{mb_ljust(display_name, 43)}#{size_or_dir.rjust(13)}"
    end

    def <=>(o)
      if directory? && !o.directory?
        1
      elsif !directory? && o.directory?
        -1
      else
        name <=> o.name
      end
    end
  end
end