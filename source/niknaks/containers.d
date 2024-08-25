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

/** 
 * A visitation stratergy
 * which always returns
 * `true`
 */
public template Always(T)
{
    /** 
     * Whatever graph node is
     * provided always accept
     * a visitation to it
     *
     * Params:
     *   treeNode = the node
     * Returns: `true` always
     */
    public bool Always(Graph!(T) treeNode)
    {
        version(unittest)
        {
            import std.stdio : writeln;
            writeln("Strat for: ", treeNode);
        }
        return true;
    }
}

/** 
 * A touching stratergy
 * that does nothing
 */
public template Nothing(T)
{
    /** 
     * Consumes a graph node
     * and does zilch with it
     *
     * Params:
     *   treeNode = the node
     */
    public void Nothing(Graph!(T));
}

/** 
 * The inclusion stratergy which
 * will be called upon the graph
 * node prior to it being visited
 * during a dfs operation.
 *
 * It is a predicate to determine
 * whether or not the graph node
 * in concern should be recursed
 * upon.
 */
public template InclusionStratergy(T)
{
    public alias InclusionStratergy = bool delegate(Graph!(T) item);
}

/** 
 * This is called on a graph node
 * as part of the first action
 * that takes place during the
 * visitation of said node during
 * a dfs operation.
 */
public template TouchStratergy(T)
{
    public alias TouchStratergy = void delegate(Graph!(T) item);
}

/** 
 * A graph of nodes.
 *
 * These nodes are comprised of
 * two components. The first of
 * which is their associated value
 * of type `T`, then the second
 * are their children nodes
 * (if any). The latter are of
 * type `Graph!(T)` and therefore
 * when constructing one such node
 * it can also be added as a child
 * of another node, therefore
 * allowing you to build your
 * graph as you see fit.
 *
 * Some notable functionality,
 * other than the obvious,
 * is the pluggable dfs method
 * which let's you perform 
 * a recursive search on
 * the graph, parameterized
 * by two stratergies. The first
 * is the so-called `TouchStratergy`
 * which specifies the function
 * to be called on the current node
 * when `dfs` is called on it -
 * this is the first thing that
 * is done. The other parameter
 * is the `VisitationStratergy`
 * which is a predicate that
 * will be called BEFORE
 * entering the dfs (recursing)
 * of a candidate child node.
 * With this things like trees
 * can be built or rather
 * _derived_ from a graph.
 * This is infact what the visitation
 * tree type does.
 *
 * See_Also: `VisitationTree`
 */
public class Graph(T)
{
    private T value;
    private Graph!(T)[] children;

    /** 
     * Constructs a new graph with
     * the given value to set
     *
     * Params:
     *   value = the value of
     * this graph node
     */
    this(T value)
    {
        this.value = value;
    }

    /** 
     * Creates a new graph without
     * associating any value with
     * itself
     */
    this()
    {

    }

    /** 
     * Sets the graph node's
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
     * Obtains the value associated with
     * this graph node
     *
     * Returns: the value `T`
     */
    public T getValue()
    {
        return this.value;
    }

    /** 
     * Appends another graph node
     * to the array of children
     * of this node's
     *
     * Params:
     *   node = the tree node
     * to append
     */
    public void appendNode(Graph!(T) node)
    {
        this.children ~= node;
    }

    /** 
     * Removes a given graph node
     * from th array of children
     * of thie node's
     *
     * Params:
     *   node = the graph node to
     * remove
     * Returns: `true` if the node
     * was found and then removed,
     * otherwise `false`
     */
    public bool removeNode(Graph!(T) node)
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

    /** 
     * Checks if the given type is
     * that of a graph node
     *
     * Returns: `true` if so, `false`
     * otherwise
     */
    private static bool isGraphNodeType(E)()
    {
        return __traits(isSame, E, Graph!(T));
    }

    /** 
     * Checks if the given type is
     * that of a graph node's value
     * type
     *
     * Returns: `true` if so, `false`
     * otherwise
     */
    private static bool isGraphValueType(E)()
    {
        return __traits(isSame, E, T);
    }

