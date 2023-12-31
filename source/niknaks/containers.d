/**
 * Container types
 */
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
 * Represents an entry of
 * some value of type `V`
 *
 * Associated with this
 * is a timer used to
 * check against for
 * expiration
 */
private template Entry(V)
{
    /**
     * The entry type
     */
    public struct Entry
    {
        private V value;
        private StopWatch timer;

        @disable
        private this();

        /** 
         * Creates a new entry
         * with the given value
         *
         * Params:
         *   value = the value
         */
        public this(V value)
        {
            setValue(value);
            timer = StopWatch(AutoStart.yes);
        }

        /** 
         * Sets the value of this
         * entry
         *
         * Params:
         *   value = the value
         */
        public void setValue(V value)
        {
            this.value = value;
        }

        /** 
         * Returns the value associated
         * with this entry
         *
         * Returns: the value
         */
        public V getValue()
        {
            return this.value;
        }

        /** 
         * Resets the timer back
         * to zero
         */
        public void bump()
        {
            timer.reset();
        }

        /** 
         * Gets the time elapsed
         * since this entry was
         * instantiated
         *
         * Returns: the elapsed
         * time
         */
        public Duration getElapsedTime()
        {
            return timer.peek();
        }
    }
}

/** 
 * A `CacheMap` with a key type of `K`
 * and value type of `V`
 */
public template CacheMap(K, V)
{
    /** 
     * A replacement function which takes
     * in the key of type `K` and returns
     * a value of type `V`
     *
     * This is the delegate-based variant
     */
    public alias ReplacementDelegate = V delegate(K);

    /** 
     * A replacement function which takes
     * in the key of type `K` and returns
     * a value of type `V`
     *
     * This is the function-based variant
     */
    public alias ReplacementFunction = V function(K);

    /** 
     * A caching map which when queried
     * for a key which does not exist yet
     * will call a so-called replacement
     * function which produces a result
     * which will be stored at that key's
     * location
     *
     * After this process a timer is started,
     * and periodically entries are checked
     * for timeouts, if they have timed out
     * then they are removed and the process
     * begins again.
     *
     * Accessing an entry will reset its
     * timer ONLY if it has not yet expired
     * however accessing an entry which
     * has expired causing an on-demand
     * replacement function call, just not
     * a removal in between
     */
    public class CacheMap
    {
        private Entry!(V)[K] map;
        private Mutex lock;
        private Duration expirationTime;
        private ReplacementDelegate replFunc;

        private Thread checker;
        private bool isRunning;
        private Condition condVar;
        private Duration sweepInterval;
        
        /** 
         * Constructs a new cache map with the
         * given replacement delegate and the
         * expiration deadline.
         *
         * Params:
         *   replFunc = the replacement delegate
         *   expirationTime = the expiration
         * deadline
         *   sweepInterval = the interval at
         * which the sweeper thread should
         * run at to check for expired entries
         */
        this(ReplacementDelegate replFunc, Duration expirationTime = dur!("seconds")(10), Duration sweepInterval = dur!("seconds")(10))
        {
            this.replFunc = replFunc;
            this.lock = new Mutex();
            this.expirationTime = expirationTime;

            this.sweepInterval = sweepInterval;
            this.condVar = new Condition(this.lock);
            this.checker = new Thread(&checkerFunc);
            this.isRunning = true;
            this.checker.start();
          
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
         *   sweepInterval = the interval at
         * which the sweeper thread should
         * run at to check for expired entries
         */
        this(ReplacementFunction replFunc, Duration expirationTime = dur!("seconds")(10), Duration sweepInterval = dur!("seconds")(10))
        {
            this(toDelegate(replFunc), expirationTime, sweepInterval);
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

        /** 
         * Check's a specific key for expiration,
         * and if expired then refreshes it if
         * not it leaves it alone.
         *
         * Returns the key's value
         *
         * Params:
         *   key = the key to check
         * Returns: the key's value
         */
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
                    version(unittest) { writeln("Expired entry for key '", key, "', refreshing"); }
                    
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
                version(unittest) { writeln("Hello there, we must MAKE key as it does not exist"); }
                makeKey(key);
                version(unittest) { writeln("fic"); }
            }

            return this.map[key].getValue();
        }

        /** 
         * Gets the value of
         * the entry at the
         * provided key
         *
         * This may or may not
         * call the replication
         * function
         *
         * Params:
         *   key = the key to
         * lookup by
         *
         * Returns: the value
         */
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

            // On access expiration check
            keyValue = expirationCheck(key);

            return keyValue;
        }

        /** 
         * Removes the given key
         * returning whether or
         * not it was a success
         *
         * Params:
         *   key = the key to
         * remove
         * Returns: `true` if the
         * key existed, `false`
         * otherwise
         */
        public bool removeKey(K key)
        {
            // Lock the mutex
            this.lock.lock();

            // On exit
            scope(exit)
            {
                // Unlock the mutex
                this.lock.unlock();
            }

            // Remove the key
            return this.map.remove(key);
        }

        /** 
         * Runs at the latest every
         * `expirationTime` ticks
         * and checks the entire
         * map for expired
         * entries
         */
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

                // Sleep until sweep interval
                this.condVar.wait(this.sweepInterval);

                // Run the expiration check
                K[] marked;
                foreach(K curKey; this.map.keys())
                {
                    Entry!(V) curEntry = this.map[curKey];

                    // If entry has expired mark it for removal
                    if(curEntry.getElapsedTime() >= this.expirationTime)
                    {
                        version(unittest) { writeln("Marked entry '", curEntry, "' for removal"); }
                        marked ~= curKey;
                    }
                }

                foreach(K curKey; marked)
                {
                    Entry!(V) curEntry = this.map[curKey];

                    version(unittest) { writeln("Removing entry '", curEntry, "'..."); }
                    this.map.remove(curKey);
                }
            }
        }

        /** 
         * Wakes up the checker
         * immediately such that
         * it can perform a cycle
         * over the map and check
         * for expired entries
         */
        private void doLiveCheck()
        {
            // Lock the mutex
            this.lock.lock();

            // Signal wake up
            this.condVar.notify();

            // Unlock the mutex
            this.lock.unlock();
        }

        /** 
         * On destruction, set
         * the running status
         * to `false`, then
         * wake up the checker
         * and wait for it to
         * exit
         */
        ~this()
        {
            version(unittest)
            {
                writeln("Dtor running");

                scope(exit)
                {
                    writeln("Dtor running [done]");
                }
            }

            // Set run state to false
            this.isRunning = false;

            // Signal to stop
            doLiveCheck();

            // Wait for it to stop
            this.checker.join();
        }
    }
}

