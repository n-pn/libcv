require "json"
require "./dict"
require "./util"

require "./core/*"

module Chivi::Core
  extend self

  class Token
    include JSON::Serializable

    property key : String
    property val : String
    property dic : Int32 = 0

    def initialize(chr : Char)
      @key = chr.to_s
      @val = chr.to_s
      @dic = 0
    end

    def initialize(@key, @val, @dic)
    end

    def capitalize!
      @val = Util.capitalize(@val)
      self
    end

    def compact!
      @val = @val.split("/").first unless @val == "/"
      self
    end

    def to_s(io : IO)
      io << "[" << @key << ":" << @val << ":" << @dic << "]"
    end
  end

  alias Tokens = Array(Token)

  alias Dicts = Array(Dict)
  alias Chars = Array(Char)

  def convert_title(dicts : Dicts, input : String)
    if match = Util.split_head(input)
      head_text, head_trash, zh_index, vi_index, tail_trash, tail_text = match

      output = Tokens.new

      if !head_text.empty?
        output.concat convert_plain(dicts, head_text)
        output << Token.new(head_trash, " - ", 0)
      elsif !head_trash.empty?
        output << Token.new(head_trash, "", 0)
      end

      output << Token.new(zh_index, vi_index, 0)

      if !tail_text.empty?
        output << Token.new(tail_trash, ": ", 0)
        output.concat convert_title(dicts, tail_text) # incase volume title is mixed with chapter title
      elsif !tail_trash.empty?
        output << Token.new(tail_trash, "", 0)
      end

      output
    else
      convert_plain(dicts, input)
    end
  end

  def convert_plain(dicts : Dicts, input : String)
    chars = Util.normalize(input)
    tokens = fix_grammar(tokenize(dicts, chars))
    add_space(capitalize(tokens))
  end
end
