require "json"
require "colorize"

class Analyze
  getter counter : Array(Int32)

  class Node
    @idx : Int32 = -1
    @trie = Hash(Char, Node).new
    property idx : Int32
    getter trie : Hash(Char, Node)
  end

  def initialize
    @entries = File.read_lines(".init/existed.txt")
    @counter = Array(Int32).new(@entries.size, 0)
    @trie = Node.new

    @entries.each_with_index do |key, idx|
      node = key.chars.reduce(@trie) do |node, char|
        node.trie[char] ||= Node.new
      end

      node.idx = idx
    end
  end

  def add(input : String)
    chars = input.chars
    0.upto(chars.size - 1) { |i| count(chars, i) }
  end

  def count(chars : Array(Char), offset = 0)
    node = @trie

    while offset < chars.size
      char = chars[offset]
      node = node.trie[char]?
      return unless node
      @counter[node.idx] += 1 if node.idx >= 0
      offset += 1
    end
  end

  def report(min = 1)
    res = Hash(String, Int32).new

    @counter.each_with_index do |count, idx|
      next if count < min
      if entry = @entries[idx]?
        res[entry] = count
      end
    end

    res
  end

  def reset!
    @counter.fill(0)
  end
end

analyzer = Analyze.new

books = Dir.children(".book/chtexts")
books.each_with_index do |book, idx|
  puts "-- [#{idx + 1}/#{books.size}] {#{book}}".colorize(:blue)

  out_file = ".temp/unique/selected/#{book}.json"
  next if File.exists?(out_file)

  files = Dir[".book/chtexts/#{book}/*.txt"]

  files.each do |file|
    File.read_lines(file).each { |line| analyzer.add(line) }
  end

  output = analyzer.report(1)
  File.write out_file, output.to_pretty_json
  analyzer.reset!
end
