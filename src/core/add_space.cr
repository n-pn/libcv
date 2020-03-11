module Chivi::Core
  def add_space(input : Tokens)
    add_space = false

    input.each_with_object(Tokens.new) do |token, res|
      # if add_space && space_before?(token.val)
      # end

      res << Token.new("", " ", 0) if space_before?(token) && add_space
      res << token.compact!
      add_space = space_after?(token.val)
    end
  end

  private def space_before?(token : Token)
    return false if token.val.empty?

    case token.val[0]
    when '”', '’', '⟩', ')', ']',
         '}', ',', '.', ':', ';',
         '!', '?', '%', ' ', '_',
         '…', '/', '\\'
      return false
    else
      return token.dic > 0
    end
  end

  private def space_after?(val : String)
    return true if val.empty?

    case val[-1]
    when '“', '‘', '⟨', '(', '[', '{', ' ', '_', '/', '\\'
      return false
    else
      return true
    end
  end
end
