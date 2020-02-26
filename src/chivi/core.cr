require "./dict"

module Chivi::Core
  extend self

  alias Token = Tuple(String, String, Int32) # {key, val, dic}
  alias TokenList = Array(Token)

  def tokenize(dicts : Array(Dict), input : Array(Char)) : TokenList
    selects = [{"", "", 0}]
    weights = [0.0]

    input.each_with_index do |char, idx|
      selects << {char.to_s, char.to_s, 0}
      weights << idx + 1.0
    end

    total = dicts.size + 1

    input.each_with_index do |char, idx|
      choices = {} of Int32 => Token

      dicts.each_with_index do |dict, jdx|
        dict.scan(input, idx).each do |item|
          choices[item.key.size] = {item.key, item.val, jdx + 1}
        end
      end

      choices.each do |size, token|
        next if token[1].empty?

        acc = token[2] / total
        jump = idx + size
        weight = weights[idx] + (size + acc) ** (1 + acc)

        if weight >= weights[jump]
          weights[jump] = weight
          selects[jump] = token
        end
      end
    end

    res = TokenList.new
    idx = selects.size - 1

    while idx > 0
      cur = selects[idx]
      res << {cur[0], cur[1].split("/").first, cur[2]} # remove multi values
      idx -= cur[0].size
    end

    res
  end

  def apply_grammar(tokens : TokenList, cap_first = true, ignore_de = true) : TokenList
    res = TokenList.new

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

  private def combine_similar(tokens : TokenList) : TokenList
    res = TokenList.new
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
         '!', '?', '%', ' ', '…'
      return false
    else
      return true
    end
  end

  private def space_after?(key : String)
    case key[-1]
    when '“', '‘', '⟨', '(', '[', '{', ' '
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
