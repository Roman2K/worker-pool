require 'test/unit'
require 'worker_pool'

class WorkerPoolTest < Test::Unit::TestCase
  def setup
    @pool = WorkerPool.new(2)
  end
  
  def test_each
    @pool << lambda { } << lambda { }
    
    assert_equal 2, @pool.to_a.size
    assert_kind_of Thread, @pool.to_a[0]
    assert_kind_of Thread, @pool.to_a[1]
    
    @pool.wait
    
    assert_equal [], @pool.to_a
  end
  
  def test_handle
    5.times do
      setup
      jobs, result = [], []
      before = Time.now
      @pool << lambda { sleep 0.01; result << 1 }
      @pool << lambda { sleep 0.01; result << 2 }
      @pool << lambda { sleep 0.01; result << 3 }
      @pool << lambda { sleep 0.01; result << 4 }
      @pool.wait
      assert_equal [1, 2, 3, 4], result.sort
    end
  end
  
  class ErrorFromWorker < StandardError
  end
  
  def test_handle_with_exception
    assert_raise ErrorFromWorker do
      @pool.push(lambda { raise ErrorFromWorker })
      @pool.finish
    end
  end
  
  def test_wait
    first, second = [], []
    
    @pool << lambda { sleep 0.01; first << 1 }
    @pool << lambda { sleep 0.01; first << 2 }
    @pool.wait
    
    @pool << lambda { sleep 0.01; second << 3 }
    @pool << lambda { sleep 0.01; second << 4 }
    @pool.wait
    
    assert_equal [1, 2], first.sort
    assert_equal [3, 4], second.sort
  end
  
  def test_wait_when_empty
    @pool.wait
  end
end
