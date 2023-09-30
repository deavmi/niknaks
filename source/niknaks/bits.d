/**
 * Binary tooling
 */
module niknaks.bits;

version(unittest)
{
    import std.stdio : writeln;
}

/** 
 * Flips the given integral value
 *
 * Params:
 *   bytesIn = the integral value
 * Returns: the flipped integral
 */
public T flip(T)(T bytesIn) if(__traits(isIntegral, T))
{
    T copy = bytesIn;

    ubyte* base = (cast(ubyte*)&bytesIn)+T.sizeof-1;
    ubyte* baseCopy = cast(ubyte*)&copy;

    for(ulong idx = 0; idx < T.sizeof; idx++)
    {
        *(baseCopy+idx) = *(base-idx);
    }

    return copy;
}

/**
 * Tests the `flip!(T)(T)` function
 */
unittest
{
    version(BigEndian)
    {
        ushort i = 1;
        ushort flipped = flip(i);
        assert(flipped == 256);
    }
    else version(LittleEndian)
    {
        ushort i = 1;
        ushort flipped = flip(i);
        assert(flipped == 256);
    }
}

/** 
 * Ordering
 */
public enum Order
{
    /**
     * Little endian
     */
    LE,

    /**
     * Big endian
     */
    BE
}

/** 
 * Swaps the bytes to the given ordering but does a no-op
 * if the ordering requested is the same as that of the 
 * system's
 *
 * Params:
 *   bytesIn = the integral value to swap
 *   order = the byte ordering to request
 * Returns: the integral value
 */
public T order(T)(T bytesIn, Order order) if(__traits(isIntegral, T))
{
    version(LittleEndian)
    {
        if(order == Order.LE)
        {
            return bytesIn;
        }
        else
        {
            return flip(bytesIn);
        }
    }
    else version(BigEndian)
    {
        if(order == Order.BE)
        {
            return bytesIn;
        }
        else
        {
            return flip(bytesIn);
        }
    }
}

/**
 * Tests the `order!(T)(T, Order)`
 *
 * To Big Endian testing
 */
unittest
{
    version(LittleEndian)
    {
        ushort i = 1;
        writeln("Pre-order: ", i);
        ushort ordered = order(i, Order.BE);
        writeln("Post-order: ", ordered);
        assert(ordered == 256);
    }
    else version(BigEndian)
    {
        ushort i = 1;
        writeln("Pre-order: ", i);
        ushort ordered = order(i, Order.BE);
        writeln("Post-order: ", ordered);
        assert(ordered == i);
    }
}

/**
 * Tests the `order!(T)(T, Order)`
 *
 * To Little Endian testing
 */
unittest
{
    version(LittleEndian)
    {
        ushort i = 1;
        writeln("Pre-order: ", i);
        ushort ordered = order(i, Order.LE);
        writeln("Post-order: ", ordered);
        assert(ordered == i);
    }
    else version(BigEndian)
    {
        ushort i = 1;
        writeln("Pre-order: ", i);
        ushort ordered = order(i, Order.LE);
        writeln("Post-order: ", ordered);
        assert(ordered == 256);
    }
}