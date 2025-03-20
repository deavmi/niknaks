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
@safe @nogc
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

/** 
 * Shifts a subset of the elements of
 * the given array to a given position
 * either from the left or right.
 *
 * Optionally allowing the shrinking
 * of the array after the process,
 * otherwise the last element shifted's
 * previous value will be set to the
 * value specified.
 *
 * Params:
 *   array = the input array
 *   position = the position to shift 
 * onto
 *   rightwards = if `true` then shift
 * elements into the position rightwards,
 * else leftwards (which is also the default)
 *   shrink = if set to `true` then
 * the array will be resized to exclude
 * the now "empty" element
 *   filler = the value to place in
 * the space where the last element
 * shifted no longer occupies, by default
 * this is `T.init`
 * Returns: the shifted array
 */
public T[] shiftInto(T)(T[] array, size_t position, bool rightwards = false, bool shrink = false, T filler = T.init)
{
    // Out of range
    if(position >= array.length)
    {
        return array;
    }

    // if rightwards
    if(rightwards)
    {
        // nothing further left than index 0
        if(!position)
        {
            return array;
        }

        for(size_t i = position; i > 0; i--)
        {
            array[i] = array[i-1];
        }

        // no shrink, then fill with filler
        if(!shrink)
        {
            array[0] = filler;
        }
        // chomp left-hand side
        else
        {
            array = array[1..$];
        }
    }
    // if leftwards
    else
    {
        // nothing furtherright
        if(position == array.length-1)
        {
            return array;
        }

        for(size_t i = position; i < array.length-1; i++)
        {
            array[i] = array[i+1];
        }

        // no shrink, then fill with filler
        if(!shrink)
        {
            array[$-1] = filler;
        }
        // chomp right-hand side
        else
        {
            array = array[0..$-1];
        }
    }

    
    return array;
}

/** 
 * Rightwards shifting into
 *
 * See_Also: `shiftInto`
 */
public T[] shiftIntoRightwards(T)(T[] array, size_t position, bool shrink = false)
{
    return shiftInto(array, position, true, shrink);
}

/**
 * Tests the rightwards shifting
 */
unittest
{
    int[] numbas = [1, 5, 2];
    numbas = numbas.shiftIntoRightwards(1);

    // should now be [0, 1, 2]
    writeln(numbas);
    assert(numbas == [0, 1, 2]);

    numbas = [1, 5, 2];
    numbas = numbas.shiftIntoRightwards(0);

    // should now be [1, 5, 2]
    writeln(numbas);
    assert(numbas == [1, 5, 2]);
    
    numbas = [1, 5, 2];
    numbas = numbas.shiftIntoRightwards(2);

    // should now be [0, 1, 5]
    writeln(numbas);
    assert(numbas == [0, 1, 5]);

    numbas = [1, 2];
    numbas = numbas.shiftIntoRightwards(1);

    // should now be [0, 1]
    writeln(numbas);
    assert(numbas == [0, 1]);

    numbas = [1, 2];
    numbas = numbas.shiftIntoRightwards(0);

    // should now be [1, 2]
    writeln(numbas);
    assert(numbas == [1, 2]);

    numbas = [];
    numbas = numbas.shiftIntoRightwards(0);

    // should now be []
    writeln(numbas);
    assert(numbas == []);

    numbas = [1, 5, 2];
    numbas = numbas.shiftIntoRightwards(1, true);

    // should now be [1, 2]
    writeln(numbas);
    assert(numbas == [1, 2]);
}

/** 
 * Leftwards shifting into
 *
 * See_Also: `shiftInto`
 */
public T[] shiftIntoLeftwards(T)(T[] array, size_t position, bool shrink = false)
{
    return shiftInto(array, position, false, shrink);
}

/**
 * Tests the leftwards shifting
 */
unittest
{
    int[] numbas = [1, 5, 2];
    numbas = numbas.shiftIntoLeftwards(1);

    // should now be [1, 2, 0]
    writeln(numbas);
    assert(numbas == [1, 2, 0]);

    numbas = [1, 5, 2];
    numbas = numbas.shiftIntoLeftwards(0);

    // should now be [5, 2, 0]
    writeln(numbas);
    assert(numbas == [5, 2, 0]);
    
    numbas = [1, 5, 2];
    numbas = numbas.shiftIntoLeftwards(2);

    // should now be [1, 5, 2]
    writeln(numbas);
    assert(numbas == [1, 5, 2]);

    numbas = [];
    numbas = numbas.shiftIntoLeftwards(0);

    // should now be []
    writeln(numbas);
    assert(numbas == []);

    numbas = [1, 5, 2];
    numbas = numbas.shiftIntoLeftwards(1, true);

    // should now be [1, 2]
    writeln(numbas);
    assert(numbas == [1, 2]);
}

