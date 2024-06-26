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
import std.stdio : File, write;
import std.string : strip, empty;

version(unittest)
{
    import std.process : pipe, Pipe;
    import std.conv : to;
    import std.stdio : writeln;
}

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

/** 
 * A user-defined prompt
 */
public struct Prompt
{
    private bool isMultiValue;
    private bool allowEmpty;
    private string query;
    private string[] value;

    /** 
     * Constructs a new prompt
     * with the given query
     *
     * Params:
     *   query = the prompt
     * query itself
     *   isMultiValue = if the
     * query allows for multiple
     * inputs (default is `false`)
     *   allowEmpty = if the
     * answer may be empty (default
     * is `true`)
     */
    this(string query, bool isMultiValue = false, bool allowEmpty = false)
    {
        this.query = query;
        this.isMultiValue = isMultiValue;
        this.allowEmpty = allowEmpty;
    }

    /** 
     * Gets the prompt query
     *
     * Returns: the query
     */
    public string getQuery()
    {
        return this.query;
    }

    /** 
     * Retrieves this prompt's
     * answer
     *
     * Params:
     *   answer = the first
     * answer is placed here
     * (if any)
     * Returns: `true` if there
     * is at least one answer,
     * `false` otherwise
     */
    public bool getValue(ref string answer)
    {
        if(this.value.length)
        {
            answer = this.value[0];
            return true;
        }

        return false;
    }

    /** 
     * Retrieves this prompt's
     * multiple anwers
     *
     * Params:
     *  answers = the answers
     * (if any)
     * Returns: `true` if there
     * are answers, `false` otherwise
     */
    public bool getValues(ref string[] answers)
    {
        if(this.value.length)
        {
            answers = this.value;
            return true;
        }
        
        return false;
    }

    /** 
     * Fill this prompt's
     * query with a corresponding
     * answer
     *
     * Params:
     *   value = the answer
     */
    public void fill(string value)
    {
        this.value ~= value;
    }
}

/** 
 * A prompting mechanism
 * which can be filled up
 * with questions and a
 * file-based source to
 * read answers in from
 * and associate with
 * their original respective
 * questions
 */
public class Prompter
{
    /** 
     * Source file
     */
    private File source;

    /** 
     * Whether or not to close
     * the source file on destruction
     */
    private bool closeOnDestruct;

    /** 
     * Prompts to query by
     */
    private Prompt[] prompts;

    /** 
     * Constructs a new prompter
     * with the given file source
     * from where the input is to
     * be read from.
     *
     * Params:
     *   source = the `File` to
     * read from
     *   closeOnDestruct = if
     * set to `true` then on
     * destruction we will close
     * the source, if `false` it
     * is left untouched
     *
     * Throws:
     *   Exception if the provided
     * `File` is not open
     */
    this(File source, bool closeOnDestruct = false)
    {
        if(!source.isOpen())
        {
            throw new Exception("Source not open");
        }

        this.closeOnDestruct = closeOnDestruct;
        this.source = source;
    }

    /** 
     * Appends the given prompt
     *
     * Params:
     *   prompt = the prompt
     */
    public void addPrompt(Prompt prompt)
    {
        this.prompts ~= prompt;
    }

    /** 
     * Performs the prompting
     * by querying each attached
     * prompt for an answer
     * which is then associated
     * with the given prompt
     *
     * Returns: the answered
     * prompts
     */
    public Prompt[] prompt()
    {
        char[] buff;

        prompt_loop: foreach(ref Prompt prompt; this.prompts)
        {
            scope(exit)
            {
                buff.length = 0;
            }

            // Prompt until empty
            if(prompt.isMultiValue)
            {
                string ans;

                do
                {
                    // If EOF signalled to us then
                    // exit
                    if(this.source.eof())
                    {
                        break prompt_loop;
                    }

                    scope(exit)
                    {
                        buff.length = 0;
                    }

                    // Perform the query
                    write(prompt.getQuery());
                    this.source.readln(buff);
                    ans = strip(cast(string)buff);

                    // If not empty, then add
                    if(!ans.empty())
                    {
                        prompt.fill(ans);
                    }
                }
                while(!ans.empty());
            }
            // Prompt once (or more depending on policy)
            else
            {
                string ans;
                do
                {
                    // If EOF signalled to us then
                    // exit
                    if(this.source.eof())
                    {
                        break prompt_loop;
                    }

                    // Perform the query
                    write(prompt.getQuery());
                    this.source.readln(buff);
                    ans = strip(cast(string)buff);
                }
                while(ans.empty() && !prompt.allowEmpty);

                // Fill answer into prompt
                prompt.fill(ans);
            }
        }

        return this.prompts;
    }

    /** 
     * Destructor
     */
    ~this()
    {
        if(this.closeOnDestruct)
        {
            this.source.close();
        }
    }
}

/**
 * Creating two single-valued prompts
 * and then extracting the answers to
 * them out
 */
unittest
{
    Pipe pipe = pipe();

    // Create a prompter with some prompts
    Prompter p = new Prompter(pipe.readEnd());
    p.addPrompt(Prompt("What is your name?"));
    p.addPrompt(Prompt("How old are you"));

    // Fill up pipe with data for read end
    File writeEnd = pipe.writeEnd();
    writeEnd.writeln("Tristan Brice Velloza Kildaire");
    writeEnd.writeln(1);
    writeEnd.flush();

    // Perform the prompt and get the
    // answers back out
    Prompt[] ans = p.prompt();

    writeln(ans);

    string nameVal;
    assert(ans[0].getValue(nameVal));
    assert(nameVal == "Tristan Brice Velloza Kildaire");

    string ageVal;
    assert(ans[1].getValue(ageVal));
    assert(to!(int)(ageVal) == 1); // TODO: Allow union conversion later
}

/**
 * Creating a single-value prompt
 * which CANNOT be empty and then
 * also a multi-valued prompt
 */
unittest
{
    Pipe pipe = pipe();

    // Create a prompter with some prompts
    Prompter p = new Prompter(pipe.readEnd());
    p.addPrompt(Prompt("What is your name?", false, false));
    p.addPrompt(Prompt("Enter the names of your friends", true));

    // Fill up pipe with data for read end
    File writeEnd = pipe.writeEnd();
    writeEnd.writeln(""); // Purposefully do empty (for name)
    writeEnd.writeln("Tristan Brice Velloza Kildaire"); // Now actually fill it in (for name)
    writeEnd.writeln("Thomas");
    writeEnd.writeln("Risima");
    writeEnd.writeln("");
    writeEnd.flush();

    // Perform the prompt and get the
    // answers back out
    Prompt[] ans = p.prompt();

    writeln(ans);

    string nameVal;
    assert(ans[0].getValue(nameVal));
    assert(nameVal == "Tristan Brice Velloza Kildaire");

    string[] friends;
    assert(ans[1].getValues(friends));
    assert(friends == ["Thomas", "Risima"]);
}