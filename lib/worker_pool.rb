require "thread"

class WorkerPool
  include Enumerable
  
  def initialize(size)
    @workers, @queue = [], SizedQueue.new(size)
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
    Finish.new(@workers, @queue).wait
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
  
  class Finish
    def initialize(workers, queue)
      @workers, @queue = workers, queue
      @guard, @done = Mutex.new, ConditionVariable.new
    end

    def call
      if @workers.select { |w| w.alive? }.size <= 1
        @guard.synchronize { @done.signal }
      else
        @queue.push(self)
      end
      Thread.current.kill
    end

    def wait
      @queue.push(self)
      @guard.synchronize { @done.wait(@guard) } if @workers.any? { |w| w.alive? }
    end
  end
end
