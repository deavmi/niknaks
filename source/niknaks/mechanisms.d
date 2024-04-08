/**
 * An assortment of mechanisms
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module niknaks.mechanisms;

// import niknaks.functional : Predicate;
import std.functional : toDelegate;
import std.datetime : Duration;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.thread : Thread;

public alias VerdictProviderFunction = bool function();
public alias VerdictProviderDelegate = bool delegate();

public final class DelayTimeoutException : Exception
{
    private Delay delay;

    this(Delay delay)
    {
        super("Timed out whilst attempting delay mechanism");

        this.delay = delay;
    }

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
    private Duration interval, timeout;
    private VerdictProviderDelegate verdictProvider;
    private StopWatch timer = StopWatch(AutoStart.no);

    this(VerdictProviderDelegate verdictProvider, Duration interval, Duration timeout)
    {
        this.verdictProvider = verdictProvider;
        this.interval = interval;
        this.timeout = timeout;
    }

    this(VerdictProviderFunction verdictProvider, Duration interval, Duration timeout)
    {
        this(toDelegate(verdictProvider), interval, timeout);
    }

    public void go()
    {
        // Try get verdict initially
        bool result = verdictProvider();

        // If verdict is a pass, return now
        if(result)
        {
            return;
        }

        // Start timer
        this.timer.start();

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


