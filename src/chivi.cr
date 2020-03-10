require "./chivi/*"

module Chivi
  extend self

  @@standard = Repo.new(".dic")
  @@translit = Repo.new(".dic/translit")
  @@glossary = Repo.new(".dic/glossary")
  @@specific = Repo.new(".dic/specific")

  def hanviet(input : String, cap_first = false)
    translate(@@translit["hanviet"], input, cap_first, ignore_de: false)
  end

  def combine(input : String, mode : Symbol = :mixed)
    dicts = @@standard["generic"]
    dicts.concat @@standard["combine"]

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
