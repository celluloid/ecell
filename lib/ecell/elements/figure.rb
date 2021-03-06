require 'ecell/internals/actor'
require 'ecell/extensions'
require 'ecell/internals/conduit'
require 'ecell/errors'
require 'ecell'
require 'ecell/constants'

module ECell
  module Elements
    #benzrf TODO: this stuff is a little bit out of date since the overhaul.
    # A Figure is an actor which serves to provide the Piece to which it
    # belongs with some kind of faculty, such as making RPCs. This is the
    # base class that every Figure is an instance of.
    #
    # {Figure} serves only as a base class and should not be instantiated
    # directly. Subclasses of {Figure} are called "Shapes".
    #
    # It is common for there to be certain features in a mesh that involve
    # functionality in Figures in more than one Piece; the aforementioned
    # example of RPCs would require both calling functionality in a Figure in
    # the calling Piece and responding functionality in a Figure in the
    # responding Piece. In this case, there should only be one Shape,
    # corresponding to the entire multi-Piece functionality, which both
    # Figures instantiate. The separate Piece-level functionalities should be
    # implemented in separate modules under the Shape. Such modules are called
    # "Faces".
    #
    # The current naming convention is that Shape names should be nouns
    # describing the multi-Piece functionality they provide, and Face names
    # should be verbs describing the actions that they allow a Figure to
    # perform. This applies primarily to Shapes intended for use in multiple
    # Pieces; Shapes that implement Piece-specific logic have no particular
    # convention.
    class Figure < ECell::Internals::Actor
      include ECell::Extensions
      include ECell::Internals::Conduit

      def initialize(frame, faces, strokes)
        @frame = frame
        @sockets = {}
        faces.each do |face|
          face = self.class.const_get(face.to_s.capitalize.to_sym)
          extend face
        end
        strokes.map do |line_id, options|
          future.initialize_line(line_id, options)
        end.map(&:value)
      end

      def shutdown
        @sockets.inject([]) { |shutdown,(line,socket)|
          shutdown << socket.future.transition(:shutdown)
        }.map(&:value)
      end

      def emitter(line, receiver=current_actor, method)
        line.async.emitter(receiver, method)
      end

      def relayer(from, to)
        debug(message: "Setting a relay from #{from}, to #{to}") if DEBUG_DEEP
        if to.ready?
          from.reader { |data|
            to << data
          }
        end
      rescue => ex
        caught(ex, "Trouble with relayer.")
        return
      end

      def initialize_line(line_id, options)
        @sockets[line_id] = super
      rescue => ex
        raise exception(ex, "Line Supervision Exception")
      end

      def leader
        configuration[:leader]
      end

      def handle_event(event, data)
        handler_id = :"on_#{event}"
        handlers = singleton_class.ancestors.map do |anc|
          anc.instance_method(handler_id) if anc.method_defined?(handler_id)
        end.compact.uniq(&:owner)
        handlers.each do |handler|
          handler = handler.bind(self)
          arity = handler.arity
          case arity
          when 0
            handler.call
          when 1
            handler.call(data)
          else
            error("A[n] #{event} event handler has bad arity (#{arity} vs. 1 or 0) and was bypassed.")
          end
        end
      end

      #benzrf TODO: probably improve on this
      def self.lines(*line_ids)
        line_ids.each {|line_id| ECell::Internals::Conduit.register_line_id(line_id)}
      end
    end
  end
end

