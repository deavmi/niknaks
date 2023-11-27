module niknaks.containers;

import core.sync.mutex : Mutex;


import std.datetime : Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.thread : Thread;
import core.sync.condition : Condition;

/** 
 * Strategy to use for managing
 * expiration of entries
 */
public enum ExpirationStrategy
{
    /** 
     * A thread should be spawned which
     * is to, at regular intervals,
     * wake up and traverse the containr
     * in order to expire entries
     */
    LIVE,

    /** 
     * Every time an access is performed
     * via the container then we traverse
     * the container in order to expire
     * entries
     */
    ON_ACCESS // TODO: Tweak how ofteh this is to make it low O(n) because currently it is 1*O(n) which is bruh moment for a hashmap my fella
}

public template Entry(V)
{
    public struct Entry
    {
        private V value;
        private StopWatch timer;

        @disable
        private this();

        public this(V value)
        {
            setValue(value);
            timer = StopWatch(AutoStart.yes);
        }

        public void setValue(V value)
        {
            this.value = value;
        }

        public V getValue()
        {
            return this.value;
        }

        public void bump()
        {
            timer.reset();
        }

        public Duration getElapsedTime()
        {
            return timer.peek();
        }
    }
}


public template CacheMap(K, V, ExpirationStrategy strat = ExpirationStrategy.ON_ACCESS)
{
    public class CacheMap
    {
        private Entry!(V)[K] map;
        private Mutex lock;
        private Duration expirationTime;

        static if(strat == ExpirationStrategy.LIVE)
        {
            private Thread checker;
            private bool isRunning;
            private Condition condVar;
            private Duration wakeupTime;
        }

        this(Duration expirationTime = dur!("seconds")(10))
        {
            this.lock = new Mutex();
            this.expirationTime = expirationTime;

            static if(strat == ExpirationStrategy.LIVE)
            {
                this.condVar = new Condition(this.lock);
                this.checker = new Thread(&checkerFunc);
                this.isRunning = true;
                this.wakeupTime = dur!("seconds")(2); // make configurable, also make it idk
                this.checker.start();
            }
        }

        // TODO: Traverse through whole thing finding expired entries
        private void expirationCheck()
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }
            
            K[] marked;

            foreach(K key; this.map.keys())
            {
                Entry!(V)* entry = key in this.map;
                if(entry.getElapsedTime() >= this.expirationTime)
                {
                    marked ~= key;
                }
            }

            foreach(K key; marked)
            {
                this.map.remove(key);
            }
        }

        public V get(K key)
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }

            // If on-access then run expiration check
            static if(strat == ExpirationStrategy.ON_ACCESS)
            {
                expirationCheck();
            }

            Entry!(V)* entry = key in this.map;
            V value;

            // If the entry exists
            if(entry != null)
            {
                // Fetch the value
                value = entry.getValue();

                // Bump its timer
                entry.bump();
            }
            // If no key exists
            else
            {
                // TODO: Throw an exception
                return V.init;
            }

            return value;
        }

        public void put(K key, V value)
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }

            Entry!(V)* entry = key in this.map;

            // If the entry exists
            if(entry != null)
            {
                // Store new value
                entry.setValue(value);

                // Bump its timer
                entry.bump();
            }
            // If no key exists
            else
            {
                this.map[key] = Entry!(V)(value);
            }

            // If on-access then run expiration check
            static if(strat == ExpirationStrategy.ON_ACCESS)
            {
                expirationCheck();
            }
        }

        static if(strat == ExpirationStrategy.LIVE)
        {
            private void checkerFunc()
            {
                while(this.isRunning)
                {
                    // Lock the mutex
                    this.lock.lock();

                    // On loop exit
                    scope(exit)
                    {
                        // Unlock the mutex
                        this.lock.unlock();
                    }

                    // Sleep until timeout
                    this.condVar.wait(this.wakeupTime);


                    // Run the expiration check
                    expirationCheck();
                }
            }

            private void doLiveCheck()
            {
                // Lock the mutex
                this.lock.lock();

                // Signal wake up
                this.condVar.notify();

                // Unlock the mutex
                this.lock.unlock();
            }

            ~this()
            {
                
            }
            
        }
    }
}

unittest
{
    CacheMap!(string, int) map = new CacheMap!(string, int);

    map.put("Tristan", 81);
    int tValue = map.get("Tristan");
    assert(tValue == 81);

    Thread.sleep(dur!("seconds")(5));

    tValue = map.get("Tristan");
    assert(tValue == 81);

    Thread.sleep(dur!("seconds")(11));

    tValue = map.get("Tristan");
    assert(tValue == int.init);

}

unittest
{
    // CacheMap!(string, int, ExpirationStrategy.LIVE) map = new CacheMap!(string, int, ExpirationStrategy.LIVE);
}

