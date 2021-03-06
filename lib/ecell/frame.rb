require 'ecell/internals/actor'
require 'ecell/internals/conduit'
require 'ecell'

module ECell
  # An instance of {Frame} manages a Piece. It handles the startup and
  # shutdown processes, stores configuration, and acts as a hub to publish
  # events through. Most ECell-specific objects in a Piece will have access
  # to its Frame.
  class Frame < ECell::Internals::Actor
    extend Forwardable
    include ECell::Internals::Conduit

    attr_reader :configuration

    def initialize(configuration, runner)
      @configuration = configuration
      @runner = runner
      fail "No piece_id provided." unless configuration[:piece_id]
      @figure_ids = []
      @actor_ids = []
      #benzrf TODO: runner.path!(File.dirname(caller[0].split(':')[0])) if CODE_RELOADING
      debug(message: "Initialized", reporter: self.class, highlight: true) if DEBUG_PIECES && DEBUG_DEEP
    rescue => ex
      raise exception(ex, "Failure initializing.")
    end

    def startup
      select_output!
      provision!
      #benzrf Having two separate events is currently necessary. Some
      # emitters must only be set up once every Figure is already done
      # with basic provisioning, because otherwise they might cause a method
      # to be called before basic provisioning is done, and that method may
      # depend on other Figures being set up.
      figure_event(:started)
      figure_event(:started2)
    rescue => ex
      exception(ex, "Failure provisioning.")
      @runner.shutdown
    end

    def provision!
      specs = configuration[:designs].flatten
      celluloid_specs = Hash.new do |h, k|
        h[k] = {
          as: k,
          args: [current_actor, [], {}]
          # args are [frame, faces, strokes]
        }
      end
      specs.each do |spec|
        @actor_ids.concat((spec[:strokes] || {}).keys)
        cspec = celluloid_specs[spec[:as]]
        cspec[:type] ||= spec[:shape]
        cspec[:args][1].concat(spec[:faces] || [])
        cspec[:args][2].merge!(spec[:strokes] || {})
      end
      celluloid_specs.values.map do |cspec|
        @figure_ids << cspec[:as]
        @actor_ids << cspec[:as]
        Celluloid::Future.new {ECell.supervise(cspec)}
      end.map(&:value)
    rescue => ex
      caught(ex, "Trouble establishing designs.")
    end

    def figure_event(event, data=nil)
      @figure_ids.map do |figure_id|
        ECell.sync(figure_id).future.handle_event(event, data)
      end.map(&:value)
    end

    def shutdown
      @output.flush
      @output.close
      @output = nil
      @dump.flush
      @dump.close
      @dump = nil
      @actor_ids.map { |actor|
        begin
          if actor && ECell.sync(actor)
            if ECell.sync(actor).respond_to?(:transition)
              ECell.sync(actor).transition(:shutdown)
            else
              ECell.sync(actor).future.shutdown
            end
          end
        rescue
          nil
        end
      }.map {|s| s.value if s}
    end

    def select_output!
      dir = configuration[:log_dir] || DEFAULT_LOG_DIR
      log = File.join(dir, "#{@configuration[:piece_id]}-console.log")
      dump = File.join(dir, "#{@configuration[:piece_id]}-errors.log")
      @output = File.open(log, "a")
      @dump = File.open(dump, "a")
      if DEBUG_DEEP
        console("Logging to: #{log}")
        console("Dumping to: #{dump}", level: :dump)
      end
    end

    def output
      io = @output || STDOUT
      if block_given?
        yield(io)
        return io.flush
      end
      io
    end

    def dump
      io = @dump || STDERR
      if block_given?
        yield io
        return io.flush
      end
      io
    end
  end
end

