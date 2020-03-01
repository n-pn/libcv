# SEP_0 = "‖"
# SEP_1 = "¦"
# SEP_2 = "|"

def cleanup(val)
  val.split("\\t")
    .map { |v| v.sub(/^\d+\.\s+/, "") }
    .reject(&.empty?)
    .join("‖")
    .sub("]‖", "] ")
    .sub("}‖", "} ")
end

input = File.read_lines(".init/lacviet.txt")
output = String::Builder.new

input.each do |line|
  line = line.strip
  next if line.empty?

  key, val = line.split "=", 2
  vals = val.split("\\n").map { |x| cleanup(x) }.join("/")

  output << "#{key}|#{vals}\n"
end

File.write "data/glossary/trungviet.dic", output.to_s
