# One public entry point, always .call (spec 14).
class ApplicationCommand
  def self.call(**kwargs)
    new(**kwargs).call
  end
end
