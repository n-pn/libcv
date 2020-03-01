require "../src/chivi/util"

require "./util/clavis"
require "./util/pinyin"

require "http/client"
require "zip"

require "json"
require "time"

def file_too_old(file : String)
  return true unless File.exists?(file)
  mtime = File.info(file).modification_time
  Time.local - mtime > 1.days
end

def read_zip(zip_file : String = ".init/cedict.zip") : String
  print "- fetching latest CC_CEDICT file from internet... ".colorize(:blue)

  if file_too_old(zip_file)
    url = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    HTTP::Client.get(url) { |res| File.write zip_file, res.body_io }
  end

  Zip::File.open(zip_file) do |zip|
    zip["cedict_ts.u8"].open do |io|
      puts "done.\n"
      return io.gets_to_end
    end
  end
end

def repeat_itself?(defn : String, simp : String) : Bool
  return true if defn =~ /variant of #{simp}/
  return true if defn =~ /also written #{simp}/
  return true if defn =~ /see #{simp}/

  false
end

def cleanup_defn(defn, simp) : String
  defn.gsub(/\p{Han}+\|/, "") # remove trad
    .gsub(/(?<=\[)(.*?)(?=\])/) { |p| pinyinfmt(p) }
    .split("/")
    .reject { |m| repeat_itself?(m, simp) }
    .join("; ")
end

def load_input(inp_file : String = ".init/cedict.txt")
  print "- Load input from #{inp_file.colorize(:yellow)}"

  if !file_too_old(inp_file)
    output = File.read_lines(inp_file).map(&.split("|"))
  else
    input = read_zip(".init/cedict.zip")

    print " parsing...".colorize(:blue)
    output = [] of Array(String)

    line_re = /^(.+?) (.+?) \[(.+?)\] \/(.+)\/$/

    input.split("\n").each do |line|
      entry = line.strip
      next if entry.empty? || entry[0] == '#'

      _, trad, simp, pinyin, defn = entry.match(line_re).not_nil!

      lookup = cleanup_defn(defn, simp)
      next if lookup.empty?

      trad = Chivi::Util.normalize(trad).join
      simp = Chivi::Util.normalize(simp).join
      pinyin = pinyinfmt(pinyin)

      output << [trad, simp, pinyin, lookup]
    end

    File.write inp_file, output.map(&.join("|")).join("\n")
  end

  puts " done. Entries: [#{output.size}]"
  output
end

def is_trad?(input : String)
  input.includes?("old variant of") || input.includes?("archaic variant of")
end

def export_cedict(input)
  puts "\n[Export cc_cedict]".colorize(:cyan)

  output = Clavis.new("data/glossary/cc_cedict.dic")

  input.each do |rec|
    _trad, simp, pinyin, lookup = rec
    output.add(simp, "[#{pinyin}] #{lookup}")
  end

  output.save!
end

alias Counter = Hash(String, Int32)

def export_pinyins(input, hanzidb)
  puts "\n[Export pinyins]".colorize(:cyan)

  counter = Hash(String, Counter).new { |h, k| h[k] = Counter.new(0) }

  input.each do |rec|
    _trad, simp, pinyin, lookup = rec
    next if is_trad?(lookup)

    chars = simp.split("")
    pinyins = pinyin.split(" ")
    next if chars.size != pinyins.size

    chars.each_with_index do |char, i|
      next if char[0].ascii?
      pinyin = pinyins[i]
      counter[char][pinyin] += 1
    end
  end

  output = Clavis.new("data/translit/binh_am.dic")
  output.load!(".init/pinyin.txt")

  counter.each do |char, count|
    best = count.to_a.sort_by { |pinyin, value| -value }.first(3).map(&.first)
    output.set(char, best.join('/'))
  end

  output.merge! hanzidb, mode: :keep_old
  output.save! sort: true
end

def export_tradsim(input, hanzidb)
  puts "\n[Export tradsim]".colorize(:cyan)

  tswords = Clavis.new(".temp/tswords.txt")
  counter = Hash(String, Counter).new { |h, k| h[k] = Counter.new(0) }

  input.each do |rec|
    trad, simp, _pinyin, lookup = rec
    next if is_trad?(lookup)
    tswords.add(trad, simp) if trad.size > 1

    simps = simp.split("")
    trads = trad.split("")

    trads.each_with_index do |trad, i|
      simp = simps[i]
      counter[trad][simp] += 1
    end
  end

  output = Clavis.new("data/translit/tradsim.dic")

  counter.each do |trad, counts|
    if counts.size == 1
      output.set(trad, counts.keys.first) if trad != counts.keys.first
      next
    end

    next if hanzidb.includes?(trad)

    best = counts.to_a.sort_by { |simp, count| -count }.map(&.first)
    output.set(trad, best.first)
  end

  puts "- single traditional char count: #{output.size.colorize(:yellow)}"

  output.set("扶馀", "扶余") # combine exception

  tswords.data.each do |trad, simp|
    next if simp.includes?('/') || simp == output.translate(trad)
    output.set(trad, simp)
  end

  tswords.save!
  output.save! sort: true
