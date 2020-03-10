require "./dict"
require "./util"

module Chivi::Core
  extend self

  alias Dicts = Array(Dict)
  alias Chars = Array(Char)
  alias Token = Tuple(String, String, Int32) # {key, val, dic}
  alias Tokens = Array(Token)

  def convert(dicts : Dicts, input : String, cap_first = true, ignore_de = true)
    tokens = tokenize(dicts, input)
    apply_grammar(tokens, cap_first, ignore_de)
  end

  def convert_title(dicts : Dicts, input : String)
    if match = Util.split_head(input)
      head_text, head_trash, zh_index, vi_index, tail_trash, tail_text = match

      output = Tokens.new

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

  def tokenize(dicts : Dicts, input : String)
    chars = Util.normalize(input)
    tokenize(dicts, chars)
  end

  def tokenize(dicts : Dicts, input : Chars) : Tokens
    selects = [{Dict::Item.new("", ""), 0}]
    weights = [0.0]

    input.each_with_index do |char, idx|
      selects << {Dict::Item.new(char.to_s, char.to_s), 0}
      weights << idx + 1.0
    end

    total = dicts.size + 1

    input.each_with_index do |char, idx|
      choices = {} of Int32 => Tuple(Dict::Item, Int32)

      dicts.each_with_index do |dict, jdx|
        dict.scan(input, idx).each do |item|
          choices[item.key.size] = {item, jdx + 1}
        end
      end

      choices.each do |size, token|
        next if token[0].val.empty?

        acc = token[1] / total
        jump = idx + size
        weight = weights[idx] + (size + acc) ** (1 + acc)

        if weight >= weights[jump]
          weights[jump] = weight
          selects[jump] = token
        end
      end
    end

    res = Tokens.new
    idx = selects.size - 1

    while idx > 0
      item, dic = selects[idx]

      val = item.val
      val = val.split("/").first unless val == "/"

      res << {item.key, val, dic}
      idx -= item.key.size
    end

    res
  end

  def apply_grammar(tokens : Tokens, cap_first = true, ignore_de = true) : Tokens
    res = Tokens.new

    should_apply_cap = cap_first
    should_add_space = false

    tokens = combine_similar(tokens)

    tokens.each do |token|
      key, val, dic = token
      if key == "的" && ignore_de
        res << {key, "", 0}
        next
      end

      res << {"", " ", 0} if should_add_space && space_before?(key)

      if val == ""
        pp token
      end

      if should_apply_cap && val[0].alphanumeric?
        cap = val[0].upcase + val[1..]
        token = {key, cap, dic}
        should_apply_cap = false
      end

      should_apply_cap ||= cap_after?(key)
      should_add_space = space_after?(key)

      res << token
    end

    res
  end

  private def combine_similar(tokens : Tokens) : Tokens
    res = Tokens.new
    idx = tokens.size - 1

    while idx >= 0
      token = tokens[idx]

      if token[2] > 0
        res << token
        idx -= 1
        next
      end

      key = token[0]
      val = token[1]

      jdx = idx - 1

      while jdx >= 0
        token = tokens[jdx]
        break unless similar?(token[0][0], key[0])

        key += token[0]
        val += token[1]
        jdx -= 1
      end

      res << {key, val, 0}
      idx = jdx
    end

    res
  end

  private def similar?(a : Char, b : Char) : Bool
    return true if a == b
    a.alphanumeric? && b.alphanumeric?
  end

  private def space_before?(key : String)
    case key[0]
    when '”', '’', '⟩', ')', ']',
         '}', ',', '.', ':', ';',
         '!', '?', '%', ' ', '_',
         '…', '/', '\\'
      return false
    else
      return true
    end
  end

  private def space_after?(key : String)
    case key[-1]
    when '“', '‘', '⟨', '(', '[', '{', ' ', '_', '/', '\\'
      return false
    else
      return true
    end
  end

  private def cap_after?(key : String)
    case key[-1]
    when '“', '‘', '⟨', '[', ']', '{', '.', ':', '!', '?'
      return true
    else
      return false
    end
  end
end
