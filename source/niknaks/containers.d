/**
 * Container types
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module niknaks.containers;

import core.sync.mutex : Mutex;
import std.datetime : Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.thread : Thread;
import core.sync.condition : Condition;
import std.functional : toDelegate;
import core.exception : ArrayIndexError;
import core.exception : RangeError;
import std.string : format;
import niknaks.arrays : removeResize;

version(unittest)
{
    import std.stdio : writeln;
}

version(unittest)
{
    import std.functional : toDelegate;

    private void DebugTouch(T)(Graph!(T) node)
    {
        writeln("Touching graph node ", node);
    }
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
         * See_Also: get 
         */
        public V opIndex(K key)
        {
            return get(key);
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
    int tValue = map["Tristan"];
    assert(tValue == 1);

    // Get the value (should still be cached)
    tValue = map["Tristan"];
    assert(tValue == 1);

    // Wait for expiry (by sweeping thread)
    Thread.sleep(dur!("seconds")(11));

    // Should call replacement function
    tValue = map["Tristan"];
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
    int tValue = map["Tristan"];
    assert(tValue == 1);

    // Wait for 5 seconds (the entry should then be expired by then for on-access check)
    Thread.sleep(dur!("seconds")(5));

    // Get the value (should have replacement function run)
    tValue = map["Tristan"];
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
    int tValue = map["Tristan"];
    assert(tValue == 1);

    // Remove the key
    assert(map.removeKey("Tristan"));

    // Get the value
    tValue = map["Tristan"];
    assert(tValue == 2);

    // Destroy the map (such that it ends the sweeper
    destroy(map);
}

private struct Sector(T)
{
    private T[] data;

    this(T[] data)
    {
        this.data = data;
    }

    public static Sector!(T) make(T[] data)
    {
        return Sector!(T)(data);
    }

    public T opIndex(size_t idx)
    {
        return this.data[idx];
    }

    public void opIndexAssign(T value, size_t index)
    {
        this.data[index] = value;
    }

    // Contract: Obtaining the length must be present
    public size_t opDollar()
    {
        return this.data.length;
    }

    // Contract: Obtaining the length must be present
    @property
    public size_t length()
    {
        return opDollar();
    }

    public T[] opSlice(size_t start, size_t end)
    {
        return this.data[start..end];
    }

    public T[] opSlice()
    {
        return opSlice(0, opDollar);
    }

    // Contract: Rezising must be implemented
    // TODO: This would then be the very reason for
    // using ref actually, as resizing may only
    // change a local copy when extding on
    // the tail-end "extent" (SectorType)

    // Actually should resizing even be done here?

}

// TODO: Make a bit better
import std.traits : hasMember, hasStaticMember, Parameters, arity, ReturnType, TemplateArgsOf;
import std.meta : AliasSeq, staticIndexOf;
private bool isSector(S)()
{
    bool s = true;

    // if()
    alias args = TemplateArgsOf!(S);
    pragma(msg, args);
    static if(!args.length)
    {
        return false;
    }
    
    alias T = args[0];

    // Has opSlice(size_t, size_t) with T[] return
    s &= hasMember!(S, "opSlice") &&
        __traits(isSame, Parameters!(S.opSlice), AliasSeq!(size_t, size_t)) &&
        __traits(isSame, ReturnType!(S.opSlice), T[]);

    // Has opSlice() with T[] return
    bool foundNonParamOpSlice = false;
    foreach(func; __traits(getOverloads, S, "opSlice"))
    {
        if(arity!(func) == 0)
        {
            static if(__traits(isSame, ReturnType!(S.opSlice), T[]))
            {
                foundNonParamOpSlice = true;
            }
        }
    }
    s &= foundNonParamOpSlice;
    // s &= hasMember!(S, "opSlice") && arity!(S.) == 0;

    pragma(msg, __traits(getFunctionAttributes, S.length));
    pragma(msg, 3LU > -1);
    // pragma(msg,   staticIndexOf!("@property", __traits(getFunctionAttributes, S.length)) == -1);
  

    // Has length method
    s &= hasMember!(S, "length") && 
         __traits(isSame, ReturnType!(S.length), size_t) &&
         staticIndexOf!("@property", __traits(getFunctionAttributes, S.length)) != -1;

    // Has opDollar with size_t return
    s &= hasMember!(S, "opDollar") &&
        __traits(isSame, Parameters!(S.opDollar), AliasSeq!()) &&
        __traits(isSame, ReturnType!(S.opDollar), size_t);

    // Has opIndex(size_t) with T return
    s &= hasMember!(S, "opIndex") &&
        __traits(isSame, Parameters!(S.opIndex), AliasSeq!(size_t)) &&
        __traits(isSame, ReturnType!(S.opIndex), T);

    // Has opIndexAssign(size_t) with T return
    s &= hasMember!(S, "opIndexAssign") &&
        __traits(isSame, Parameters!(S.opIndexAssign), AliasSeq!(T, size_t)) &&
        __traits(isSame, ReturnType!(S.opIndexAssign), void);


    // Has make(T[] data) returning S (implied S!(T) due to template arg check earlier)
    s &= hasStaticMember!(S, "make") &&
         __traits(isSame, Parameters!(S.make), AliasSeq!(T[])) &&
         __traits(isSame, ReturnType!(S.make), S);

    return s;
}



