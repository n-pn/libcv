require "json"
require "colorize"

alias Counter = Hash(String, Int32)
count_books = Counter.new { |h, k| h[k] = 0 }
count_words = Counter.new { |h, k| h[k] = 0 }

files = Dir.glob(".temp/counted/*.json")
files.each_with_index do |file, idx|
  puts "- [#{idx + 1}/#{files.size}] [#{file}]".colorize(:yellow)

  hash = Counter.from_json File.read(file)
  hash.each do |key, val|
    count_books[key] += 1
    count_words[key] += val
  end
end

File.write ".init/counters/books.json", count_books.to_pretty_json
File.write ".init/counters/words.json", count_words.to_pretty_json
