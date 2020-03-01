require "../../webcv/engine"
require "colorize"

require "./utils/hash_dict"

def read_file(file : String)
  inp = [] of Tuple(String, String)
  File.read_lines(file).each do |line|
    key, val = line.split("=", 2)
    inp << {key, val}
  end

  puts "- loaded [#{file.colorize(:blue)}], entries: #{inp.size.colorize(:blue)}"

  inp.sort_by { |x| {x[0].size, x[0]} }
end

Dir.glob(".keep/*.txt").map { |x| File.delete(x) }

HANVIET = [Chivi::Dict.load!(".keep/system/hanviet.txt")]
ONDICTS = HashDict.load!(".temp/ondicts.txt")
CHECKED = HashDict.load!(".temp/checked.txt")

def translate(dicts, input)
  Chivi.translate(dicts, input, generic: false)
end

GENERIC_ADD = Chivi::Dict.new(".keep/generic.txt")

def shoud_keep?(key, val)
  return true if ONDICTS.includes?(key) || CHECKED.includes?(key)

  val = val.split("/", 2).first
  return true if translate(HANVIET, key).downcase == val.downcase
  return false if translate([GENERIC_ADD], key) == val

  true
end

####################################
puts "\n[Cleanup generic.txt]".colorize(:cyan)

GENERIC_REM = HashDict.new(".keep/removed/generic.convertable.txt")

read_file(".temp/mergevp/generic.txt").each do |key, val|
  if shoud_keep?(key, val)
    GENERIC_ADD.put(Chivi::Dict::Item.new(key, val))
  else
    GENERIC_REM.add(key, val)
  end
end

GENERIC_ADD.save!(sort: true)
GENERIC_REM.save!

####################################
puts "\n[Cleanup suggest.txt]".colorize(:cyan)

SUGGEST_ADD = Chivi::Dict.new(".keep/suggest.txt", load: false)
SUGGEST_REM = HashDict.new(".keep/removed/suggest.convertable.txt")

read_file(".temp/mergevp/suggest.txt").each do |key, val|
  if shoud_keep?(key, val)
    SUGGEST_ADD.put(Chivi::Dict::Item.new(key, val))
  else
    SUGGEST_REM.add(key, val)
  end
end

SUGGEST_ADD.save!(sort: true)
SUGGEST_REM.save!

####################################
puts "\n[Cleanup recycle.txt]".colorize(:cyan)

RECYCLE_ADD = Chivi::Dict.new(".keep/recycle.txt", load: false)
RECYCLE_REM = HashDict.new(".keep/removed/recycle.convertable.txt")

read_file(".temp/mergevp/recycle.txt").each do |key, val|
  if shoud_keep?(key, val)
    RECYCLE_ADD.put(Chivi::Dict::Item.new(key, val))
  else
    RECYCLE_REM.add(key, val)
  end
end

RECYCLE_ADD.save!(sort: true)
RECYCLE_REM.save!
