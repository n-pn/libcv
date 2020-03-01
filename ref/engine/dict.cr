require "colorize"
require "benchmark"

class Engine::Dict
  SEP = "="

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

  alias Items = Array(Item)

  class Node
    property item : Item?
    property trie : Hash(Char, Node)

    def initialize(@item : Item? = nil, @trie = Hash(Char, Node).new)
    end
  end

  getter list : Items
  getter size : Int32

  @list = Items.new
  @trie = Node.new
  @size = 0

  def self.load!(file : String)
    dict = new(file)
    dict.load!(file)
  end

  def initialize(@file : String, preload = true)
    load!(@file) if preload && File.exists?(@file)
  end

  def load!(file : String = @file)
    count = 0

    realtime = Benchmark.realtime do
      lines = File.read_lines(file)
      count = lines.size

      lines.each { |line| put(Item.parse(line)) }
    end

    elapse = realtime.total_milliseconds
    puts "- Loaded [#{file.colorize(:yellow)}], lines: #{count.colorize(:yellow)}, time: #{elapse.colorize(:yellow)}ms"

    self
  end

  def set(key : String, val : String) : String
    item = Item.new(key, val)
    File.open(@file, "a") { |f| f.puts item }
    put(item)
  end

  def del(key : String) : String
    set(key, "")
  end

  def put(item : Item) : String
    @size += 1 unless item.val.empty?
    old = ""

    node = item.key.chars.reduce(@trie) do |node, char|
      node.trie[char] ||= Node.new
    end

    if prev = node.item
      old = prev.val
      prev.val = item.val
      @size -= 1 unless old.empty?
    else
      @list << item
      node.item = item
    end

    old
  end

  def find(key : String) : Item?
    node = @trie

    key.chars.each do |char|
      node = node.trie[char]
      return nil unless node
    end

    node.item
  end

  def scan(chars : Array(Char), offset : Int32 = 0) : Items
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

  def save!(file : String = @file, sort : Bool = false)
    list = sort ? @list.sort_by { |x| {-x.key.size, x.key} } : @list

    File.open(file, "w") { |f| list.each { |i| f.puts i } }
    puts "- Save to [#{file.colorize(:yellow)}], items: #{@size.colorize(:yellow)}"
  end
end
