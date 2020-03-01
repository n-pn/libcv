require "json"

require "./utils/hash_dict"

GENERIC = HashDict.load! ".temp/mergevp/generic.txt"
SUGGEST = HashDict.load! ".keep/suggest.txt"

COMBINE = HashDict.new(".keep/combine.txt")
COMBINE.load! ".temp/localvp/combine.txt"

files = Dir.glob(".temp/unique/selected/*.json")

files.each_with_index do |file, idx|
  name = File.basename(file, ".json")
  puts "- serial: [#{idx + 1}/#{files.size}] #{name.colorize(:blue)}"

  unique = HashDict.new(".keep/unique/#{name}.txt")
  counter = Hash(String, Int32).from_json File.read(file)

  counter = counter.reject do |key, val|
    val < 20 || GENERIC.includes?(key) || key =~ /^\w+$/
  end

  counter.to_a.sort_by { |item| -item[1] }.each do |item|
    key, val = item
    if val = SUGGEST.get(key)
      unique.add(key, val)
      COMBINE.add(key, val) if val.downcase != val
    end
  end
  unique.save!
end

COMBINE.save!
