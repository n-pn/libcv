require "./utils/hash_dict"

puts "\n[Load inputs]".colorize(:cyan)

HISTORY = ".init/hanviet/localqt.log"
CHECKED = Set.new(File.read_lines(HISTORY)[1..].map(&.split("\t", 2)[0]))

HANVIET = HashDict.load!(".init/hanviet/localqt.txt")

extra_files = {
  ".init/hanviet/trichdan-chars.txt",
  ".init/hanviet/checked-chars.txt",
  ".init/hanviet/checked-words.txt",
}

extra_files.each do |file|
  HashDict.load!(file).data.each do |key, val|
    HANVIET.set(key, val) unless CHECKED.includes?(key)
  end
end

puts "\n[Split trad/simp]".colorize(:cyan)

TRADSIM = HashDict.load!(".keep/system/tradsim.txt")

SPECIAL = {"連", "嬑", "釵", "匂", "宮", "夢", "滿", "闇", "詞", "遊", "東"}

def is_simp?(input : String)
  return true if SPECIAL.includes?(input)
  !input.split("").find { |char| TRADSIM.includes?(char) }
end

out_hanviet = HashDict.new(".keep/system/hanviet.txt")
out_hantrad = HashDict.new(".temp/hantrad.txt")

HANVIET.data.each do |key, val|
  if is_simp?(key)
    out_hanviet.set(key, val)
  else
    out_hantrad.set(key, val)
  end
end

converted = 0
# if trad hanzi existed, but not for simp evaquilent
out_hantrad.data.each do |trad, val|
  if simp = TRADSIM.get(trad)
    next if out_hanviet.includes?(simp)
    out_hanviet.add(simp, val)
    out_hantrad.del(trad)
    converted += 1
  end
end

puts "- hanviet: #{out_hanviet.size.colorize(:yellow)}, hantrad: #{out_hantrad.size.colorize(:yellow)}, trad-to-simp: #{converted.colorize(:yellow)}"

puts "\n[Check missing hanviet]".colorize(:cyan)

missing = [] of String

ce_dict_count = 0
hanzidb_count = 0

TRADSIM.data.each_value do |val|
  next unless val.size == 1
  next if out_hanviet.includes?(val)
  missing << val
  ce_dict_count += 1
end

HANZIDB = HashDict.load!(".init/hanzidb.txt")
HANZIDB.data.each_key do |key|
  next if out_hanviet.includes?(key)
  missing << key
  hanzidb_count += 1
end

puts "- MISSING ce_dict: #{ce_dict_count.colorize(:yellow)}, hanzidb: #{hanzidb_count.colorize(:yellow)}, total: #{missing.size.colorize(:yellow)}"

puts "\n[Fill missing hanviet from vietphrase]".colorize(:cyan)

dict_files = {
  ".init/localvp/vietphrase.txt",
  ".init/localvp/names1.txt",
  ".init/localvp/names2.txt",

  ".init/extravp/words.txt",
  ".init/extravp/names.txt",
}
recovered = 0

dict_files.each do |file|
  HashDict.load!(file).data.each do |key, val|
    next if key.size > 1 || !missing.includes?(key)
    out_hanviet.add(key, val)
    missing.delete(key)
    recovered += 1
  end
end

puts "- recovered: #{recovered.colorize(:yellow)}, still missing: #{missing.size.colorize(:yellow)}"

puts "\n[Guess hanviet from pinyins]".colorize(:cyan)

pinyins = Hash(String, Array(String)).new { |h, k| h[k] = Array(String).new }

# TODO: replace key with hanviet[key]?

PINYINS = HashDict.load!(".keep/system/pinyins.txt")
PINYINS.data.each do |key, val|
  val.split("/").each { |v| pinyins[v] << key }
end

puts "- pinyinis count: #{pinyins.size.colorize(:blue)}"

missing.each do |key|
  if vals = PINYINS.get(key)
    val = vals.split("/", 2).first

    choices =
      pinyins[val]
        .map { |x| out_hanviet.get(x) }.reject(&.nil?)
        .map { |x| x.as(String).split("/") }.flatten

    next if choices.empty?

    hanviet =
      choices.tally.to_a
        .sort_by { |x, y| -y }.first(3)
        .map { |x, y| x }
        .join("/")

    out_hanviet.add(key, hanviet)
    missing.delete(key)
  else
    puts key
  end
end

puts "- still missing #{missing.size.colorize(:yellow)} chars."

puts "\nWrite results".colorize(:cyan)

out_hanviet.save!(keep: 4)
out_hantrad.save!(keep: 4)

out_file = ".temp/hanmiss.txt"
File.write out_file, missing.map { |x| "#{x}=[#{PINYINS.get(x)}]" }.join("\n")
puts "- saving [#{out_file.colorize(:green)}]... done, entries: #{missing.size.colorize(:green)}"
