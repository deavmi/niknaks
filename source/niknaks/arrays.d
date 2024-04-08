/** 
 * Arrays tooling
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module niknaks.arrays;

import niknaks.functional : Predicate;

/** 
 * Checks if the given value is present in
 * the given array
 *
 * Params:
 *   array = the array to check against
 *   value = the value to check prescence
 * for
 * Returns: `true` if present, `false`
 * otherwise
 */
public bool isPresent(T)(T[] array, T value)
{
    if(array.length == 0)
    {
        return false;
    }
    else
    {
        foreach(T cur; array)
        {
            if(cur == value)
            {
                return true;
            }
        }

        return false;
    }
}

/**
 * Tests the `isPresent!(T)(T[], T)` function
 *
 * Case: Non-empty array
 */
unittest
{
    ubyte[] values = [1,2,3];
    foreach(ubyte value; values)
    {
        assert(isPresent(values, value));
    }
    assert(isPresent(values, 0) == false);
    assert(isPresent(values, 5) == false);
}

/**
 * Tests the `isPresent!(T)(T[], T)` function
 *
 * Case: Empty array
 */
unittest
{
    assert(isPresent([], 1) == false);
}

/** 
 * Given an array of values this tries to find
 * the next free value of which is NOT present
 * within the given array.
 *
 * If the array provided is emptied then a value
 * will always be found and will be that of `T.init`.
 *
 * Params:
 *   used = the array of values
 *   found = the found free value
 * Returns: `true` if a free value was found
 * otherwise `false`
 */
@nogc
public bool findNextFree(T)(T[] used, ref T found) if(__traits(isIntegral, T))
{
    // Temporary value used for searching
    T tmp = T.init;

    // If the array is empty then the first
    // ... found value may as well be T.init
    if(used.length == 0)
    {
        found = tmp;
        return true;
    }
    else
    {
        // Is the starting value in use?
        // If it is increment it such that
        // ... looping infinite rule in the
        // ... upcoming while loop works
        // ... as expected
        if(isPresent(used, tmp))
        {
            tmp++;
        }
        // If not, then we found it
        else
        {
            found = tmp;
            return true;
        }

        // Loop till we hit starting value
        while(tmp != T.init)
        {
            if(isPresent(used, tmp))
            {
                tmp++;
            }
            else
            {
                found = tmp;
                return true;
            }
        }

        // We exited loop because we exhausted all possible values
        return false;
    }
}

/**
 * Tests the `findNextFree!(T)(T[], ref T)` function
 *
 * Case: First value is free + non-empty array
 */
unittest
{
    ubyte[] values = [1,2,3];

    ubyte free;
    bool status = findNextFree(values, free);
    assert(status == true);
    assert(isPresent(values, free) == false);
}

/**
 * Tests the `findNextFree!(T)(T[], ref T)` function
 *
 * Case: First value is unfree + non-empty array
 */
unittest
{
    ubyte[] values = [0,2,3];

    ubyte free;
    bool status = findNextFree(values, free);
    assert(status == true);
    assert(isPresent(values, free) == false);
}

/**
 * Tests the `findNextFree!(T)(T[], ref T)` function
 *
 * Case: Array is empty, first value should be T.init
 */
unittest
{
    ubyte[] values = [];

    ubyte free;
    bool status = findNextFree(values, free);
    assert(status == true);
    assert(free == ubyte.init);
    assert(isPresent(values, free) == false);
}

version(unittest)
{
    import std.stdio : writeln;
}

/**
 * Tests the `findNextFree!(T)(T[], ref T)` function
 *
 * Case: All values are unfree
 */
unittest
{
    // Populate entire array with 0 through 255
    ubyte[] values;
    static foreach(ushort val; 0..256)
    {
        values~=val;
    }
    writeln(values);

    ubyte free;
    bool status = findNextFree(values, free);
    assert(status == false);

    // Ensure none of the values are present
    foreach(ubyte i; values)
    {
        assert(isPresent(values, i) == true);
    }
}

/** 
 * Filters items by the given predicate
 *
 * Params:
 *   filterIn = the array to filer
 *   predicate = the predicate to use
 *   filterOut = output array
 */
public void filter(T)(T[] filterIn, Predicate!(T) predicate, ref T[] filterOut)
{
    foreach(T t; filterIn)
    {
        if(predicate(t))
        {
            filterOut ~= t;
        }
    }
}

version(unittest)
{
    import niknaks.functional : predicateOf;
}

/**
 * Tests the array filtering method
 */
unittest
{
    bool onlyEven(int i)
    {
        return i % 2 == 0;
    }

    int[] vals = [0, 1, 2, 3];
    
    int[] vals_expected = [0, 2];
    int[] vals_got;

    // TODO: See why not auto detecting the array type
    filter!(int)(vals, predicateOf!(onlyEven), vals_got);
    assert(vals_got == vals_expected);   
}