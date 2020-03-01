require "json"

require "./utils/normalize"
require "./utils/hash_dict"

alias Counter = Hash(String, Int32)

COUNT_WORDS = Counter.from_json File.read(".init/count_words.json")
COUNT_BOOKS = Counter.from_json File.read(".init/count_books.json")

def split_val(val : String)
  val.split(/[\/|]/)
    .map(&.strip)
    .reject(&.empty?)
    .reject(&.includes?(":"))
end

CHECKED = Set(String).new
EXISTED = Set(String).new

Dir.glob(".init/localvp/history/*.log") do |file|
  next if file.includes?("hanviet")

  puts "- load file: [#{file.colorize(:blue)}]"

  File.read_lines(file)[1..].each do |line|
    key = line.split("\t", 2).first
    CHECKED.add key.not_nil! # to keep in output
    EXISTED.add key.not_nil! # to reject extravp
  end
end

ONDICTS = Set(String).new File.read_lines(".temp/ondicts.txt")
REJECTS = ["的", "了", "是", ",", ".", "!"]

def should_skip?(key : String)
  return false if ONDICTS.includes?(key)
  return true if key !~ /\p{Han}/
  return true if key =~ /^第?.+[章节幕回集卷]$/

  REJECTS.each do |char|
    return true if key.starts_with?(char) || key.ends_with?(char)
  end

  false
end

alias Dict = Hash(String, Set(String))

INPUT = Dict.new { |h, k| h[k] = Set(String).new }
# WORDS = Dict.new { |h, k| h[k] = Set(String).new }

Dir.glob(".init/localvp/*.txt") do |file|
  next if file.includes?("hanviet")

  puts "- load file: [#{file.colorize(:cyan)}]"

  File.read_lines(file).each do |line|
    rows = line.split "=", 2
    next if rows.size != 2

    key, val = rows
    key = normalize(key)
    EXISTED.add(key)
    next if should_skip?(key)

    vals = split_val(val)
    INPUT[key].concat(vals) unless vals.empty?
  end
end

# replace localvp with manually checked
Dir.glob(".init/localvp/replace/*.txt") do |file|
  puts "- load file: [#{file.colorize(:blue)}]"

  File.read_lines(file).each do |line|
    rows = line.split "=", 2
    next if rows.size != 2

    key, val = rows
    CHECKED.add(key)
    EXISTED.add(key)

    INPUT[key].clear.concat split_val(val)
  end
end

generic = HashDict.new(".temp/localvp/generic.txt")
suggest = HashDict.new(".temp/localvp/suggest.txt")
recycle = HashDict.new(".temp/localvp/recycle.txt")
combine = HashDict.new(".temp/localvp/combine.txt")

def generic?(key, book_count, word_count)
  return true if key.size == 1 && key =~ /\p{Han}/ # for hanviet
  return book_count >= 5 if CHECKED.includes?(key)
  return word_count >= 5 if ONDICTS.includes?(key)
  word_count >= 200 && book_count >= 50
end

def suggest?(key, book_count, word_count)
  word_count >= 10 || ONDICTS.includes?(key) || CHECKED.includes?(key)
end

INPUT.each do |key, vals|
  book_count = COUNT_BOOKS[key]? || 0
  word_count = COUNT_WORDS[key]? || 0

  names, words = vals.partition { |x| x != x.downcase }

  if names.size > 0
    names = names.first(3).join('/')

    if generic?(key, book_count, word_count)
      generic.add(key, names)
    elsif suggest?(key, book_count, word_count) || key !~ /[^\p{Han}]/
      suggest.add(key, names)
    else
      recycle.add(key, names)
    end

    if CHECKED.includes?(key)
      next if key =~ /[^\p{Han}]/
      combine.add(key, names) unless generic.includes?(key)
    end
  end

  if words.size > 0
    words = words.first(3).join('/')

    if generic?(key, book_count, word_count) || CHECKED.includes?(key)
      generic.add(key, words)
    elsif suggest?(key, book_count, word_count)
      suggest.add(key, words)
    else
      recycle.add(key, words)
    end
  end
end

# load hanviet
File.read_lines(".keep/system/hanviet.txt").each do |line|
  rows = line.split "=", 2
  next if rows.size != 2

  key, val = rows
  EXISTED.add(key)
  generic.add(key, val) unless generic.includes?(key)
end

File.read_lines(".init/hanviet/trichdan-words.txt").each do |line|
  rows = line.split "=", 2
  next if rows.size != 2

  key, val = rows
  EXISTED.add(key)
  generic.add(key, val) unless generic.includes?(key)
end

# save results

File.write(".temp/existed.txt", EXISTED.to_a.join("\n"))
File.write(".temp/checked.txt", CHECKED.to_a.join("\n"))

generic.save!
suggest.save!
recycle.save!
combine.save!
