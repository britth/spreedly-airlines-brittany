class Flight
  attr_accessor :name, :cost

  def initialize(name:, cost:)
    @name = name
    @cost = (cost.to_f / 100)
  end
end
