require 'celluloid/current'
require 'ecell/constants'
require 'ecell/internals/spool'

module ECell
  include ECell::Constants

  Celluloid.task_class = if DEBUG_BACKTRACING
    Celluloid::Task::Threaded
  else
    require 'celluloid/task/pooled_fiber'
    Celluloid::Task::PooledFiber
  end

  module Internals
    #benzrf TODO: why use an empty subclass instead of the class itself?
    class Supervisor < Celluloid::Supervision::Container; end
    Celluloid.services.supervise(type: Supervisor, as: :service)
  end

  # This module contains basic general-purpose Designs, Shapes, and Strokes.
  module Base
  end

  # The elements of ECell systems.
  module Elements
  end

  class << self
    def sync(actor)
      Celluloid::Actor[actor]
    end

    def supervise(config)
      sync(:service).supervise(config)
    end

    ECell.supervise(as: :spool, type: ECell::Internals::Spool)

    def async(actor)
      #benzrf TODO: possible race condition here?
      if Celluloid::Actor[actor]
        Celluloid::Actor[actor].async rescue nil
      else
        Celluloid::Actor[:spool][actor] rescue nil
      end
    end

    alias_method :[], :async
  end
end

