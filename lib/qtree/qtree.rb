class QTree
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

  required :offset, :int64, 1
  required :level, :int32, 2
  required :count, :double, 3
  required :mean, :double, 4
  required :lowerchild, self, 5
  required :upperchild, self, 6

  def self.create(value, level = nil)
    if(value < 0)
      raise "QTree cannot accept negative values"
    end

    level ||= Fixnum === value ? 0 : -12

    inst = self.new
    inst.offset = (value.to_f / (2.0 ** level)).floor
    inst.level = level
    inst.count = 1.0
    inst.mean = value
    inst
  end

  def width
    2.0 ** level
  end

  def lower_bound
    width * offset
  end

  def upper_bound
    width * (offset + 1)
  end

  def size
    lower_size = lowerchild ? lowerchild.size : 0
    upper_size = upperchild ? upperchild.size : 0
    1 + lower_size + upper_size
  end

  def merge(other, k = 48, scale = 1.0)
    min_count = (count + (other.count * scale)) * 3 / k
    common = common_ancestor_level(other)
    left = extend_to_level(common)
    right = other.extend_to_level(common)
    left.merge_with_peer(right, min_count, scale)
  end

  def quantile(p)
    rank = count * p
    [find_rank_lower_bound(rank), find_rank_upper_bound(rank)]
  end

  protected

  def extend_to_level(n)
    if(n <= level)
      self
    else
      next_level = level + 1
      next_offset = offset / 2

      parent = self.class.new
      parent.level = level + 1
      parent.offset = offset / 2
      parent.count = count
      parent.mean = mean

      if(offset % 2 == 0)
        parent.lowerchild = self
      else
        parent.upperchild = self
      end

      parent.extend_to_level(n)
    end
  end

  def common_ancestor_level(other)
    min_level = [level, other.level].min
    left_offset = offset << (level - min_level)
    right_offset = other.offset << (other.level - min_level)
    offset_diff = left_offset ^ right_offset
    ancestor_level = min_level
    while(offset_diff > 0)
      ancestor_level += 1
      offset_diff >>= 1
    end
    [ancestor_level, level, other.level].max
  end

  def merge_with_peer(other, min_count, scale)
    return self unless other
    inst = self.class.new
    inst.level = level
    inst.offset = offset

    scaled_count = other.count * scale
    inst.count = count + scaled_count
    inst.mean = merge_means(scaled_count, other.mean)
    if(inst.count >= min_count)
      inst.lowerchild = merge_children(lowerchild, other.lowerchild, min_count, scale)
      inst.upperchild = merge_children(upperchild, other.upperchild, min_count, scale)
    end
    inst
  end

  def merge_children(mine, other, min_count, scale)
    if mine
      mine.merge_with_peer(other, min_count, scale)
    elsif other
      if scale == 1.0
        other
      else
        other.prune_and_scale(min_count, scale)
      end
    end
  end

  def prune_and_scale(min_count, scale)
    inst = self.class.new
    inst.level = level
    inst.offset = offset
    inst.count = count * scale
    inst.mean = mean
    if(inst.count >= min_count)
      inst.lowerchild = lowerchild && lowerchild.prune_and_scale(min_count, scale)
      inst.upperchild = upperchild && upperchild.prune_and_scale(min_count, scale)
    end
    inst
  end

  def find_rank_lower_bound(rank)
    if(rank > count)
      nil
    else
      lower_count = lowerchild ? lowerchild.count : 0.0
      upper_count = upperchild ? upperchild.count : 0.0
      parent_count = count - lower_count - upper_count

      result = lowerchild && lowerchild.find_rank_lower_bound(rank - parent_count)

      if result
        result
      else
        new_rank = rank - lower_count - parent_count
        if(new_rank <= 0.0)
          lower_bound
        else
          upperchild && upperchild.find_rank_lower_bound(new_rank)
        end
      end
    end
  end

  def find_rank_upper_bound(rank)
    if(rank > count)
      nil
    else
      result = lowerchild && lowerchild.find_rank_upper_bound(rank)
      if result
        result
      else
        lower_count = (lowerchild && lowerchild.count) || 0.0
        (upperchild && upperchild.find_rank_upper_bound(rank - lower_count)) || upper_bound
      end
    end
  end

  def merge_means(c2, m2)
    c1 = count
    m1 = mean

    if(c1 < c2)
      c1,c2 = c2,c1
      m1,m2 = m2,m1
    end

    new_count = c1 + c2
    weight = c2 / new_count
    if(weight < 0.1)
      m1 + (m2 - m1)*weight
    else
      (c1*m1 + c2*m2) / new_count
    end
  end
end