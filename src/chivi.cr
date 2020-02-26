require "./chivi/*"

module Chivi
  extend self
  VERSION = "0.2.0"

  alias DictList = Array(Dict)

  def translate(dicts : DictList, input : String, generic = false)
    tokens = convert(dicts, input, cap_first: generic, ignore_de: generic)
    render_tokens(tokens)
  end

  def render_tokens(tokens : Array(Core::Token))
    tokens.map(&.[1]).join
  end

  def convert(dicts : DictList, input : String, cap_first = true, ignore_de = true)
    tokens = tokenize(dicts, input)
    Core.apply_grammar(tokens, cap_first, ignore_de)
  end

  def convert_title(dicts : DictList, input : String)
    if match = Util.split_head(input)
      head_text, head_trash, zh_index, vi_index, tail_trash, tail_text = match

      output = Core::TokenList.new

      if !head_text.empty?
        output.concat convert(dicts, head_text)
        output << {head_trash, " - ", 0}
      elsif !head_trash.empty?
        output << {head_trash, "", 0}
      end

      output << {zh_index, vi_index, 0}

      if !tail_text.empty?
        output << {tail_trash, ": ", 0}
        output.concat convert_title(dicts, tail_text) # incase volume title is mixed with chapter title
      elsif !tail_trash.empty?
        output << {tail_trash, "", 0}
      end

      output
    else
      convert(dicts, input)
    end
  end

  def tokenize(dicts : DictList, input : String)
    chars = Util.normalize(input)
    Core.tokenize(dicts, chars)
  end
end
