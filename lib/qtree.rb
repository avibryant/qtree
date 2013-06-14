require 'protobuf'
require 'QTree.pb'

class QTree
  def self.create(value, level = nil)
    if(value < 0)
      raise "QTree cannot accept negative values"
    end

    level ||= Fixnum === value ? 0 : -16

    inst = self.new
    inst.offset = (value.to_f / (2.0 ** level)).floor
    inst.level = level
    inst.stats = Stats.new(:count => 1.0, :mean => value)
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

  def count
    stats.count
  end

  def mean
    stats.mean
  end

  def +(other)
    common = common_ancestor_level(other)
    left = extend_to_level(common)
    right = other.extend_to_level(common)
    left.merge(right)
  end

  def compress(size_hint = 6)
    min_count = count / (2 ** size_hint)
    new_tree, pruned = prune_children_where{|c| c.count < min_count}
    new_tree
  end

  def quantile(p)
    rank = count * p
    [find_rank_lower_bound(rank), find_rank_upper_bound(rank)]
  end

  def range(from, to)
    if(from <= lower_bound && to >= upper_bound)
      [stats, stats]
    elsif(from < upper_bound && to >= lower_bound)
      partial_range(from,to)
    else
      empty_range
    end
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
      parent.stats = stats.dup

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

  def merge(other)
    inst = self.class.new
    inst.level = level
    inst.offset = offset
    inst.stats = stats + other.stats
    inst.lowerchild = merge_children(lowerchild, other.lowerchild)
    inst.upperchild = merge_children(upperchild, other.upperchild)
    inst
  end

  def merge_children(left, right)
    if left && right
      left.merge(right)
    else
      left || right
    end
  end

  def find_rank_lower_bound(rank)
    if(rank > count)
      nil
    else
      lower_count, upper_count = map_children_with_default(0.0){|c| c.count}
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

  def map_children_with_default(default)
    [(lowerchild && yield(lowerchild)) || default,
      (upperchild && yield(upperchild)) || default]
  end

  def prune_children_where(&b)
    if b.call(self)
      inst = self.class.new
      inst.level = level
      inst.offset = offset
      inst.stats = stats.dup
      inst.lowerchild = nil
      inst.upperchild = nil
      [inst, true]
    else
      new_lower, lower_pruned = prune_child_where(lowerchild, &b)
      new_upper, upper_pruned = prune_child_where(upperchild, &b)
      if(!lower_pruned && !upper_pruned)
        [self, false]
      else
        inst = self.class.new
        inst.level = level
        inst.offset = offset
        inst.stats = stats.dup
        inst.lowerchild = new_lower
        inst.upperchild = new_upper
        [inst, true]
      end
    end
  end

  def prune_child_where(child, &b)
    if child
      child.prune_children_where(&b)
    else
      [nil, false]
    end
  end

  def empty_range
    [Stats.empty, Stats.empty]
  end

  def partial_range(from, to)
    a, b = map_children_with_default(empty_range){|c| c.range(from, to)}
    low = a[0] + b[0]
    high = a[1] + b[1] + stats_without_children
    [low,high]
  end

  def stats_without_children
    result = stats
    result -= lowerchild.stats if lowerchild
    result -= upperchild.stats if upperchild
    result
  end

  class Stats
    def self.empty
      self.new(:count => 0.0, :mean => 0.0)
    end

    def <=>(other)
      count <=> other.count
    end

    def -(other)
      neg = other.dup
      neg.count *= -1
      self + neg
    end

    def +(other)
      if(other.count > count)
        other + self
      elsif(other.count == 0)
        self
      else
        inst = self.class.new
        inst.count = count + other.count
        if(inst.count <= 0)
          inst.mean = 0
        else
          other_weight = other.count / inst.count
          if(other_weight < 0.1)
            inst.mean = mean + (other.mean - mean)*other_weight
          else
            inst.mean = (count*mean + other.count*other.mean) / inst.count
          end
        end
        inst
      end
    end
  end
end
