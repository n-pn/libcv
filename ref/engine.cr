require "./engine/*"

module Engine
  extend self

  @@common = Repo.new("db/dicts")
  @@system = Repo.new("db/dicts/system")
  @@unique = Repo.new("db/dicts/unique")

  def hanviet(input : String, cap_first = false)
    translate(@@system["hanviet"], input, cap_first)
  end

  def combine(input : String, mode : Symbol = :mixed)
    dicts = @@common["generic"]
    dicts.concat @@common["combine"]

    convert(dicts, input, mode).map { |line| line.map(&.[1]).join }.join("\n")
  end

  def translate(dicts : Array(Dict), input : String, cap_first = true, ignore_de = true)
    Core.convert(dicts, input, cap_first: cap_first, ignore_de: ignore_de)
      .map(&.[1]).join
  end

  def convert(dicts : Array(Dict), input : String, mode : Symbol = :mixed)
    convert(dicts, Util.split_lines(input), mode)
  end

  def convert(dicts : Array(Dict), lines : Array(String), mode : Symbol = :mixed)
    case mode
    when :title
      lines.map { |line| Core.convert_title(dicts, line) }
    when :plain
      lines.map { |line| Core.convert_title(dicts, line) }
    else # :mixed
      output = [Core.convert_title(dicts, lines.first)]
      lines[1..].each { |line| output << Core.convert(dicts, line) }
      output
    end
  end
end
