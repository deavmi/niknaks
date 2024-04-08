/**
 * An assortment of mechanisms
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module niknaks.mechanisms;

import std.functional : toDelegate;
import std.datetime : Duration;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.thread : Thread;

/** 
 * A verdict-providing function
 */
public alias VerdictProviderFunction = bool function();

/** 
 * A verdict-providing delegate
 */
public alias VerdictProviderDelegate = bool delegate();

/** 
 * An exception thrown when a `Delay`
 * mechanism times out
 */
public final class DelayTimeoutException : Exception
{
    /** 
     * The offending delay mechanism
     */
    private Delay delay;

    /** 
     * Constructs a new exception with
     * the offending `Delay`
     *
     * Params:
     *   delay = the offending `Delay`
     */
    this(Delay delay)
    {
        super("Timed out whilst attempting delay mechanism");

        this.delay = delay;
    }

    /** 
     * Returns the offending delay
     * mechanism
     *
     * Returns: the `Delay`
     */
    public Delay getDelay()
    {
        return this.delay;
    }
}

/** 
 * A mechanism that consumes a function
 * and calls it at a regular interval,
 * exiting if it returns a `true` verdict
 * within a certain time limit but
 * throwing an exception if it never
 * returned a `true` verdict in said
 * time window and the time was exceeded
 */
public class Delay
{
    /** 
     * The interval to retry
     * and the total timeout
     */
    private Duration interval, timeout;

    /** 
     * The delegate to call
     * to obtain a verdict
     */
    private VerdictProviderDelegate verdictProvider;

    /** 
     * Internal timer
     */
    private StopWatch timer = StopWatch(AutoStart.no);

    /** 
     * Constructs a new delay mechanism
     * with the given delegate to call
     * in order to determine the verdict,
     * an interval to call it at and the
     * total timeout
     *
     * Params:
     *   verdictProvider = the provider of the verdicts
     *   interval = thje interval to retry at
     *   timeout = the timeout
     */
    this(VerdictProviderDelegate verdictProvider, Duration interval, Duration timeout)
    {
        this.verdictProvider = verdictProvider;
        this.interval = interval;
        this.timeout = timeout;
    }

    /** 
     * Constructs a new delay mechanism
     * with the given function to call
     * in order to determine the verdict,
     * an interval to call it at and the
     * total timeout
     *
     * Params:
     *   verdictProvider = the provider of the verdicts
     *   interval = thje interval to retry at
     *   timeout = the timeout
     */
    this(VerdictProviderFunction verdictProvider, Duration interval, Duration timeout)
    {
        this(toDelegate(verdictProvider), interval, timeout);
    }

    /** 
     * Performs the delay mechanism
     *
     * Throws:
     *    DelayTimeoutException if
     * we time out
     */
    public void go()
    {
        // On leave stop-and-reset (this is for re-use)
        scope(exit)
        {
            this.timer.stop();
            this.timer.reset();
        }

        // Start timer
        this.timer.start();

        // Try get verdict initially
        bool result = verdictProvider();

        // If verdict is a pass, return now
        if(result)
        {
            return;
        }

        // Whilst still in time window
        while(this.timer.peek() < this.timeout)
        {
            // Wait a little bit
            Thread.sleep(this.interval);

            // Try get verdict
            result = verdictProvider();

            // If verdict is a pasds, return now
            if(result)
            {
                return;
            }
        }
        
        // If we get here it is because we timed out
        throw new DelayTimeoutException(this);
    }

}

version(unittest)
{
    import std.datetime : dur;
}

/**
 * Tests out the delay mechanism
 * with a verdict provider (as a
 * delegate) which is always false
 */
unittest
{
    bool alwaysFalse()
    {
        return false;
    }

    Delay delay = new Delay(&alwaysFalse, dur!("seconds")(1), dur!("seconds")(1));

    try
    {
        delay.go();
        assert(false);
    }
    catch(DelayTimeoutException e)
    {
        assert(true);
    }
    
}

version(unittest)
{
    bool alwaysFalseFunc()
    {
        return false;
    }
}

/**
 * Tests out the delay mechanism
 * with a verdict provider (as a
 * function) which is always false
 */
unittest
{
    Delay delay = new Delay(&alwaysFalseFunc, dur!("seconds")(1), dur!("seconds")(1));

    try
    {
        delay.go();
        assert(false);
    }
    catch(DelayTimeoutException e)
    {
        assert(true);
    }
    
}

/**
 * Tests out the delay mechanism
 * with a verdict provider (as a
 * function) which is always true
 */
unittest
{
    bool alwaysTrue()
    {
        return true;
    }

    Delay delay = new Delay(&alwaysTrue, dur!("seconds")(1), dur!("seconds")(1));

    try
    {
        delay.go();
        assert(true);
    }
    catch(DelayTimeoutException e)
    {
        assert(false);
    }
}

/**
 * Tests out the delay mechanism
 * with a verdict provider (as a
 * delegate) which is only true
 * on the second call
 */
unittest
{
    int cnt = 0;
    bool happensLater()
    {
        cnt++;
        if(cnt == 2)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    Delay delay = new Delay(&happensLater, dur!("seconds")(1), dur!("seconds")(1));

    try
    {
        delay.go();
        assert(true);
    }
    catch(DelayTimeoutException e)
    {
        assert(false);
    }
}

