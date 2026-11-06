module ServiceCall
  def self.included(service)
    service.extend(ClassMethods)
  end

  module ClassMethods
    def call(...)
      new.call(...)
    end
  end
end
