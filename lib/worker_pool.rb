require "thread"

class WorkerPool
  include Enumerable
  
  def initialize(size)
    @workers, @queue = [], SizedQueue.new(size)
  end
  
  # Returns the current size of the pool.
  def size
    @queue.max
  end
  
  # Modifies the size of the pool. If the new size is lower than the current and
  # tasks are still being executed by extra workers, those task will finish but
  # the extra worker slots won't be renewed upon further pushes.
  def size=(size)
    @queue.max = size
  end
  
  # Yields each worker thread. These might be either active or dead.
  def each
    @workers.each { |worker| yield worker }
  end
  
  # Schedules one or more tasks to be executed as soon as a worker is available.
  # If that's not the case at the time of the push, the current thread will
  # block until a slot becomes available.
  def push(*tasks)
    ensure_workers
    tasks.each { |task| @queue.push(task) }
    self
  end
  alias << :push
  
  # Schedules a single task passed as a block that will be called with the
  # passed arguments. Example usage:
  #
  #   (1..3).each { |n| pool.schedule(n) { |i| process(i) } }
  #
  # Instead of:
  #
  #   (1..3).each { |n| pool << lambda { process(n) } }
  #
  def schedule(*args)
    push(lambda { yield *args })
  end
  
  # Blocks until all current tasks have been executed.
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
