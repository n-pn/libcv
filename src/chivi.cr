require "./chivi/*"

module Chivi
  extend self

  VERSION = "0.1.0"

  DICTS = {} of String => Dict

  def load_dict(file)
    DICTS[file] ||= Dict.new(file)
  end

  def convert(dicts : Array(Dict), input : String, mode : Symbol = :chap)
    convert(dicts, Util.split_lines(input), mode)
  end

  def convert(dicts : Array(Dict), lines : Array(String), mode : Symbol = :chap)
    case mode
    when :head
      lines.map { |line| convert_head(dicts, line) }
    when :para
      lines.map { |line| convert_para(dicts, line) }
    else # :chap
      output = [convert_head(dicts, lines.first)]
      lines[1..].each { |line| output << convert_para(dicts, line) }
      output
    end
  end

  def convert_head(dicts : Array(Dict), input : String)
    if match = Util.split_head(input)
      head_text, head_trash, zh_index, vi_index, tail_trash, tail_text = match

      output = Core::TokenList.new

      if !head_text.empty?
        output.concat convert_para(dicts, head_text)
        output << {head_trash, " - ", 0}
      elsif !head_trash.empty?
        output << {head_trash, "", 0}
      end

      output << {zh_index, vi_index, 0}

      if !tail_text.empty?
        output << {tail_trash, ": ", 0}
        output.concat convert_head(dicts, tail_text) # incase volume title is mixed with chapter title
      elsif !tail_trash.empty?
        output << {tail_trash, "", 0}
      end

      output
    else
      convert_para(dicts, input)
    end
  end

  def convert_para(dicts : Array(Dict), input : String)
    chars = Util.normalize(input)
    convert_para(dicts, chars)
  end

  def convert_para(dicts : Array(Dict), chars : Array(Char))
    tokens = Core.tokenize(dicts, chars)
    Core.apply_grammar(tokens)
  end

  def translate(dicts : Array(Dict), input : String, cap = true)
    chars = Util.normalize(input)
    tokens = Core.tokenize(dicts, chars)
    Core.apply_grammar(tokens, cap).map(&.[1]).join
  end

  def tokenize(dicts : Array(Dict), input : String)
    # normally tokenize process return tokens in incorrect order to avoid
    # array allocation
    Core.tokenize(dicts, Util.normalize(input)).reverse
  end
end
