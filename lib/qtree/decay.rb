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

  def self.create(value, timestamp = nil, level = nil)
    timestamp ||= Time.new.to_i
    inst = self.new
    inst.scaledtime = timestamp
    inst.tree = QTree.create(value, level)
    inst
  end

  def merge(other, halflife, k = 48)
    #todo
  end

  def quantile(p)
    tree.quantile(p)
  end

  def range(from, to)
    #todo
  end
end