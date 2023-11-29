module niknaks.containers;

import core.sync.mutex : Mutex;


import std.datetime : Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.thread : Thread;
import core.sync.condition : Condition;
import std.functional : toDelegate;

version(unittest)
{
    import std.stdio : writeln;
}

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

/** 
 * 
 */
public template CacheMap(K, V, ExpirationStrategy strat = ExpirationStrategy.ON_ACCESS)
{
    private alias ReplacementDelegate = V delegate(K);
    private alias ReplacementFunction = V function(K);

    

    /** 
     * 
     */
    public class CacheMap
    {
        private Entry!(V)[K] map;
        private Mutex lock;
        private Duration expirationTime;
        private ReplacementDelegate replFunc;

        static if(strat == ExpirationStrategy.LIVE)
        {
            private Thread checker;
            private bool isRunning;
            private Condition condVar;
            private Duration wakeupTime;
        }
        else static if(strat == ExpirationStrategy.ON_ACCESS)
        {
            private size_t maxHitCount;
            private size_t curHitCount;
        }

        /** 
         * Constructs a new cache map with the
         * given replacement delegate and the
         * expiration deadline.
         *
         * Params:
         *   replFunc = the replacement delegate
         *   expirationTime = the expiration
         * deadline
         */
        this(ReplacementDelegate replFunc, Duration expirationTime = dur!("seconds")(10))
        {
            this.replFunc = replFunc;
            this.lock = new Mutex();
            this.expirationTime = expirationTime;

            static if(strat == ExpirationStrategy.LIVE)
            {
                this.condVar = new Condition(this.lock);
                this.checker = new Thread(&checkerFunc);
                this.isRunning = true;
                this.wakeupTime = dur!("seconds")(2); // TODO: make configurable, also make it idk
                this.checker.start();
            }
            else static if(strat == ExpirationStrategy.ON_ACCESS)
            {
                this.maxHitCount = 100; // TODO: Decide on how this should scale
                this.curHitCount = 0;
            }
        }

        /** 
         * Constructs a new cache map with the
         * given replacement function and the
         * expiration deadline.
         *
         * Params:
         *   replFunc = the replacement function
         *   expirationTime = the expiration
         * deadline
         */
        this(ReplacementFunction replFunc, Duration expirationTime = dur!("seconds")(10))
        {
            this(toDelegate(replFunc));
        }

        /** 
         * Creates an entry for the given
         * key by creating the `Entry`
         * at the key and then setting
         * that entry's value with the
         * replacement function
         *
         * Params:
         *   key = the key
         * Returns: the value set
         */
        private V makeKey(K key)
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }

            // Run the replacement function for this key
            V newValue = replFunc(key);

            // Create a new entry with this value
            Entry!(V) newEntry = Entry!(V)(newValue);

            // Save this entry into the hashmap
            this.map[key] = newEntry;
            
            return newValue;
        }

        /** 
         * Called to update an existing
         * `Entry` (already present) in
         * the map. This will run the 
         * replacement function and update
         * the value present.
         *
         * Params:
         *   key = the key
         * Returns: the value set
         */
        private V updateKey(K key)
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }

            // Run the replacement function for this key
            V newValue = replFunc(key);

            // Update the value saved at this key's entry
            this.map[key].setValue(newValue);

            return newValue;
        }

        // Check's a specific key for expiration,
        // ... and if expired then refreshes it
        // ... if not it leaves it alone
        // 
        // At the end returns the value
        private V expirationCheck(K key)
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }

            // Obtain the entry at this key
            Entry!(V)* entry = key in this.map;

            // If the key exists
            if(entry != null)
            {
                // If this entry expired, run the refresher
                if(entry.getElapsedTime() >= this.expirationTime)
                {
                    version(unittest)
                    {
                        writeln("Expired entry for key '", key, "', refreshing");
                    }
                    
                    updateKey(key);
                }
                // Else, if not, then bump the entry
                else
                {
                    entry.bump();
                }
            }
            // If it does not exist (then make it)
            else
            {
                writeln("Hello there, we must MAKE key as it does not exist");
                makeKey(key);
                writeln("fic");
            }

            return this.map[key].getValue();
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

            // The key's value
            V keyValue;

            // If on-access then run expiration check
            static if(strat == ExpirationStrategy.ON_ACCESS)
            {
                keyValue = expirationCheck(key);
            }
            else static if(strat == ExpirationStrategy.LIVE)
            {
                pragma(msg, "Live stratergy not yet implemented, get() failed");
                static assert(false);
            }

            return keyValue;
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
                // Set run state to false
                this.isRunning = false;

                // Signal to stop
                doLiveCheck();
            }
            
        }
    }
}

int i=0;
private int getVal(string)
{
    i++;
    return i;
}

unittest
{
    CacheMap!(string, int) map = new CacheMap!(string, int)(&getVal);

    // Get the value
    int tValue = map.get("Tristan");
    assert(tValue == 1);

    tValue = map.get("Tristan");
    assert(tValue == 1);

    // Thread.sleep(dur!("seconds")(5));

    // tValue = map.get("Tristan");
    // assert(tValue == 81);

    Thread.sleep(dur!("seconds")(11));

    tValue = map.get("Tristan");
    assert(tValue == 2);

}

unittest
{
    // CacheMap!(string, int, ExpirationStrategy.LIVE) map = new CacheMap!(string, int, ExpirationStrategy.LIVE);

    // map.put("Tristan", 81);
    // int tValue = map.get("Tristan");
    // assert(tValue == 81);

    // Thread.sleep(dur!("seconds")(5));

    // tValue = map.get("Tristan");
    // assert(tValue == 81);

    // Thread.sleep(dur!("seconds")(11));

    // tValue = map.get("Tristan");
    // assert(tValue == int.init);
}

public template CacheList(V)
{
    public class CacheList
    {
        private DList!(Entry!(V)) list;
        private Mutex lock;

        this()
        {
            this.lock = new Mutex();
        }
    }
}