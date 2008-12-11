require "thread"

class WorkerPool
  include Enumerable
  
  def initialize(size)
    @queue = SizedQueue.new(size)
  end
  
  def workers
    @workers || []
  end
  
  def each
    @workers.each { |w| yield w } if @workers
  end
  
  def push(*jobs)
    ensure_workers
    jobs.each { |job| @queue.push(job) }
    self
  end
  alias << :push
  
  def wait
    return unless @workers
    @workers.size.times { push(nil) }
    sleep 0.01 until @workers.all? { |w| !w.alive? }
    @workers = nil
    nil
  end
  
private

  def ensure_workers
    @workers ||= Array.new(@queue.max) do
      Thread.new do
        while job = @queue.shift
          begin
            job.call
          rescue Exception
            Thread.main.raise $!
          end
        end
      end
    end
  end
  
  class SizedQueue
    attr_reader :max
    
    def initialize(max)
      @max    = max
      @items  = Queue.new
      @guard  = Mutex.new
      @wait   = ConditionVariable.new
    end
    
    # TODO make thread-safe
    def push(obj)
      wait until @items.size < @max
      @items.push(obj)
    end
    
    # TODO make thread-safe
    def shift
      obj = @items.shift
      @guard.synchronize { @wait.signal }
      obj
    end
    
    def wait
      @guard.synchronize { @wait.wait(@guard) }
    end
  end
end
