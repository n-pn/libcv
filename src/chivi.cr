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

  HAN_NUM    = "零〇一二两三四五六七八九十百千"
  TITLE_RE_0 = /^(第?(\p{Nd}+|\d+)([集卷]))([,.:]*)(.*)$/
  TITLE_RE_1 = /^(第【?([\d\p{Nd}]+)】?([章节幕回]))([,.:]*)(.*)$/
  TITLE_RE_2 = /^(第?【?([\p{Nd}]+|\d+)】?([章节幕回]))([,.:]*)(.*)$/
  TITLE_RE_3 = /^(\p{Nd}+|\d+)([,.:]*)(.*)$/

  def cv_title(dicts : Dicts, input : String)
    res = Nodes.new

    frags = input.split(/\p{Z}/)

    if match = TITLE_RE_0.match(input)
      _, zh_group, index, label, trash, title = match
      vi_group = "#{vi_label(label)} #{Util.hanzi_int(index)}"

      res << Node.new(zh_group, vi_group, 0)

      if title.empty?
        res << Node.new(trash, "", 0) unless trash.empty?
      else
        res << Node.new(trash, ": ", 0) # unless trash.empty?
      end

      input = title
    end

    if match = (TITLE_RE_1.match(input) || TITLE_RE_2.match(input))
      _, pre_title, pre_trash, zh_group, index, label, trash, title = match

      if pre_title.empty?
        res << Node.new(pre_trash, "", 0) unless pre_trash.empty?
      else
        res.concat cv_plain(dicts, pre_title)
        res << Node.new(pre_trash, " - ", 0) unless pre_trash.empty?
      end

      vi_group = "#{vi_label(label)} #{Util.hanzi_int(index)}"
      res << Node.new(zh_group, vi_group, 0)
    elsif match = TITLE_RE_3.match(input)
      _, zh_index, trash, title = match
      vi_index = "Chương #{Util.hanzi_int(zh_index)}"

      res << Node.new(zh_index, vi_index, 0)
    else
      title = input
      trash = ""
    end

    if title.empty?
      res << Node.new(trash, "", 0) unless trash.empty?
    else
      res << Node.new(trash, ": ", 0) unless trash.empty?
      res.concat cv_plain(dicts, title)
    end

    res
  end

  private def vi_label(label : String)
    case label
    when "章" then "Chương"
    when "卷" then "Quyển"
    when "集" then "Tập"
    when "节" then "Tiết"
    when "幕" then "Màn"
    when "回" then "Hồi"
    else          label
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

    dsize = dicts.size + 1

    chars.each_with_index do |char, i|
      choices = {} of Int32 => Tuple(Dict::Item, Int32)

      dicts.each_with_index do |dict, j|
        dict.scan(chars, i).each do |item|
          choices[item.key.size] = {item, j + 1}
        end
      end

      choices.each do |size, entry|
        item, dic = entry

        bonus = dic / dsize
        weight = weights[i] + (size + bonus) ** (1 + bonus)

        j = i + size
        if weight >= weights[j]
          weights[j] = weight
          selects[j] = Node.new(item.key, item.vals[0], dic)
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
      next if node.val.empty?

      res << Node.new("", " ", 0) if add_space && space_before?(node.val[0])
      res << node
      add_space = node.dic > 0 || space_after?(node.val[-1])
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
