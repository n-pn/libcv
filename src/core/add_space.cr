module Chivi::Core
  def add_space(input : Tokens)
    add_space = false

    input.each_with_object(Tokens.new) do |token, res|
      # if add_space && space_before?(token.val)
      # end

      if add_space && space_before?(token.val[0]?)
        res << Token.new("", " ", 0)
      end

      res << token.compact!
      add_space = token.dic > 0 || space_after?(token.val[-1]?)
    end
  end

  private def space_before?(char : Char?)
    case char
    when nil, '”', '’', '⟩', ')', ']',
         '}', ',', '.', ':', ';',
         '!', '?', '%', ' ', '_',
         '…', '/', '\\', '~'
      return false
    else
      return true
    end
  end

  private def space_after?(char : Char?)
    case char
    when nil, '”', '’', '⟩', ')', ']',
         '}', ',', '.', ':', ';',
         '!', '?', '…', '~'
      return true
      # when '“', '‘', '⟨', '(', '[', '{', ' ', '_', '/', '\\'
      # return false
    else
      return false
    end
  end
end
