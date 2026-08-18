# Base for boundary objects. DTOs are immutable, keyword-initialised, and carry
# no persistence or workflow (spec 11).
class ApplicationDto
  def self.attribute(*names)
    names.each { |name| attr_reader name }
    (@attribute_names ||= []).concat(names)
  end

  def self.attribute_names
    @attribute_names ||= []
  end

  def to_h
    self.class.attribute_names.index_with { |name| public_send(name) }
  end

  def ==(other)
    other.is_a?(self.class) && other.to_h == to_h
  end
end
