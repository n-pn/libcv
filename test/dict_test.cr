require "../src/chivi"

test = Chivi::Dict.new "test/test.txt"

print "\nset abc to abc: ", test.set("abc", "abc")

print "\nput a to a: ", test.put Chivi::Dict::Item.new("a", "a")
print "\nput b to b: ", test.put Chivi::Dict::Item.new("b", "b")

print "\nset a to c: ", test.set("a", "c")

print "\nfind abc: ", test.find("abc")
print "\nfind ab: ", test.find("ab")

print "\nscan abc: ", test.scan("abc".chars).map(&.to_s).join(" ")
print "\nscan ab: ", test.scan("ab".chars).map(&.to_s).join(" ")

print "\ndel b: ", test.del "b"

puts "\n size: #{test.size}"

puts test.items.join("\n")

test.save! sort: true
