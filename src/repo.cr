require "./dict"

# Loading dicts
class Chivi::Repo
  alias DictMap = Hash(String, Dict)
  alias UserMap = Hash(String, DictMap)

  def initialize(@root = ".dic")
    @dicts = {
      "common" => DictMap.new,
      "shared" => DictMap.new,
      "unique" => DictMap.new,
    }

    @fixes = {
      "shared" => UserMap.new { |h, k| h[k] = DictMap.new },
      "unique" => UserMap.new { |h, k| h[k] = DictMap.new },
    }
  end

  alias Dicts = Array(Dict)

  def cc_cedict
    @dicts["common"]["cc_cedict"] ||= load_dic(".", "cc_cedict")
  end

  def trungviet
    @dicts["common"]["trungviet"] ||= load_dic(".", "trungviet")
  end

  def hanviet
    @dicts["common"]["hanviet"] ||= load_dic(".", "hanviet")
  end

  def binh_am
    @dicts["common"]["binh_am"] ||= load_dic(".", "binh_am")
  end

  def tradsim
    @dicts["common"]["tradsim"] ||= load_dic(".", "tradsim")
  end

  def generic
    @dicts["shared"]["generic"] ||= load_dic("shared", "generic")
  end

  def generic(fix : String)
    @fixes["shared"]["generic"][fix] ||= load_fix("shared", "generic", fix)
    {generic, @fixes["shared"]["generic"][fix]}
  end

  def combine
    @dicts["shared"]["combine"] ||= load_dic("shared", "combine")
  end

  def combine(fix : String)
    @fixes["shared"]["combine"][fix] ||= load_fix("shared", "combine", fix)
    {combine, @fixes["shared"]["combine"][fix]}
  end

  def suggest
    @dicts["shared"]["suggest"] ||= load_dic("shared", "suggest")
  end

  def suggest(fix : String)
    @fixes["shared"]["suggest"][fix] ||= load_fix("shared", "suggest", fix)
    {suggest, @fixes["shared"]["suggest"][fix]}
  end

  def unique(name : String)
    @dicts["unique"][name] ||= load_dic("unique", name)
  end

  def unique(name : String, fix : String)
    @fixes["unique"][name][fix] ||= load_fix("unique", name, fix)
    {unique(name), @fixes["unique"][name][fix]}
  end

  def load_dic(dir : String, name : String)
    Dict.new(File.join(@root, dir, "#{name}.dic"))
  end

  def load_fix(dir : String, name : String, user : String = "admin")
    Dict.new(File.join(@root, dir, "#{name}.#{user}.fix"))
  end
end
