require 'json'

class Ef::Pack::Capacity::Logging::Storage::File < Ef::Pack::Actor

  include Ef::Pack::Extensions
  finalizer :shutdown

  def initialize(config={})
    @enabled = config[:service] == DEFAULT_LEADER
    execute {
      tag = mark("FINISH", :after)
      @console = File.open(LOG_FILE[:console], "a")
      @errors = File.open(LOG_FILE[:errors], "a")
      console(tag)
      errors(tag)
    }
  end

  def save(entry)
    execute {
      log = entry.formatted
      errors(log) if [:warn, :error].include? entry.level
      console(log)
      send(([ :warn, :error ].include? entry.level) ? :errors : :console, JSON.pretty_generate(entry.store)) if entry.store.any?
    }
  end

  def console(data)
    @console.puts(data)
  end

  def errors(data)
    @errors.puts(data)
  end

  def shutdown
    puts "#{self.class} cleanly shutting down." if DEBUG_SHUTDOWN
    execute {
      tag = mark("FINISH", :after)
      console(tag)
      errors(tag)
      @errors.close
      @console.close
    }
  end

  private

  def mark(tag, where=:neither)
    "#{(where==:before)?'\n\n\n\n\n':''}> #{tag} * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *#{(where==:after)?'\n\n\n\n\n':''}"
  end

  def execute
    if @enabled
      yield
    end
  end

end