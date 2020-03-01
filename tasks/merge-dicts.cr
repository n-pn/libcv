require "./utils/hash_dict"

generic = HashDict.new ".temp/mergevp/generic.txt"
suggest = HashDict.new ".temp/mergevp/suggest.txt"
recycle = HashDict.new ".temp/mergevp/recycle.txt"

####################

generic.load! ".temp/localvp/generic.txt"

Dir.glob(".init/persist/generic/*.txt").each do |file|
  generic.load!(file)
end

EXISTED = Set.new File.read_lines(".temp/existed.txt")

HashDict.load!(".temp/extravp/generic.txt").data.each do |key, extra_val|
  if !EXISTED.includes?(key)
    generic.add(key, extra_val, mode: :keep_old)
  elsif local_val = generic.get(key)
    remains = extra_val.split("/") - local_val.split("/")
    suggest.add(key, remains.join("/")) unless remains.empty?
  end
end

####################

Dir.glob(".init/persist/suggest/*.txt").each do |file|
  suggest.load!(file)
end

suggest.load! ".temp/localvp/suggest.txt"

HashDict.load!(".temp/extravp/suggest.txt").data.each do |key, val|
  if generic_val = generic.get(key)
    remains = val.split("/") - generic_val.split("/")
    suggest.add(key, remains.join("/")) unless remains.empty?
  else
    suggest.add(key, val, mode: :old_first)
  end
end

####################

recycle.merge! ".temp/localvp/recycle.txt"
recycle.merge! ".temp/extravp/recycle.txt", mode: :keep_old

recycle.data.each_key do |key|
  recycle.del(key) if generic.includes?(key) || suggest.includes?(key)
end

####################

generic.save!
suggest.save!
recycle.save!
