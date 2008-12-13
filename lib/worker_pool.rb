require "thread"

class WorkerPool
  include Enumerable
  
  def initialize(size)
    @queue = SizedQueue.new(size)
    @workers = []
  end
  
  def each
    @workers.each { |w| yield w }
  end
  
  def push(*tasks)
    ensure_workers
    tasks.each { |task| @queue.push(task) }
    self
  end
  alias << :push
  
  def wait
    @workers.each { @queue.push(nil) }
    sleep 0.01 until @workers.all? { |w| !w.alive? }
    self
  end
  
private

  def ensure_workers
    @workers.delete_if { |w| !w.alive? }
    @workers << Thread.new { while task = @queue.shift do task.call end } unless @workers.size >= @queue.max
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
