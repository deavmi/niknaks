/**
 * Debugging tools
 */
module niknaks.debugging;

import std.traits : isArray;
import std.conv : to;

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

/** 
 * Dumps a given array within the provided boundries
 *
 * Params:
 *   array = the array
 *   start = beginning index
 *   end = ending index
 * Returns: the formatted dump text
 */
public string dumpArray(T)(T[] array, size_t start, size_t end, size_t depth = 0)
{
    // String out
    string output;

    // Obtain the array's name (symbol as-a-string)
    string ident = __traits(identifier, array);

    for(size_t i = start; i < end; i++)
    {
        string textOut;

        static if(isArray!(T))
        {
            textOut = (depth ? "":ident)~"["~to!(string)(i)~"] = ...";

            // Tab by depth
            textOut = genTabs(depth)~textOut;

            output ~= textOut~"\n";


            output ~= dumpArray(array[i], 0, array[i].length, depth+1);
        }
        else
        {
            textOut = (depth ? "":ident)~"["~to!(string)(i)~"] = "~to!(string)(array[i]);

            // Tab by depth
            textOut = genTabs(depth)~textOut;

            output ~= textOut~"\n";
        }
    }

    return output;
}

/** 
 * Dumps a given array 
 *
 * Params:
 *   array = the array
 * Returns: the formatted dump text
 */
public string dumpArray(T)(T[] array)
{
    return dumpArray(array, 0, array.length);
}

version(unittest)
{
    import std.stdio : writeln, write;
}

/**
 * Test dumping an array of integers
 */
unittest
{
    int[] test = [1,2,3];
    writeln("Should have 3 things (BEGIN)");
    write(dumpArray(test));
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
    write(dumpArray(test, 0, 0));
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
    write(dumpArray(test, 1, 2));
    writeln("Should have 2 (END)");
}

/**
 * Test dumping an array of integer
 * arrays
 */
unittest
{
    int[][] test = [ [1,2,3], [4,5,6]];
    write(dumpArray(test));
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
    write(dumpArray(test));
}