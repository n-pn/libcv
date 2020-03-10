module Chivi::Core
  def capitalize(input : Tokens, apply_cap = true)
    input.each_with_index do |token, idx|
      if apply_cap && can_apply_cap?(token.val)
        input[idx].capitalize!
        apply_cap = false
      else
        apply_cap ||= cap_after?(token.key)
      end
    end

    input
  end

  private def can_apply_cap?(val : String)
    val[0].alphanumeric?
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
