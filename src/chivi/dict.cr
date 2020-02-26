require "colorize"
require "benchmark"

class Chivi::Dict
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

  class Node
    property item : Item?
    property trie : Hash(Char, Node)

    def initialize(@item : Item? = nil, @trie = Hash(Char, Node).new)
    end
  end

  getter items : Array(Item)
  getter size : Int32

  def initialize(@file : String, load = true)
    @items = [] of Item
    @size = 0

    @trie = Node.new
    load! if File.exists?(@file) && load
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
      @items << item
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

  def scan(chars : Array(Char), offset : Int32 = 0) : Array(Item)
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
    items = sort ? @items.sort_by { |x| {-x.key.size, x.key} } : @items

    File.open(file, "w") { |f| items.each { |i| f.puts i } }
    puts "- Save to [#{file.colorize(:yellow)}], items: #{@size.colorize(:yellow)}"
  end
end
