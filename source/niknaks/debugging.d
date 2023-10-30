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
    dumpArray(test);
}