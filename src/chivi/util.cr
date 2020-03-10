require "./util/*"

module Chivi::Util
  extend self

  # capitalize all words
  def titlecase(input : String)
    input.split(" ").map { |x| capitalize(x) }.join(" ")
  end

  # don't downcase extra characters
  def capitalize(str : String) : String
    str[0].upcase + str[1..]
  end

  def slugify(input : String, no_accent = false)
    input = unaccent(input) if no_accent

    input.downcase
      .gsub(/[^\p{L}\p{N}_]/, "-")
      .split("-")
      .reject(&.empty?)
      .join("-")
  end

  def unaccent(input : String)
    input
      .tr("áàãạảAÁÀÃẠẢăắằẵặẳĂẮẰẴẶẲâầấẫậẩÂẤẦẪẬẨ", "a")
      .tr("éèẽẹẻEÉÈẼẸẺêếềễệểÊẾỀỄỆỂ", "e")
      .tr("íìĩịỉIÍÌĨỊỈ", "i")
      .tr("óòõọỏOÓÒÕỌỎôốồỗộổÔỐỒỖỘỔơớờỡợởƠỚỜỠỢỞ", "o")
      .tr("úùũụủUÚÙŨỤỦưứừữựửƯỨỪỮỰỬ", "u")
      .tr("ýỳỹỵỷYÝỲỸỴỶ", "y")
      .tr("đĐD", "d")
  end

  # Convert chinese punctuations to english punctuations
  # and full width characters to ascii characters
  def normalize(input : Array(Char)) : Array(Char)
    input.map { |c| NORMALIZE.fetch(c, c) }
  end

  def normalize(input : String) : Array(Char)
    normalize(input.chars)
  end

  # read chinese text file and strip whitespaces
  def read_lines(input : String) : Array(String)
    split_lines(File.read(input))
  end

  # Split text to lines, strip empty whitespaces
  def split_lines(input : String) : Array(String)
    input.split("\n").map(&.tr("　", " ").strip).reject(&.empty?)
  end

  NUMBER  = "零〇一二三四五六七八九十百千"
  LABELS  = "章节幕回集卷"
  HEAD_RE = /^(.*?)(\s*)(第?([\d#{NUMBER}]+)([#{LABELS}]))([,.:]?\s*)(.*)$/

  # split chapter title and translate chapter index
  def split_head(input : String)
    if match = input.match(HEAD_RE)
      vi_index = vi_label(match[5]) + " " + hanzi_int(match[4])
      {match[1], match[2], match[3], vi_index, match[6], match[7]}
    else
      nil
    end
  end

  # convert chinese numbers to latin numbers
  def hanzi_int(input)
    HANZI_INT.fetch(input, input)
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
end
