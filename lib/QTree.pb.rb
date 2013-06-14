##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'

##
# Message Classes
#
class QTree < ::Protobuf::Message
  class Stats < ::Protobuf::Message; end
end
class DecayedQTree < ::Protobuf::Message; end

##
# Message Fields
#
class QTree
  class Stats
    required ::Protobuf::Field::DoubleField, :count, 1
    required ::Protobuf::Field::DoubleField, :mean, 2
  end
  
  required ::Protobuf::Field::Int64Field, :offset, 1
  required ::Protobuf::Field::Int32Field, :level, 2
  required ::QTree::Stats, :stats, 3
  optional ::QTree, :lowerchild, 4
  optional ::QTree, :upperchild, 5
end

class DecayedQTree
  required ::Protobuf::Field::Int32Field, :halflife, 1
  required ::Protobuf::Field::Int64Field, :scaledtime, 2
  required ::QTree, :tree, 3
end