    /** 
     * Returns a slice of the requested
     * type. This is either `Graph!(T)`
     * or `T` itself, therefore returning
     * an array of either
     *
     * Returns: an array of the requested
     * type of children
     */
    public E[] opSlice(E)()
    if(isGraphNodeType!(E) || isGraphValueType!(E))
    {
        // If the children as graph nodes is requested
        static if(isGraphNodeType!(E))
        {
            return this.children;
        }
        // If the children as values themselves is requested
        else static if(isGraphValueType!(E))
        {
            T[] slice;
            foreach(Graph!(T) tnode; this.children)
            {
                slice ~= tnode.value;
            }
            return slice;
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
     * as either `Graph!(T)` or `T`
     * which will hence return a node
     * from the children array at the 
     * given index of that type (either
     * the child node or the child node's
     * value).
     *
     * Params:
     *   idx = the index 
     * Returns: the type `E`
     */
    public E opIndex(E)(size_t idx)
    if(isGraphNodeType!(E) || isGraphValueType!(E))
    {
        // If the child as a graph node is requested
        static if(isGraphNodeType!(E))
        {
            return this.children[idx];
        }
        // If the child as a value itself is requested
        else static if(isGraphValueType!(E))
        {
            return this.children[idx].value;
        }
    }

    /** 
     * Returns the value of
     * the child node at
     * the provided index
     *
     * Params:
     *   idx = the index
     * Returns: the value
     */
    public T opIndex(size_t idx)
    {
        return opIndex!(T)(idx);
    }

    /** 
     * Returns the number
     * of children attached
     * to this node
     *
     * Returns: the count
     */
    @property
    public size_t length()
    {
        return this.children.length;
    }

    /** 
     * Returns the number
     * of children attached
     * to this node
     *
     * Returns: the count
     */
    public size_t opDollar()
    {
        return this.length;
    }

    /** 
     * Performs a depth first search
     * on the graph by firstly calling
     * the `TouchStratergy` on the current
     * node and then iterating over all
     * of its children and only recursing
     * on each of them if the `InclusionStratergy`
     * allows it.
     *
     * The touch stratergy is called
     * as part of the first line of code
     * in the call to the dfs on a
     * given graph node.
     *
     * Note that is you don't have a good
     * inclusion stratergy and touch startergy
     * then you may have a stack overflow
     * occur if your graph has cycles
     *
     * Params: 
     *   strat = the `InclusionStratergy` 
     *   touch = the `TouchStratergy`
     * Returns: a `T[]`
     */
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

        foreach(Graph!(T) child; this.children) // subtree[x], 
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

    /** 
     * Returns a string representation
     * of this node and its value
     *
     * Returns: a `string`
     */
    public override string toString()
    {
        return format("GraphNode [val: %s]", this.value);
    }
}

/**
 * Test out usage of the `Graph!(T)`
 */
unittest
{
    Graph!(string) treeOfStrings = new Graph!(string)("Top");

    Graph!(string) subtree_1 = new Graph!(string)("1");
    Graph!(string) subtree_2 = new Graph!(string)("2");
    Graph!(string) subtree_3 = new Graph!(string)("3");

    treeOfStrings.appendNode(subtree_1);
    treeOfStrings.appendNode(subtree_2);
    treeOfStrings.appendNode(subtree_3);

    assert(treeOfStrings.opIndex!(Graph!(string))(0) == subtree_1);
    assert(treeOfStrings.opIndex!(Graph!(string))(1) == subtree_2);
    assert(treeOfStrings.opIndex!(Graph!(string))(2) == subtree_3);

    assert(treeOfStrings[0] == subtree_1.getValue());
    assert(treeOfStrings[1] == subtree_2.getValue());
    assert(treeOfStrings[2] == subtree_3.getValue());

    assert(treeOfStrings.opDollar() == 3);

    InclusionStratergy!(string) strat = toDelegate(&Always!(string));
    TouchStratergy!(string) touch = toDelegate(&DebugTouch!(string));

    string[] result = treeOfStrings.dfs(strat, touch);
    writeln("dfs: ", result);

    assert(result[0] == "1");
    assert(result[1] == "2");
    assert(result[2] == "3");
    assert(result[3] == "Top");


    auto i = treeOfStrings.opSlice!(Graph!(string))();
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
 * A kind-of a graph which has the ability
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
public class VisitationTree(T) : Graph!(T)
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
     *   tnode = the graph node
     * Returns: `true` if not
     * yet visited or incompatible
     * node type
     */
    private static bool _shouldVisit(Graph!(T) tnode)
    {
        VisitationTree!(T) vnode = cast(VisitationTree!(T))tnode;
        return vnode && !vnode.isVisited();
    }

    /** 
     * The touching stratergy
     *
     * Only works on compatible
     * graph nodes
     *
     * Params:
     *   tnode = the tree node
     */
    private static void _touch(Graph!(T) tnode)
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

    // Contract: Allow downsizing
    @property
    public void length(size_t newSize)
    {
        assert(newSize <= this.data.length);
        this.data.length = newSize;
    }
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

    // Has length (setter) method
    bool found_len_setter = false;
    static foreach(lenFunc; __traits(getOverloads, S, "length"))
    {
        static if
        (
            __traits(isSame, Parameters!(lenFunc), AliasSeq!(size_t)) &&
            __traits(isSame, ReturnType!(lenFunc), void) &&
            staticIndexOf!("@property", __traits(getFunctionAttributes, lenFunc)) != -1
        )
        {
            found_len_setter = true;
        }
    }
    s &= found_len_setter;

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

    /** 
     * Computes the sum of the
     * length of all sectors
     * attached to us
     *
     * Returns: the total
     */
    private size_t computeTotalLen()
    {
        size_t l;
        foreach(SectorType sector; this.sectors)
        {
            l += sector.opDollar();
        }
        return l;
    }

    /** 
     * Returns the total length
     * of the data in the view
     *
     * Returns: the length
     */
    public size_t opDollar()
    {
        return this.length;
    }

    /** 
     * Retrieves the value of
     * the element at the
     * given position
     *
     * Params:
     *   idx = the position
     * of the element
     * Returns: the value
     */
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

    /** 
     * Updates the element at
     * the given index with
     * a new value
     *
     * Params:
     *   value = the new value
     *   idx = the element
     * to update's position
     */
    public void opIndexAssign(T value, size_t idx)
    {
        // Within range of "fake" size
        if(!(idx < this.length))
        {
            throw new ArrayIndexError(idx, this.length);
        }

        size_t thunk;
        foreach(ref SectorType sector; this.sectors)
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

    /** 
     * Returns a copy of the entire
     * view
     *
     * Returns: a `T[]`
     */
    public T[] opSlice()
    {
        return this[0..this.length];
    }

    /** 
     * Returns a copy of the view
     * within the provided bounds
     *
     * Params:
     *   start = the starting
     * index
     *   end = the ending index
     * (exclusive)
     * Returns: 
     */
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

    /** 
     * Appends a new value to
     * the end of the view
     *
     * Params:
     *   value = the value
     * to append
     */
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

    /** 
     * Takes the data with which we
     * constructs a kind-of `SectorType`
     * from. We then adjust the total
     * size and append the new sector
     *
     * Params:
     *   data = the data to append
     */
    private void add(T[] data)
    {
        // Create a new sector
        SectorType sec = SectorType.make(data);

        // Update the tracking size
        this.curSize += sec.length;

        // Concatenate it to the view
        this.sectors ~= sec;
    }

    /** 
     * Returns the total length
     * of the data in the view
     *
     * Returns: the length
     */
    @property
    public size_t length()
    {
        return this.curSize;
    }

    /** 
     * Resizes the total
     * length of the view.
     *
     * This allows the user
     * to either keep the
     * size the same or
     * shrink the view,
     * but never extend
     * it.
     *
     * 
     * Params:
     *   size = the new size
     * Throws:
     *   RangeError if an
     * attempt to extend
     * the length is made
     */
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

            foreach(ref SectorType sector; this.sectors)
            {
                accumulator += sector.length;
                sectorCnt++;
                if(size <= accumulator)
                {
                    // TODO: Resize on the tail-end sector?

                    // Bleed size (accumulation of previous sectors)
                    // called "x". Then we do `size-x`, this gives
                    // us the bleed size and we use this as the
                    // tail-end sector's new size
                    size_t tailEndTrimSize = size-(accumulator-sector.length);
                    version(unittest)
                    {
                        writeln("tailEndTrimSize: ", tailEndTrimSize);
                    }
                    sector.length(tailEndTrimSize);

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