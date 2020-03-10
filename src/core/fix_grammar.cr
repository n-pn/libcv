module Chivi::Core
  def fix_grammar(input : Tokens) : Tokens
    output = Tokens.new
    idx = 0

    # TODO: handle more special rules, like:
    # - convert hanzi to number,
    # - convert hanzi percent
    # - date and time
    # - guess special words meaning..
    # - apply `的` grammar
    # - apply other grammar rule
    # - ...

    while idx < input.size
      token = input[idx]
      jdx = idx + 1

      if token.dic == 0
        # combine tokens when they are similar
        while jdx < input.size && similar?(token, input[jdx])
          token.key += input[jdx].key
          token.val += input[jdx].val
          jdx += 1
        end
      elsif token.key == "的"
        token.val = ""
        token.dic = 0
      end

      output << token
      idx = jdx
    end

    # puts input, output

    output
  end

  # TODO: handle weblinks?
  private def similar?(current : Token, pending : Token) : Bool
    return false if pending.dic > 0
    a = current.key[0]
    b = pending.key[0]
    return true if a == b
    a.alphanumeric? && b.alphanumeric?
  end
end
