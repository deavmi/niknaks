/**
 * Useful methods for debugging
 * data structures
 */
module niknaks.debugging;

import std.traits : ForeachType, isArray;
import std.conv : to;
import std.stdio : writeln, write;

import std.traits : isFunction, arity, ParameterTypeTuple;

private bool isWriteStrat(alias T)(T)
{
    static if(isFunction!(T))
    {
        alias paramTypes = ParameterTypeTuple!(T);
        static if(arity!(T) == 1 && __traits(isSame, paramTypes[0], string))
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    else
    {
        return false;
    }
}

// public alias Strat = void function(string...);

// public Strat defaultStrat = &writeln;

/** 
 * Generates a string containing
 * the provided pattern repeated
 * by the given number of times
 *
 * Params:
 *   count = the number of times
 * to repeat the pattern
 *   pattern = the pattern itself
 * Returns: the repeated pattern
 */
public string genX(size_t count, string pattern)
{
    string strOut;
    for(ubyte i = 0; i < count; i++)
    {
        strOut ~= pattern;
    }
    return strOut;
}

/** 
 * Generates a string containing
 * the number of tabs specified
 *
 * Params:
 *   count = the number of tabs
 * Returns: the tabbed string
 */
public string genTabs(size_t count)
{
    return genX(count, "\t");
}

public void dumpArray(T)(T[] array, size_t start, size_t end, size_t depth = 0)
{
    pragma(msg, T);
    pragma(msg, typeof(array));

    string ident = __traits(identifier, array);

    for(size_t i = start; i < end; i++)
    {
        string textOut;

        static if(isArray!(T))
        {
            textOut = (depth ? "":ident)~"["~to!(string)(i)~"] = ...";

            // Tab by depth
            textOut = genTabs(depth)~textOut;

            writeln(textOut);


            dumpArray(array[i], 0, array[i].length, depth+1);
        }
        else
        {
            textOut = (depth ? "":ident)~"["~to!(string)(i)~"] = "~to!(string)(array[i]);

            // Tab by depth
            textOut = genTabs(depth)~textOut;

            writeln(textOut);
        }

        
    }
}

public void dumpArray(T)(T[] array)
{
    dumpArray(array, 0, array.length);
}

/**
 * Test dumping an array of integers
 */
unittest
{
    int[] test = [1,2,3];
    writeln("Should have 3 things (BEGIN)");
    dumpArray(test);
    writeln("Should have 3 things (END)");
}

/**
 * Test dumping an array of integers
 * with custom bounds
 */
unittest
{
    int[] test = [1,2,3];
    writeln("Should have nothing (BEGIN)");
    dumpArray(test, 0, 0);
    writeln("Should have nothing (END)");
}

/**
 * Test dumping an array of integers
 * with custom bounds
 */
unittest
{
    int[] test = [1,2,3];
    writeln("Should have 2 (BEGIN)");
    dumpArray(test, 1, 2);
    writeln("Should have 2 (END)");
}

/**
 * Test dumping an array of integer
 * arrays
 */
unittest
{
    int[][] test = [ [1,2,3], [4,5,6]];
    dumpArray(test);
}

/**
 * Test dumping an array of an array of
 * integer arrays
 */
unittest
{
    int[][][] test = [
        [   [1,2],
            [3,4]
        ],
        
        [
            [4,5],
            [6,7]
        ]
    ];
    dumpArray(test);
}