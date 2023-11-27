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

