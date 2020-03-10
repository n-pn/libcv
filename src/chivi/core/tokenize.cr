module Chivi::Core
  def tokenize(dicts : Dicts, input : Chars) : Tokens
    selects = [Token.new('.')]
    weights = [0.0]

    input.each_with_index do |char, idx|
      selects << Token.new(char)
      weights << idx + 1.0
    end

    total = dicts.size + 1

    input.each_with_index do |char, idx|
      choices = {} of Int32 => Token

      dicts.each_with_index do |dict, jdx|
        dict.scan(input, idx).each do |item|
          choices[item.key.size] = Token.new(item.key, item.val, jdx + 1)
        end
      end

      choices.each do |size, token|
        next if token.val.empty?

        acc = token.dic / total
        jump = idx + size
        weight = weights[idx] + (size + acc) ** (1 + acc)

        if weight >= weights[jump]
          weights[jump] = weight
          selects[jump] = token
        end
      end
    end

    res = Tokens.new
    idx = input.size

    while idx > 0
      token = selects[idx]
      res << token
      idx -= token.key.size
    end

    res.reverse
  end
end
