require "./*"

class Chivi::Main
  def initialize(@dir : String = ".dic")
    @repo = Repo.new(@dir)
  end

  def hanviet(input : String)
    chars = Util.normalize(input)
    tokens = Core.cv_lit([@repo.hanviet], chars)
    to_text(tokens)
  end

  def binh_am(input : String)
    chars = Util.normalize(input)
    tokens = Core.cv_lit([@repo.binh_am], chars)
    to_text(tokens)
  end

  def tradsim(input : String)
    puts "TODO: punctuation!!!"

    chars = input.chars
    tokens = Core.cv_raw([@repo.tradsim], chars)
    to_text(tokens)
  end

  def to_text(tokens : Array(Core::Token))
    tokens.map(&.val.split("/").first).join
  end

  def translate(input : String, mode : Symbol = :mixed, book : String? = nil)
    lines = Util.split_lines(input)
    translate(lines, mode, book)
  end

  def translate(lines : Array(String), mode : Symbol, book : String?)
    extra = book ? @repo.unique(book) : @repo.combine
    dicts = [@repo.generic, extra]

    case mode
    when :title
      lines.map { |line| to_text Core.cv_title(dicts, line) }
    when :plain
      lines.map { |line| to_text Core.cv_plain(dicts, line) }
    else # :mixed
      output = [to_text Core.cv_title(dicts, lines.first)]
      lines[1..].each { |line| output << to_text(Core.cv_plain(dicts, line)) }
      output
    end
  end
end
