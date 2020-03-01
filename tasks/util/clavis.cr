require "colorize"

class Clavis
  alias Data = Hash(String, String)
  getter file : String
  getter data : Data

  def initialize(@file : String)
    @data = Data.new
  end

  def self.load!(file : String)
    raise "File [#{file.colorize(:red)}] not found!" unless File.exists?(file)
    new(file).load!
  end

  private def get_sever(file : String = @file)
    File.extname(file) == ".txt" ? "=" : "|"
  end

  def load!(file : String = @file)
    print "- loading [#{file.colorize(:blue)}]... "

    sever = get_sever(file)
    count = 0

    File.read_lines(file).each do |line|
      next if line.empty? || line[0] == '#'

      rows = line.split(sever, 2)
      # next if rows.empty?

      key = rows[0]
      if val = rows[1]?
        val = val.split(/[\/|]/).join("/") if sever == "="
        set(key, val)
      else
        del(key)
      end

      count += 1
    end

    puts "done, entries: #{count.to_s.colorize(:blue)}"
    self
  end

  def merge!(that : String, mode : Symbol = :old_first)
    merge! Clavis.load!(that), mode
  end

  def merge!(that : Clavis, mode : Symbol = :old_first)
    print "- merging [#{@file.colorize(:yellow)}] with [#{that.file.colorize(:yellow)}], mode: [:#{mode.to_s.colorize(:yellow)}]... "

    count = 0

    @data.merge!(that.data) do |k, v1, v2|
      count += 1
      case mode
      when :keep_old  then v1
      when :keep_new  then v2
      when :new_first then v2 + '/' + v1
      else                 v1 + '/' + v2
      end
    end

    puts "done, conflict: #{count.to_s.colorize(:yellow)}"
    self
  end

  def save!(file = @file, keep = 10, sort = false)
    print "- saving [#{file.colorize(:green)}]... "

    sever = get_sever(file)

    data = sort ? @data.to_a.sort_by { |k, v| {k.size, k} } : @data.to_a

    File.open file, "w" do |f|
      data.each do |key, val|
        vals = val.split('/').map { |x| x.strip }.uniq.first(keep).join('/')
        f << key << sever << vals << "\n"
      end
    end

    puts "done, entries: #{@data.size.to_s.colorize(:green)}"

    self
  end

  def includes?(key : String)
    @data.has_key?(key)
  end

  def keys
    @data.keys
  end

  def size
    @data.size
  end

  def set(key : String, val : String)
    @data[key] = val
  end

  def add(key : String, val : String, mode = :old_first)
    if old = get(key)
      val =
        case mode
        when :keep_new  then val
        when :new_first then val + '/' + old
        when :old_first then old + '/' + val
        else                 old
        end
    end

    @data[key] = val
  end

  def del(key : String)
    @data.delete key
  end

  def get(key : String)
    @data[key]?
  end

  def fetch(key : String)
    if val = get(key)
      val.split('/', 2).first
    else
      key
    end
  end

  def translate(input : String, joiner = "")
    input.split("").map { |c| fetch(c) }.join(joiner)
  end
end
