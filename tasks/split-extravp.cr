require "json"
require "./utils/hash_dict"

ONDICTS = Set(String).new File.read_lines(".temp/ondicts.txt")

def generic?(key, book_count, word_count)
  # return true if key.size == 1 && key =~ /\p{Han}/ # for hanviet
  return book_count >= 100 if ONDICTS.includes?(key)
  book_count >= 500 && word_count >= 1000
end

def suggest?(key, book_count, word_count)
  return true if word_count >= 500
  ONDICTS.includes?(key) && word_count >= 50
end

alias Counter = Hash(String, Int32)

COUNT_WORDS = Counter.from_json File.read(".init/count_words.json")
COUNT_BOOKS = Counter.from_json File.read(".init/count_books.json")

generic = HashDict.new(".temp/extravp/generic.txt")
suggest = HashDict.new(".temp/extravp/suggest.txt")
recycle = HashDict.new(".temp/extravp/recycle.txt")

Dir.glob(".init/extravp/*.txt").each do |file|
  File.read_lines(file).each do |line|
    key, val = line.split("=", 2)

    book_count = COUNT_BOOKS[key]? || 0
    word_count = COUNT_WORDS[key]? || 0

    if generic?(key, book_count, word_count)
      generic.add(key, val)
    elsif suggest?(key, book_count, word_count)
      suggest.add(key, val)
    elsif word_count >= 100
      recycle.add(key, val)
    end
  end
end

generic.save!
suggest.save!
recycle.save!