/** 
 * A view represents a collection of
 * arrays which can be accessed
 * in an array like manner and have their
 * elements changed too. Therefore this
 * provides access to these originally
 * non-contiguous data sets as if they
 * were one contiguous array.
 *
 * Updating of elements is allowed,
 * fetching of elements (and slices)
 * and lastly sizing down but NOT
 * updwards. This last constraint
 * is why this is considered a "view".
 */
public struct View(T, SectorType = Sector!(T))
if(isSector!(SectorType)())
{
    private SectorType[] sectors;

    // Maybe current size should be here as we
    // are a view, we should allow modofication
    // but not make any NEW arrays
    private size_t curSize;

    private size_t computeTotalLen()
    {
        size_t l;
        foreach(SectorType sector; this.sectors)
        {
            l += sector.opDollar();
        }
        return l;
    }

    public size_t opDollar()
    {
        return this.length;
    }

    public T opIndex(size_t idx)
    {
        // Within range of "fake" size
        if(!(idx < this.length))
        {
            throw new ArrayIndexError(idx, this.length);
        }

        size_t thunk;
        foreach(SectorType sector; this.sectors)
        {
            if(idx-thunk < sector.opDollar())
            {
                return sector[idx-thunk];
            }
            else
            {
                thunk += sector.opDollar();
            }
        }

        // NOTE: This should be unreachable but
        // compiler moans and groans
        assert(false);
    }

    public void opIndexAssign(T value, size_t idx)
    {
        // Within range of "fake" size
        if(!(idx < this.length))
        {
            throw new ArrayIndexError(idx, this.length);
        }

        size_t thunk;
        // TODO: Should be ref, else it is just a local struct copy
        // could cheat if sector is never replaced, hence why it works
        foreach(SectorType sector; this.sectors)
        {
            version(unittest)
            {
                writeln(sector);
                writeln("idx: ", idx);
                writeln("thunk: ", thunk);
            }
            
            if(idx-thunk < sector.opDollar())
            {
                sector[idx-thunk] = value;
                return;
            }
            else
            {
                thunk += sector.opDollar();
            }
        }
    }

    public T[] opSlice()
    {
        return this[0..this.length];
    }

    public T[] opSlice(size_t start, size_t end)
    {
        // Invariant of start <= end
        if(!(start <= end))
        {
            throw new RangeError("Starting index must be smaller than or equal to ending index");
        }
        // If the indices are equal, then it is empty
        else if(start == end)
        {
            return [];
        }
        // Within range of "fake" size
        else if(!((start < this.length) && (end <= this.length)))
        {
            throw new RangeError("start index or end index not under range");
        }

        T[] collected;

        size_t thunk;
        foreach(SectorType sector; this.sectors)
        {
            // If the current sector contains
            // both the starting AND ending
            // indices
            if(start-thunk < sector.opDollar() && end-thunk <= sector.opDollar())
            {
                return sector[start-thunk..end-thunk];
            }
            // If the current sector's starting
            // index (only) is included
            else if(start-thunk < sector.opDollar() && !(end-thunk <= sector.opDollar()))
            {
                collected ~= sector[start-thunk..$];
            }
            // If the current sector's ending
            // index (only) is included
            else if(!(start-thunk < sector.opDollar()) && end-thunk <= sector.opDollar())
            {
                collected ~= sector[0..end-thunk];
            }
            // If the current sector's entirety
            // is to be included
            else
            {
                collected ~= sector[];
            }

            thunk += sector.opDollar();
        }

        return collected;
    }

    private static bool isArrayAppend(P)()
    {
        return __traits(isSame, P, T[]);
    }

    private static bool isElementAppend(P)()
    {
        return __traits(isSame, P, T);
    }

    // Append
    public void opOpAssign(string op, E)(E value)
    if(op == "~" && (isArrayAppend!(E) || isElementAppend!(E)))
    {
        static if(isArrayAppend!(E))
        {
            add(value);
        }
        else
        {
            add([value]);
        }
    }

    // Takes the data, constructs a kind-of SectorType
    // and adds it
    private void add(T[] data)
    {
        // Create a new sector
        SectorType sec = SectorType.make(data);

        // Update the tracking size
        this.curSize += sec.length;

        // Concatenate it to the view
        this.sectors ~= sec;
    }

    @property
    public size_t length()
    {
        return this.curSize;
    }

    @property
    public void length(size_t size)
    {
        // TODO: Need we continuously compute this?
        // ... we should have a tracking field for
        // ... this
        // Would only need to be called in length(size_t)
        // and add(T[])
        size_t actualSize = computeTotalLen();

        // On successful exit, update the "fake" size
        scope(success)
        {
            this.curSize = size;
        }


        // Don't allow sizing up (doesn't make sense for a view)
        if(size > actualSize)
        {
            auto r = new RangeError();
            r.msg = "Cannot extend the size of a view past its total size (of all attached sectors)";
            throw r;
        }
        // If nothing changes
        else if(size == actualSize)
        {
            // Nothing
        }
        // If shrinking to zero
        else if(size == 0)
        {
            // Just drop everything
            this.sectors.length = 0;
        }
        // If shrinking (arbitrary)
        else
        {
            // Sectors from left-to-right to keep
            size_t sectorCnt;

            // Accumulator
            size_t accumulator;

            foreach(SectorType sector; this.sectors)
            {
                accumulator += sector.length;
                sectorCnt++;
                if(size <= accumulator)
                {
                    break;
                }
            }

            this.sectors.length = sectorCnt;
        }
    }
}

