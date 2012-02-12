# WorkerPool

Class for managing fixed-size pools of worker threads.

## Use case

I've needed such a class while creating a worker queue of background jobs (similar to [`delayed_job`](http://github.com/tobi/delayed_job)). I wanted to be able to fetch 50 jobs from the database and have them executed 3 at a time, so that when one ends, a new one can start while the other two finish. Then when the whole queue has been emptied, it can be filled with a new batch of jobs, one of which can start immediately while the two from the previous batch finish.

The `WorkerPool` class allows for doing that very easily: fetch jobs from the database, stuff them as `lambda`s into the pool one by one: the throttling is done automatically, blocking `Thread.current` until a slot becomes available, namely until a job ends.

## Usage

    require 'worker_pool'
    
    pool = WorkerPool.new(3)    # three workers
    pool << lambda { sleep 1 }
    pool << lambda { sleep 2 }
    pool << lambda { sleep 3 }
    pool << lambda { sleep 4 }  # waits 3 seconds before starting
    pool.wait                   # takes 7 seconds to finish
    
    # The three workers are now all available again:
    pool << lambda { sleep 2 }  # Starts immediately
    
    # Worker threads are spawned on the fly, so a task can safely kill its
    # thread without preventing the next tasks from running:
    pool = WorkerPool.new(1)
    pool << lambda { puts 1 }
    pool << lambda { raise "an error" }
    pool << lambda { puts 2 }
    pool.wait
    > 1
    > 2