/**
 * Tests the usage of the `CacheMap` type
 * along with the expiration of entries
 * mechanism
 */
unittest
{
    int i = 0;
    int getVal(string)
    {
        i++;
        return i;
    }

    // Create a CacheMap with 10 second expiration and 10 second sweeping interval
    CacheMap!(string, int) map = new CacheMap!(string, int)(&getVal, dur!("seconds")(10));

    // Get the value
    int tValue = map.get("Tristan");
    assert(tValue == 1);

    // Get the value (should still be cached)
    tValue = map.get("Tristan");
    assert(tValue == 1);

    // Wait for expiry (by sweeping thread)
    Thread.sleep(dur!("seconds")(11));

    // Should call replacement function
    tValue = map.get("Tristan");
    assert(tValue == 2);

    // Wait for expiry (by sweeping thread)
    writeln("Sleeping now 11 secs");
    Thread.sleep(dur!("seconds")(11));

    // Destroy the map (such that it ends the sweeper)
    destroy(map);
}

/**
 * Creates a `CacheMap` which tests out
 * the on-access expiration checking of
 * entries by accessing an entry faster
 * then the sweep interval and by
 * having an expiration interval below
 * the aforementioned interval
 */
unittest
{
    int i = 0;
    int getVal(string)
    {
        i++;
        return i;
    }

    // Create a CacheMap with 5 second expiration and 10 second sweeping interval
    CacheMap!(string, int) map = new CacheMap!(string, int)(&getVal, dur!("seconds")(5), dur!("seconds")(10));

    // Get the value
    int tValue = map.get("Tristan");
    assert(tValue == 1);

    // Wait for 5 seconds (the entry should then be expired by then for on-access check)
    Thread.sleep(dur!("seconds")(5));

    // Get the value (should have replacement function run)
    tValue = map.get("Tristan");
    assert(tValue == 2);

    // Destroy the map (such that it ends the sweeper
    destroy(map);
}

/**
 * Tests the usage of the `CacheMap`,
 * specifically the explicit key
 * removal method
 */
unittest
{
    int i = 0;
    int getVal(string)
    {
        i++;
        return i;
    }

    // Create a CacheMap with 10 second expiration and 10 second sweeping interval
    CacheMap!(string, int) map = new CacheMap!(string, int)(&getVal, dur!("seconds")(10), dur!("seconds")(10));

    // Get the value
    int tValue = map.get("Tristan");
    assert(tValue == 1);

    // Remove the key
    assert(map.removeKey("Tristan"));

    // Get the value
    tValue = map.get("Tristan");
    assert(tValue == 2);

    // Destroy the map (such that it ends the sweeper
    destroy(map);
}