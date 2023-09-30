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
 */
unittest
{
    ubyte[] values = [1,2,3];
    ubyte free = findNextFree(values);
    assert(isPresent(values, free) == false);
}

/** 
 * Converts the given integral value  to
 * its byte encoding
 *
 * Params:
 *   integral = the integral value
 * Returns: a `ubyte[]` of the value
 */
public ubyte[] toBytes(T)(T integral) if(__traits(isIntegral, T))
{
    ubyte[] bytes;

    static if(integral.sizeof == 1)
    {
        bytes = [cast(ubyte)integral];
    }
    else static if(integral.sizeof == 2)
    {
        ubyte* ptrBase = cast(ubyte*)&integral;
        bytes = [*ptrBase, *(ptrBase+1)];
    }
    else static if(integral.sizeof == 4)
    {
        ubyte* ptrBase = cast(ubyte*)&integral;
        bytes = [*ptrBase, *(ptrBase+1), *(ptrBase+2), *(ptrBase+3)];
    }
    else static if(integral.sizeof == 8)
    {
        ubyte* ptrBase = cast(ubyte*)&integral;
        bytes = [*ptrBase, *(ptrBase+1), *(ptrBase+2), *(ptrBase+3), *(ptrBase+4), *(ptrBase+5), *(ptrBase+6), *(ptrBase+7)];
    }
    else
    {
        pragma(msg, "toBytes cannot support integral types greater than 8 bytes");
        static assert(false);
    }
    
    return bytes;
}

/**
 * Tests the `toBytes!(T)(T)` function
 */
unittest
{
    version(LittleEndian)
    {
        ulong value = 1;
        ubyte[] bytes = toBytes(value);

        assert(bytes == [1, 0, 0, 0, 0, 0, 0, 0]);
    }
    else version(BigEndian)
    {
        ulong value = 1;
        ubyte[] bytes = toBytes(value);

        assert(bytes == [0, 0, 0, 0, 0, 0, 0, 1]);
    }
}