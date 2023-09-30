/** 
 * Arrays tooling
 */
module niknaks.arrays;

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
 * within the given array
 *
 * Params:
 *   used = the array of values
 * Returns: the free value
 */
public T findNextFree(T)(T[] used) if(__traits(isIntegral, T))
{
    T found;
    if(used.length == 0)
    {
        return 0;
    }
    else
    {
        found = 0;
        while(isPresent(used, found)) // FIXME: Constant loop if none available
        {
            found++;
        }

        return found;
    }
}

/**
 * Tests the `findNextFree!(T)(T[])` function
 *
 * Case: First value is free + non-empty array
 */
unittest
{
    ubyte[] values = [1,2,3];
    ubyte free = findNextFree(values);
    assert(isPresent(values, free) == false);
}

/**
 * Tests the `findNextFree!(T)(T[])` function
 *
 * Case: First value is unfree + non-empty array
 */
unittest
{
    ubyte[] values = [0,2,3];
    ubyte free = findNextFree(values);
    assert(isPresent(values, free) == false);
}

// TODO: Add support for , ref-based present and returns if found

// /**
//  * Tests the `findNextFree!(T)(T[])` function
//  *
//  * Case: First value is unfree + non-empty array
//  */
// unittest
// {
//     ubyte free = findNextFree([]]);
//     assert(isPresent(values, free) == false);
// }