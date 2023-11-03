/**
 * Debugging tools
 */
module niknaks.debugging;

import std.traits : isArray, ForeachType;
import std.conv : to;

version(unittest)
{
    import std.stdio : writeln, write;
}

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
 * Tests the generation of a pattern
 */
unittest
{
    string pattern = "YOLO";
    size_t count = 2;

    string output = genX(count, pattern);
    assert(output == "YOLOYOLO");
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
 * Tests `genTabs(size_t)`
 */
unittest
{
    size_t count = 2;

    string output = genTabs(count);
    assert(output == "\t\t");
}

/** 
 * Dumps the provided array
 *
 * Params:
 *   array = the array to dump
 */
template dumpArray(alias array)
if(isArray!(typeof(array)))
{
    // Get the type of the array
    private alias symbolType = typeof(array);
    pragma(msg, "Symboltype: ", symbolType);

    // Get the arrays'e element type
    private alias elementType = ForeachType!(symbolType);
    pragma(msg, "Element type: ", elementType);

    // Get the array's name as a string
    private string ident = __traits(identifier, array);

    /** 
     * Dumps the array within the provided boundries
     *
     * Params:
     *   start = beginning index
     *   end = ending index
     * Returns: the formatted dump text
     */
    public string dumpArray(size_t start, size_t end, size_t depth = 0)
    {
        // String out
        string output;

        for(size_t i = start; i < end; i++)
        {
            string textOut;

            static if(isArray!(elementType) && !__traits(isSame, elementType, string))
            {
                textOut = (depth ? "":ident)~"["~to!(string)(i)~"] = ...";

                // Tab by depth
                textOut = genTabs(depth)~textOut;

                output ~= textOut~"\n";


                output ~= dumpArray_rec(array[i], 0, array[i].length, depth+1);
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
     * Dumps the entire array
     *
     * Returns: the formatted dump text
     */
    public string dumpArray()
    {
        return dumpArray!(array)(0, array.length);
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

/**
 * Test dumping an array of integers
 */
unittest
{
    int[] test = [1,2,3];
    writeln("Should have 3 things (BEGIN)");
    write(dumpArray!(test));
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
    write(dumpArray!(test)(0, 0));
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
    write(dumpArray!(test)(1, 2));
    writeln("Should have 2 (END)");
}

/**
 * Test dumping an array of integer
 * arrays
 */
unittest
{
    int[][] test = [ [1,2,3], [4,5,6]];
    write(dumpArray!(test));
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
    write(dumpArray!(test));
}

/**
 * Tests out the compile-time component-type
 * detection of `string` in any array of them
 */
unittest
{
    string[] stringArray = ["Hello", "world"];
    writeln(dumpArray!(stringArray));
}

/**
 * Tests the array-name dumping
 */
unittest
{
    int[] bruh = [1,2,3];
    string g = dumpArray!(bruh)();
    writeln(g);
}

/** 
 * Dumps a given array within the provided boundries
 *
 * This method is used internally for the recursive
 * call as it won't work with the template.
 *
 * Params:
 *   array = the array
 *   start = beginning index
 *   end = ending index
 * Returns: the formatted dump text
 */
private string dumpArray_rec(T)(T[] array, size_t start, size_t end, size_t depth = 0)
{
    // String out
    string output;

    // Obtain the array's name (symbol as-a-string)
    string ident = __traits(identifier, array);

    for(size_t i = start; i < end; i++)
    {
        string textOut;

        static if(isArray!(T) && !__traits(isSame, T, string))
        {
            textOut = (depth ? "":ident)~"["~to!(string)(i)~"] = ...";

            // Tab by depth
            textOut = genTabs(depth)~textOut;

            output ~= textOut~"\n";


            output ~= dumpArray_rec(array[i], 0, array[i].length, depth+1);
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

version(unittest)
{
    import std.stdio : writeln, write;
}