unittest
{
    View!(int) view;
    assert(view.opDollar() == 0);

    try
    {
        view[1];
        assert(false);
    }
    catch(ArrayIndexError e)
    {
        assert(e.index == 1);
        assert(e.length == 0);
    }

    view ~= [1,3,45];
    assert(view.opDollar() == 3);
    assert(view.length == 3);

    view ~= 2;
    assert(view.opDollar() == 4);
    assert(view.length == 4);

    assert(view[0] == 1);
    assert(view[1] == 3);
    assert(view[2] == 45);
    assert(view[3] == 2);
    assert(view[0..2] == [1,3]);
    assert(view[0..4] == [1,3,45,2]);

    // Update elements
    view[0] = 71;
    view[3] = 50;

    // Set size to same size
    view.length = view.length;

    // Check that update is present
    // and size unchanged
    int[] all = view[];
    assert(all == [71,3,45,50]);

    // Truncate by 1 element
    view.length = view.length-1;
    all = view[];
    assert(all == [71,3,45]);

    // This should fail
    try
    {
        view[3] = 3;
        assert(false);
    }
    catch(RangeError e)
    {
    }

    // This should fail
    try
    {
        int j = view[3];
        assert(false);
    }
    catch(RangeError e)
    {
    }

    // Up-sizing past real size should not be allowed
    try
    {
        view.length =  view.length+1;
        assert(false);
    }
    catch(RangeError e)
    {
    }

    // Size to zero
    view.length = 0;
    assert(view.length == 0);
    assert(view[] == []);
}

unittest
{
    View!(int) view;
    view ~= 1;
    view ~= [2,3,4];
    view ~= 5;

    assert(view[0..5] == [1,2,3,4,5]);

    // test: start <= end invariant broken
    try
    {
        auto j = view[1..0];
        assert(false);
    }
    catch(RangeError e)
    {

    }

    // test: end out of bounds
    try
    {
        auto j = view[1..view.length+1];
        assert(false);
    }
    catch(RangeError e)
    {

    }

    int[] d = [1,2,3];
    writeln("according to dlang: ", d[1..2]);

    writeln("test lekker: ", view[1..2]);
    assert(view[1..2] == [2]);

    writeln("test lekker: ", view[1..1]);
    assert(view[1..1] == []);
}