end

def extract_ondicts(cedict, tradsim)
  puts "\n[Export ondicts]".colorize(:cyan)
  ondicts = Set(String).new

  ondicts.concat cedict.keys.reject { |x| tradsim.includes?(x) }
  ondicts.concat Clavis.load!(".init/lacviet.txt").keys
  ondicts.concat Clavis.load!(".init/hanviet/checked/words.txt").keys
  ondicts.concat Clavis.load!(".init/hanviet/trichdan/words.txt").keys

  out_file = ".temp/ondicts.txt"
  File.write out_file, ondicts.to_a.join("\n")
  puts "- saving [#{out_file.colorize(:green)}]... done, entries: #{ondicts.size.colorize(:green)}"
end

EXCEPT = {"連", "嬑", "釵", "匂", "宮", "夢", "滿", "闇", "詞", "遊", "東"}

def is_simp?(tradsimp, input : String)
  return true if EXCEPT.includes?(input)
  !input.split("").find { |char| tradsimp.includes?(char) }
end

def export_hanviet(tradsimp, pinyins, hanzidb)
  puts "\n[Export hanviet]".colorize(:cyan)

  history_file = ".init/hanviet/localqt.log"
  history = Set.new(File.read_lines(history_file)[1..].map(&.split("\t", 2)[0]))

  localqt = Clavis.load!(".init/hanviet/localqt.txt")

  extra_files = {
    ".init/hanviet/trichdan/chars.txt",
    ".init/hanviet/checked/chars.txt",
    ".init/hanviet/checked/words.txt",
  }

  extra_files.each do |file|
    Clavis.load!(file).data.each do |key, val|
      localqt.set(key, val) unless history.includes?(key)
    end
  end

  puts "\n- Split trad/simp".colorize(:blue)

  out_hanviet = Clavis.new("data/translit/hanviet.dic")
  out_hantrad = Clavis.new(".temp/hantrad.txt")

  localqt.data.each do |key, val|
    if is_simp?(tradsimp, key)
      out_hanviet.set(key, val)
    else
      out_hantrad.set(key, val)
    end
  end

  converted = 0
  # if trad hanzi existed, but not for simp evaquilent
  out_hantrad.data.each do |trad, val|
    if simp = tradsimp.get(trad)
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

  tradsimp.data.each_value do |val|
    next unless val.size == 1
    next if out_hanviet.includes?(val)
    missing << val
    ce_dict_count += 1
  end

  hanzidb.data.each_key do |key|
    next if out_hanviet.includes?(key)
    missing << key
    hanzidb_count += 1
  end

  puts "- MISSING ce_dict: #{ce_dict_count.colorize(:yellow)}, hanzidb: #{hanzidb_count.colorize(:yellow)}, total: #{missing.size.colorize(:yellow)}"

  puts "\n- Fill missing hanviet from vietphrase".colorize(:blue)

  dict_files = {
    ".init/localqt/vietphrase.txt",
    ".init/localqt/names1.txt",
    ".init/localqt/names2.txt",

    ".init/extraqt/words.txt",
    ".init/extraqt/names.txt",
  }
  recovered = 0

  dict_files.each do |file|
    Clavis.load!(file).data.each do |key, val|
      next if key.size > 1 || !missing.includes?(key)
      out_hanviet.add(key, val)
      missing.delete(key)
      recovered += 1
    end
  end

  puts "- recovered: #{recovered.colorize(:yellow)}, still missing: #{missing.size.colorize(:yellow)}"

  puts "\n- Guess hanviet from pinyins".colorize(:blue)

  pinmap = Hash(String, Array(String)).new { |h, k| h[k] = Array(String).new }

  # TODO: replace key with hanviet[key]?

  pinyins.data.each do |key, val|
    val.split("/").each { |v| pinmap[v] << key }
  end

  puts "- pinyinis count: #{pinmap.size.colorize(:blue)}"

  missing.each do |key|
    if vals = pinyins.get(key)
      val = vals.split("/", 2).first

      choices =
        pinmap[val]
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
      puts "NO PINYIN: #{key}"
    end
  end

  puts "- still missing #{missing.size.colorize(:yellow)} chars."

  puts "- write results".colorize(:blue)

  out_hanviet.save!(keep: 4, sort: true)
  out_hantrad.save!(keep: 4, sort: true)

  out_file = ".temp/hanmiss.txt"
  File.write out_file, missing.map { |x| "#{x}=[#{pinyins.get(x)}]" }.join("\n")
  puts "- saving [#{out_file.colorize(:green)}]... done, entries: #{missing.size.colorize(:green)}"
end

input = load_input(".init/cedict.txt")
hanzidb = Clavis.load!(".init/hanzidb.txt")

cedict = export_cedict(input)
pinyins = export_pinyins(input, hanzidb)
tradsim = export_tradsim(input, hanzidb)
export_hanviet(tradsim, pinyins, hanzidb)

extract_ondicts(cedict, tradsim)
