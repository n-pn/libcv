require "json"

require "./chivi/*"

module Chivi
  extend self

  alias Dicts = Array(Dict)

  def cv_raw(dicts : Dicts, input : String)
    tokenize(dicts, input.chars).reverse
  end

  def cv_lit(dicts : Dicts, input : String, apply_cap = false)
    nodes = tokenize(dicts, input.chars)
    nodes = combine_similar(nodes)
    nodes = capitalize(nodes) if apply_cap
    add_spaces(nodes)
  end

  def cv_plain(dicts : Dicts, input : String)
    nodes = tokenize(dicts, input.chars)
    nodes = combine_similar(nodes)
    nodes = apply_grammar(nodes)
    nodes = capitalize(nodes)
    add_spaces(nodes)
  end

  TITLE_RE = /^(第([零〇一二两三四五六七八九十百千]+|\d+)([集卷章节幕回]))([,.:]*)(.*)$/

  def cv_title(dicts : Dicts, input : String)
    res = Nodes.new
    space = false

    input.split(" ") do |title|
      res << Node.new("", " ", 0) if space

      if match = TITLE_RE.match(title)
        _, group, index, label, trash, title = match

        res << Node.new(group, vi_title(index, label), 0)
        res << Node.new(trash, ":", 0) # unless trash.empty?
        res << Node.new("", " ", 0) unless title.empty?
      end

      res.concat(cv_plain(dicts, title)) unless title.empty?
      space = true
    end

    res
  end

  private def vi_title(index : String, label = "")
    int = Util.hanzi_int(index)

    case label
    when "章" then "Chương #{int}"
    when "卷" then "Quyển #{int}"
    when "集" then "Tập #{int}"
    when "节" then "Tiết #{int}"
    when "幕" then "Màn #{int}"
    when "回" then "Hồi #{int}"
    else          "Chương #{int}"
    end
  end

  private def tokenize(dicts : Dicts, input : Array(Char))
    selects = [Node.new("", "")]
    weights = [0.0]
    chars = Util.normalize(input)

    input.each_with_index do |char, idx|
      selects << Node.new(char, chars[idx])
      weights << idx + 1.0
    end

    csize = chars.size + 1
    dsize = dicts.size + 1

    chars.each_with_index do |char, idx|
      items = {} of Int32 => Dict::Item
      picks = {} of Int32 => Int32

      dicts.each_with_index do |dict, jdx|
        dict.scan(chars, idx).each do |item|
          items[item.key.size] = item
          picks[item.key.size] = jdx + 1
        end
      end

      pos_bonus = (csize - idx) / csize + 1

      picks.each do |size, pick|
        item = items[size]
        next if item.vals.empty?

        dic_bonus = pick / dsize

        item_weight = (size + dic_bonus ** pos_bonus) ** (1 + dic_bonus)
        gain_weight = weights[idx] + item_weight

        jdx = idx + size
        if gain_weight > weights[jdx]
          weights[jdx] = gain_weight
          selects[jdx] = Node.new(item.key, item.vals[0], pick)
        end
      end
    end

    idx = input.size
    res = Nodes.new

    while idx > 0
      node = selects[idx]
      res << node
      idx -= node.key.size
    end

    res
  end

  private def combine_similar(nodes : Nodes)
    res = Nodes.new
    idx = nodes.size - 1

    while idx >= 0
      acc = nodes[idx]
      jdx = idx - 1

      if acc.dic == 0
        while jdx >= 0
          cur = nodes[jdx]
          break if cur.dic > 0
          break unless similar?(acc, cur)

          acc.key += cur.key
          acc.val += cur.val
          jdx -= 1
        end
      end

      idx = jdx
      res << acc
    end

    res
  end

  private def similar?(acc : Node, cur : Node)
    return true if acc.key[0] == cur.key[0]
    return true if acc.key == acc.val && cur.key == cur.val

    letter?(cur) && letter?(acc)
  end

  private def letter?(node : Node)
    case node.key[0]
    when .alphanumeric?, ':', '/', '?', '-', '_', '%'
      # match letter or uri scheme
      true
    else
      # match normalizabled chars
      node.val[0].alphanumeric?
    end
  end

  def apply_grammar(nodes : Nodes)
    # TODO: handle more special rules, like:
    # - convert hanzi to number,
    # - convert hanzi percent
    # - date and time
    # - guess special words meaning..
    # - apply `的` grammar
    # - apply other grammar rule
    # - ...

    nodes.each do |node|
      if node.key == "的"
        node.val = ""
        node.dic = 0
      end
    end

    nodes
  end

  def capitalize(nodes : Nodes, cap_first : Bool = true)
    apply_cap = cap_first

    nodes.each do |node|
      next if node.val.empty?

      if apply_cap && node.val[0].alphanumeric?
        node.val = Util.capitalize(node.val)
        apply_cap = false
      else
        apply_cap ||= cap_after?(node.val)
      end
    end

    nodes
  end

  private def cap_after?(val : String)
    return false if val.empty?
    case val[-1]
    when '“', '‘', '⟨', '[', '{', '.', ':', '!', '?'
      return true
    else
      return false
    end
  end

  def add_spaces(nodes : Nodes)
    res = Nodes.new
    add_space = false

    nodes.each do |node|
      if node.val.empty?
        res << node
      else
        res << Node.new("", " ", 0) if add_space && space_before?(node.val[0])
        res << node
        add_space = node.dic > 0 || space_after?(node.val[-1])
      end
    end

    res
  end

  private def space_before?(char : Char)
    case char
    when '”', '’', '⟩', ')', ']', '}', ',', '.', ':', ';',
         '!', '?', '%', ' ', '_', '…', '/', '\\', '~'
      false
    else
      true
    end
  end

  private def space_after?(char : Char)
    case char
    when '“', '‘', '⟨', '(', '[', '{', ' ', '_', '/', '\\'
      false
    else
      true
    end
  end
end