/** 
 * Removes the element at the
 * provided position in the
 * given array
 *
 * Params:
 *   array = the array
 *   position = position of
 * element to remove
 * Returns: the array
 */
public T[] removeResize(T)(T[] array, size_t position)
{
    return array.shiftInto(position, false, true);
}

/**
 * Tests removing an element from an array
 */
unittest
{
    int[] numbas = [1, 5, 2];
    numbas = numbas.removeResize(1);

    // should now be [1, 2]
    writeln(numbas);
    assert(numbas == [1, 2]);
}

/** 
 * Inserts the given value into
 * the array at the provided index
 *
 * Params:
 *   array = the array to insert
 * into
 *   position = the position to
 * insert at
 *   value = the value to insert
 * Returns: the updated array
 */
public T[] insertAt(T)(T[] array, size_t position, T value)
{
    if(position > array.length)
    {
        return array;
    }

    // Case: Right at end
    if(position == array.length)
    {
        array ~= value;
        return array;
    }
    // Anywhere else
    else
    {
        // Make space for a single new element
        array.length++;

        // Cha-cha to the right
        for(size_t i = array.length-1; i > position; i--)
        {
            array[i] = array[i-1];
        }

        // Overwrite
        array[position] = value;
        return array;
    }
}

/** 
 * Tests inserting into an array
 * at the given index
 */
unittest
{
    int[] vals = [];
    vals = vals.insertAt(0, 1);
    assert(vals == [1]);

    vals = vals.insertAt(0, 69);
    assert(vals == [69, 1]);

    vals = vals.insertAt(1, 68);
    assert(vals == [69, 68, 1]);

    vals = vals.insertAt(3, 420);
    assert(vals == [69, 68, 1, 420]);

    // Failure to insert (array stays the same)
    vals = vals.insertAt(5, 421);
    assert(vals == [69, 68, 1, 420]);
}

/** 
 * Returns a version of
 * the input array with
 * only unique elements.
 *
 * If the input array's
 * length is 0 or 1 then
 * it is immediately returned
 * as an optimization.
 *
 * Params:
 *   array = the input array
 * Returns: an array with
 * only unique elements
 */
@safe
public T[] unique(T)(T[] array)
{
    // optimize
    if(array.length == 0 || array.length == 1)
    {
        return array;
    }

    T[] newArray;
    foreach(T elem; array)
    {
        if(!isPresent(newArray, elem))
        {
            newArray ~= elem;
        }
    }

    return newArray;
}

/**
 * Tests out using the uniqueness method
 */
unittest
{
    // Empty or 1 elem should not re-allocate
    int[] vals = [];
    int[] newVals = unique(vals);
    assert(vals.ptr == newVals.ptr);

    vals = [1];
    newVals = unique(vals);
    assert(vals.ptr == newVals.ptr);

    // Copy triggering cases
    vals = [1,1];
    newVals = unique(vals);
    assert(newVals == [1]);
}


import std.range : isInputRange, ElementType;

/** 
 * Given an input range this will
 * copy all its elements into an 
 * array of the range's element
 * type
 *
 * Params:
 *   range = the input range
 * Returns: an array
 */
public ElementType!(T)[] toArray(T)(T range)
if(isInputRange!(T))
{
    ElementType!(T)[] a;
    while(!range.empty())
    {
        a ~= range.front();
        range.popFront();
    }
    return a;
}

/**
 * Tests out copying from an `SList`,
 * which is an input range
 */
unittest
{
    import std.container.slist : SList;
    SList!(int) r;
    r.insertAfter(r[], 1);
    r.insertAfter(r[], 12);
    r.insertAfter(r[], 123);

    assert(__traits(compiles, toArray(r[])));
    int[] a = toArray(r[]);
    assert(a == [1, 12, 123]);
}

/**
 * Tests out copying from an `DList`,
 * which is an input range
 */
unittest
{
    import std.container.dlist : DList;
    DList!(int) r;
    r.insertAfter(r[], 1);
    r.insertAfter(r[], 12);
    r.insertAfter(r[], 123);

    assert(__traits(compiles, toArray(r[])));
    int[] a = toArray(r[]);
    assert(a == [1, 12, 123]);
}