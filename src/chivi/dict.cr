require "time"
require "json"
require "colorize"

class Chivi::Dict
  EPOCH = Time.utc(2020, 1, 1)

  SEP_0 = "ǁ"
  SEP_1 = "¦"

  class Item
    include JSON::Serializable

    getter key : String
    getter vals : Array(String)
    getter mtime : Time? = nil
    getter extra : String? = nil

    def initialize(line : String)
      cols = line.split(SEP_0)

      @key = cols[0]
      @vals = (cols[1]? || "").split(SEP_1)

      mtime = cols[2]?.try(&.to_i?) || 0
      @mtime = EPOCH + mtime.minutes

      @extra = cols[3]?
    end

    def initialize(@key : String, vals : String, @mtime = nil, @extra = nil)
      @vals = vals.split(SEP_1)
    end

    def initialize(@key : String, @vals : Array(String), @mtime = nil, @extra = nil)
    end

    def to_s(io : IO)
      io << @key << SEP_0 << @vals.join(SEP_1)
      if mtime = @mtime
        io << SEP_0 << (mtime - EPOCH).total_minutes.to_i
      end

      if extra = @extra
        io << SEP_0 << extra
      end
    end
  end

  class Leaf
    alias Trie = Hash(Char, Leaf)

    property item : Item?
    property trie : Trie

    def initialize(@item : Item? = nil)
      @trie = Trie.new
    end
  end

  # Class

  @@dicts = {} of String => Dict

  def self.dicts
    @@dicts
  end

  def self.load!(file : String)
    raise "File [#{file.colorize(:red)}] not found!" unless File.exists?(file)
    load(file)
  end

  def self.load(file : String) : Dict
    @@dicts[file] ||= new(file, preload: true)
  end

  getter file : String
  getter trie : Leaf = Leaf.new
  getter size : Int32 = 0
  getter mtime : Time = Time.utc

  def initialize(@file : String, preload : Bool = true)
    load!(@file) if preload && File.exists?(@file)
  end

  def load!(file : String = @file) : Dict
    @mtime ||= File.info(file).modification_time

    time1 = Time.monotonic
    lines = File.read_lines(file)
    lines.each { |line| put(Item.new(line)) }
    time2 = Time.monotonic

    elapsed = (time2 - time1).total_milliseconds
    puts "- Loaded [#{file.colorize(:yellow)}], \
            lines: #{lines.size.colorize(:yellow)}, \
            time: #{elapsed.colorize(:yellow)}ms"

    self
  end

  def set(key : String, vals : String | Array(String), extra : String? = nil)
    item = Item.new(key, vals, Time.utc, extra)
    File.open(@file, "a") { |f| f.puts item }
    put(item)
  end

  def del(key : String, extra : String? = nil)
    set(key, [] of String, extra)
  end

  def put(key : String, vals : String | Array(String), extra : String? = nil)
    put(Item.new(key, vals))
  end

  def put(new_item : Item) : Item?
    leaf = new_item.key.chars.reduce(@trie) do |leaf, char|
      leaf.trie[char] ||= Leaf.new
    end

    old_item = leaf.item
    leaf.item = new_item

    @size += 1 if old_item.nil?
    old_item
  end

  def find(key : String) : Item?
    leaf = @trie

    key.chars.each do |char|
      leaf = leaf.trie[char]?
      return nil unless leaf
    end

    leaf.item
  end

  def scan(chars : Array(Char) | String, offset : Int32 = 0)
    res = [] of Item

    leaf = @trie
    offset.upto(chars.size - 1) do |idx|
      char = chars[idx]
      break unless leaf = leaf.trie[char]?
      if item = leaf.item
        res << item
      end
    end

    res
  end

  def includes?(key)
    find(key) != nil
  end

  def []?(key)
    find(key)
  end

  def []=(item : Item)
    put(item)
  end

  include Enumerable(Item)

  def each
    queue = [@trie]
    while leaf = queue.pop?
      leaf.trie.each_value do |leaf|
        queue << leaf
        if item = leaf.item
          yield item
        end
      end
    end
  end

  def save!(file : String = @file)
    File.open(file, "w") do |f|
      each { |item| f.puts item }
    end

    puts "- Saved [#{file.colorize(:yellow)}], \
            items: #{@size.colorize(:yellow)}"
  end
end
