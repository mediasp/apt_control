#
# Explicitly proxy some objects to have actor proxies - perhaps celluloid already
# has this facility?
#
# The rationale is that I want to leave the underlying objects 'clean' so I
# can test them individually without having to worry about celluloid magic
#
module AptControl::Actors

  module ProxiedClassMethods
    def proxy(method)
      proxy_class.class_eval """\
        def #{method}(*args, &block)
          @proxied_object.#{method}(*args, &block)
        end
"""
    end

    attr_reader :proxy_class

  end

  class ActorProxy
    include Celluloid
    def initialize(proxied_object)
      @proxied_object = proxied_object
    end
  end

  module Proxied
    def self.included(other_class)
      @proxy_class = Class.new(ActorProxy)
      other_class.instance_variable_set('@proxy_class', @proxy_class)
      other_class.extend(ProxiedClassMethods)
    end

    def actor
      @actor_proxy ||= self.class.proxy_class.new(self)
    end
  end
end
