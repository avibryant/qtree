class DecayedQTree
  #use the beefcake protobuf library if available
  if defined? Beefcake
    include Beefcake::Message

    def initialize
      #the default beefcake implementation of this is very slow
    end
  else
    def self.required(attr, type, num)
      attr_accessor(attr)
    end
  end

  required :scaledtime, :int64, 1
  required :tree, QTree, 2

  def self.create(value, halflife, timestamp = nil, level = nil)
    timestamp ||= Time.new.to_i
    inst = self.new
    inst.scaledtime = timestamp * Math.log(2.0)/halflife
    inst.tree = QTree.create(value, level)
    inst
  end

  def merge(older, k = 48)
    if older.scaledtime > scaledtime
      older.merge(self, k)
    else
      inst = self.class.new
      inst.scaledtime = scaledtime
      inst.tree = tree.merge(older.tree, k, Math.exp(older.scaledtime - scaledtime))
    end
    inst
  end

  def quantile(p)
    tree.quantile(p)
  end

  def mean
    tree.mean
  end

  def size
    tree.size
  end
end