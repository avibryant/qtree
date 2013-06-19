== qtree

Avi Bryant

A QTree provides a compact data structure for approximate quantile and range queries. It's especially useful in a distributed
environment because it can be constructed in parts that are later merged.

Quantile and range queries both give hard upper and lower bounds; the true result will be somewhere in the range given.

Values added to a QTree must be >= 0.

== Usage

````ruby
require 'qtree'

#create a tree for the value 0
tree = QTree.create(0)

1000.times do
  #create a tree for a new random value, and combine it with the existing tree
  #try to keep the resulting tree no larger than approx 60 nodes
  tree = tree.merge(QTree.create(rand), 60)
end

#number of nodes in the tree
puts "Size: #{tree.size}"

#find the exact mean
puts "Mean: #{tree.mean}"

#find the lower and upper bounds of the median
lower, upper = tree.quantile(0.5)
puts "Median: #{lower} - #{upper}"

````
== Implementation

It is loosely related to the Q-Digest data structure from http://www.cs.virginia.edu/~son/cs851/papers/ucsb.sensys04.pdf,
but using an immutable tree structure, and carrying a mean at each node as well as just a count.

The basic idea is to keep a binary tree, where the root represents the entire range of the input keys,
and each child node represents either the lower or upper half of its parent's range. Ranges are constrained to be
dyadic intervals (https://en.wikipedia.org/wiki/Interval_(mathematics)#Dyadic_intervals) for ease of merging.

To keep the size bounded to roughly k nodes, the total count carried by any sub-tree must be at least 3/k of the total
count at the root. Any sub-trees that do not meet this criteria have their children pruned and become leaves.
(It's important that they not be pruned away entirely, but that we keep a fringe of low-count leaves that can
gain weight over time and ultimately split again when warranted).

== Dependencies

If https://github.com/bmizerany/beefcake is available, it will be used to provide protobuf serialization.