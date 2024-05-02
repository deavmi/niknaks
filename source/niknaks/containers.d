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
import std.string : format;
import niknaks.arrays : removeResize;

version(unittest)
{
    import std.stdio : writeln;
}

version(unittest)
{
    import std.functional : toDelegate;

    private void DebugTouch(T)(Tree!(T) node)
    {
        writeln("Touching tree node ", node);
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

public template Always(T)
{
    public bool Always(Tree!(T) treeNode)
    {
        version(unittest)
        {
            import std.stdio : writeln;
            writeln("Strat for: ", treeNode);
        }
        return true;
    }
}

public template Nothing(T)
{
    public void Nothing(Tree!(T) treeNode)
    {

    }
}

/** 
 * The inclusion stratergy which
 * will be called upon the tree
 * node prior to it being visited
 * during a dfs operation.
 *
 * It is a predicate to determine
 * whether or not the tree node
 * in concern should be recursed
 * upon.
 */
public template InclusionStratergy(T)
{
    public alias InclusionStratergy = bool delegate(Tree!(T) item);
}

/** 
 * This is called on a tree node
 * as part of the first action
 * that takes place during the
 * visitation of said node during
 * a dfs operation.
 */
public template TouchStratergy(T)
{
    public alias TouchStratergy = void delegate(Tree!(T) item);
}



// TODO: Technically this is a graph
public class Tree(T)
{
    private T value;
    private Tree!(T)[] children;

    /** 
     * Constructs a new tree with
     * the given value to set
     *
     * Params:
     *   value = the value of
     * this tree node
     */
    this(T value)
    {
        this.value = value;
    }

    /** 
     * Creates a new tree without
     * associating any value with
     * itself
     */
    this()
    {

    }

    /** 
     * Sets the tree node's
     * associated value
     *
     * Params:
     *   value = the valye
     */
    public void setValue(T value)
    {
        this.value = value;
    }

    /** 
     * Appends another tree node
     * to the array of children
     * of this node's
     *
     * Params:
     *   node = the tree node
     * to append
     */
    public void appendNode(Tree!(T) node)
    {
        this.children ~= node;
    }

    /** 
     * Removes a given tree node
     * from th array of children
     * of thie node's
     *
     * Params:
     *   node = the tree node to
     * remove
     * Returns: `true` if the node
     * was found and then removed,
     * otherwise `false`
     */
    public bool removeNode(Tree!(T) node)
    {
        bool found = false;
        size_t idx;
        for(size_t i = 0; i < this.children.length; i++)
        {
            found = this.children[i] == node;
            if(found)
            {
                idx = i;
                break;
            }
        }

        if(found)
        {
            this.children = this.children.removeResize(idx);
            return true;
        }

        return false;
    }

    private static bool isTreeNodeType(E)()
    {
        return __traits(isSame, E, Tree!(T));
    }

    private static bool isTreeValueType(E)()
    {
        return __traits(isSame, E, T);
    }

    /** 
     * Returns a slice of the requested
     * type. This is either `Tree!(T)`
     * or `T` itself, therefore returning
     * an array of either
     *
     * Returns: an array of the requested
     * type of children
     */
    public E[] opSlice(E)()
    if(isTreeNodeType!(E) || isTreeValueType!(E))
    {
        // If the children as tree nodes is requested
        static if(isTreeNodeType!(E))
        {
            return this.children;
        }
        // If the children as values themselves is requested
        else static if(isTreeValueType!(E))
        {
            T[] slice;
            foreach(Tree!(T) tnode; this.children)
            {
                slice ~= tnode.value;
            }
            return slice;
            // import std.algorithm.iteration : map;
            // return map!(getValue)(this.children)[];
        }
    }

    /** 
     * Returns an array of all the childrens'
     * associated values
     *
     * Returns: a `T[]`
     */
    public T[] opSlice()
    {
        return opSlice!(T)();
    }

    /** 
     * Returns the element of the child
     * at the given index.
     *
     * The type `E` can be specified
     * as either `Tree!(T)` or `T`
     * which will hence return a node
     * from the children array at the 
     * given index of that tyope (either
     * the child node or the child node's
     * value).
     *
     * Params:
     *   idx = the index 
     * Returns: the type `E`
     */
    public E opIndex(E)(size_t idx)
    if(isTreeNodeType!(E) || isTreeValueType!(E))
    {
        // If the cjild as a tree node is requested
        static if(isTreeNodeType!(E))
        {
            return this.children[idx];
        }
        // If the child as a value itself is requested
        else static if(isTreeValueType!(E))
        {
            return this.children[idx].value;
        }
    }

    public T opIndex(size_t idx)
    {
        return opIndex!(T)(idx);
    }

    public T[] dfs
    (
        InclusionStratergy!(T) strat = toDelegate(&Always!(T)),
        TouchStratergy!(T) touch = toDelegate(&Nothing!(T))
    )
    {
        version(unittest)
        {
            writeln("dfs entry: ", this);
        }
        
        T[] collected;
        scope(exit)
        {
            version(unittest)
            {
                writeln("leaving node ", this, " with collected ", collected);
            }
        }

        // Touch
        touch(this); // root[x]

        foreach(Tree!(T) child; this.children) // subtree[x], 
        {
            if(strat(child))
            {
                version(unittest)
                {
                    writeln("dfs, strat good for child: ", child);
                }

                // Visit
                collected ~= child.dfs(strat, touch);
            }
            else
            {
                version(unittest)
                {
                    writeln("dfs, strat ignored for child: ", child);
                }
            }
        }

        // "Visit"
        collected ~= this.value;
        
        
        return collected;
    }

    public override string toString()
    {
        return format("TreeNode [val: %s]", this.value);
    }
}

/**
 * Test out usage of the tree
 */
unittest
{
    Tree!(string) treeOfStrings = new Tree!(string)("Top");

    Tree!(string) subtree_1 = new Tree!(string)("1");
    Tree!(string) subtree_2 = new Tree!(string)("2");
    Tree!(string) subtree_3 = new Tree!(string)("3");

    treeOfStrings.appendNode(subtree_1);
    treeOfStrings.appendNode(subtree_2);
    treeOfStrings.appendNode(subtree_3);


    InclusionStratergy!(string) strat = toDelegate(&Always!(string));
    TouchStratergy!(string) touch = toDelegate(&DebugTouch!(string));

    string[] result = treeOfStrings.dfs(strat, touch);
    writeln("dfs: ", result);

    assert(result[0] == "1");
    assert(result[1] == "2");
    assert(result[2] == "3");
    assert(result[3] == "Top");


    auto i = treeOfStrings.opSlice!(Tree!(string))();
    writeln("Siblings: ", i);
    assert(i[0] == subtree_1);
    assert(i[1] == subtree_2);
    assert(i[2] == subtree_3);

    auto p = treeOfStrings.opSlice!(string)();
    writeln("Siblings (vals): ", p);
    assert(p == treeOfStrings[]);


    assert(treeOfStrings.removeNode(subtree_1));
    assert(!treeOfStrings.removeNode(subtree_1));
}

/** 
 * A kind-of a tree which has the ability
 * to linearize all of its nodes which
 * results in performing a depth first
 * search resulting in the collection of
 * all nodes into a single array with
 * elements on the left hand side being
 * the most leafiest (and left-to-right
 * on the same depth are in said order).
 *
 * It also marks a node as visited on
 * entry to it via the dfs call to it.
 *
 * When dfs is performed, a child node
 * is only recursed upon if it has not
 * yet been visited.
 *
 * With all this, it means a graph of
 * relations can be flattened into an
 * array.
 */
public class VisitationTree(T) : Tree!(T)
{
    private bool visisted;    

    /** 
     * Constructs a new node
     *
     * Params:
     *   value = the value
     */
    this(T value)
    {
        super(value);
    }

    /** 
     * Performs the linearization
     *
     * Returns: the linearized list
     */
    public T[] linearize()
    {
        return dfs(toDelegate(&_shouldVisit), toDelegate(&_touch));
    }

    /** 
     * The inclusion startergy
     *
     * Params:
     *   tnode = the tree node
     * Returns: `true` if not
     * yet visited or incompatible
     * node type
     */
    private static bool _shouldVisit(Tree!(T) tnode)
    {
        VisitationTree!(T) vnode = cast(VisitationTree!(T))tnode;
        return vnode && !vnode.isVisited();
    }

    /** 
     * The touching stratergy
     *
     * Only works on compatible
     * tree nodes
     *
     * Params:
     *   tnode = the tree node
     */
    private static void _touch(Tree!(T) tnode)
    {
        VisitationTree!(T) vnode = cast(VisitationTree!(T))tnode;
        if(vnode)
        {
            vnode.mark();
        }
    }

    /** 
     * Marks this node as
     * visited
     */
    private void mark()
    {
        this.visisted = true;
    }
    
    /** 
     * Checks this node has been
     * visited
     *
     * Returns: `true` if visited,
     * otherwise `false`
     */
    private bool isVisited()
    {
        return this.visisted;
    }
}

/**
 * Tests out using the visitation tree
 */
unittest
{
    VisitationTree!(string) root = new VisitationTree!(string)("root");

    VisitationTree!(string) thing = new VisitationTree!(string)("subtree");
    root.appendNode(thing);
    thing.appendNode(root);

    string[] linearized = root.linearize();
    writeln(linearized);

    assert(linearized[0] == "subtree");
    assert(linearized[1] == "root");
}