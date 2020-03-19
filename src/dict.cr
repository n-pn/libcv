require "colorize"
require "benchmark"

class Chivi::Dict
  SEP = "|"

  # Child
  class Item
    getter key : String
    property val : String

    def self.parse(line : String)
      cols = line.split(SEP, 2)
      new(cols[0], cols[1]? || "")
    end

    def initialize(@key : String, @val : String)
    end

    def to_s(io : IO)
      io << @key << SEP << @val
    end
  end

  class Node
    alias Trie = Hash(Char, Node)

    property item : Item?
    property trie : Trie

    def initialize(@item : Item? = nil)
      @trie = Trie.new
    end
  end

  # Class

  @@dicts = {} of String => Dict

  def self.load(file : String, reload : Bool = false) : Dict
    if dict = @@dicts[file]?
      return dict unless reload
    end

    @@dicts[file] = new(file, preload: true)
  end

  def self.load!(file : String, reload = false)
    raise "File [#{file.colorize(:red)}] not found!" unless File.exists?(file)
    load(file, reload: reload)
  end

  EPOCH = Time.utc(2020, 1, 1)

  def self.mtime(time = Time.utc) : Int32
    (time - EPOCH).total_minutes.to_i
  end

  # Instance

  @trie = Node.new
  @mtimes = Hash(String, Int32).new

  getter file : String
  getter size : Int32 = 0
  getter mtime : Int32 = 0

  def initialize(@file : String, preload = true)
    if File.exists?(@file)
      load!(@file) if preload
      mtime = File.info(@file).modification_time
      @mtime = Dict.mtime(mtime)
    end
  end

  def load!(file : String = @file) : Dict
    count = 0

    realtime = Benchmark.realtime do
      lines = File.read_lines(file)
      count = lines.size

      lines.each do |line|
        cols = line.split(SEP)
        key = cols[0]
        val = cols[1]? || ""

        put(key, val)

        if mtime = cols[2]?
          mtime = mtime.to_i
          @mtime = mtime
          @mtimes[key] = mtime
        end
      end
    end

    elapse = realtime.total_milliseconds
    puts "- Loaded [#{file.colorize(:yellow)}], lines: #{count.colorize(:yellow)}, time: #{elapse.colorize(:yellow)}ms"

    self
  end

  def set(key : String, val : String) : String
    item = Item.new(key, val)
    @mtimes[key] = Dict.mtime

    File.open(@file, "a") do |f|
      f << key << SEP << val << SEP << mtime << "\n"
    end

    put(item)
  end

  def del(key : String) : String
    set(key, "")
  end

  def put(key : String, val : String)
    put(Item.new(key, val))
  end

  def put(item : Item) : String
    @size += 1 unless item.val.empty?
    old_val = ""

    node = item.key.chars.reduce(@trie) do |node, char|
      node.trie[char] ||= Node.new
    end

    if old = node.item
      old_val = old.val
      old.val = item.val
      @size -= 1 unless old_val.empty?
    else
      node.item = item
    end

    old_val
  end

  def find(key : String) : Item?
    node = @trie

    key.chars.each do |char|
      node = node.trie[char]?
      return nil unless node
    end

    node.item
  end

  def scan(chars : Array(Char), offset : Int32 = 0)
    output = [] of Item

    node = @trie
    chars[offset..-1].each do |char|
      if node = node.trie[char]?
        if item = node.item
          output << item
        end
      else
        break
      end
    end

    output
  end

  include Enumerable(Item)

  def each
    queue = [@trie]
    while node = queue.pop?
      node.trie.each_value do |node|
        queue << node
        if item = node.item
          yield item
        end
      end
    end
  end

  def save!(file : String = @file)
    File.open(file, "w") do |f|
      each do |item|
        f << item.key << SEP << item.val
        if mtime = @mtimes[item.key]?
          f << SEP << mtime
        end
        f << "\n"
      end
    end

    puts "- Save to [#{file.colorize(:yellow)}], items: #{@size.colorize(:yellow)}"
  end
end
