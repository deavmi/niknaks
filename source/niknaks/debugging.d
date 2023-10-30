/**
 * Useful methods for debugging
 * data structures
 */
module niknaks.debugging;

import std.traits : ForeachType, isArray;
import std.conv : to;
import std.stdio : writeln;

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

public void dumpArray(T)(T[] array, size_t start, size_t end)
{
    pragma(msg, T);
    pragma(msg, typeof(array));

    string ident = __traits(identifier, array);

    for(size_t i = start; i < end; i++)
    {
        string textOut = ident~"["~to!(string)(i)~"] = "~to!(string)(array[i]);
        writeln(textOut);
    }
}

public void dumpArray(T)(T[] array)
{
    dumpArray(array, 0, array.length);
}

unittest
{
    int[] test = [1,2,3];
    writeln("Should have 3 things (BEGIN)");
    dumpArray(test);
    writeln("Should have 3 things (END)");
}

unittest
{
    int[] test = [1,2,3];
    writeln("Should have nothing (BEGIN)");
    dumpArray(test, 0, 0);
    writeln("Should have nothing (END)");
}

unittest
{
    int[] test = [1,2,3];
    writeln("Should have 2 (BEGIN)");
    dumpArray(test, 1, 2);
    writeln("Should have 2 (END)");
}