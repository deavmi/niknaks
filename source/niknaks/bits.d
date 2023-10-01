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

/** 
 * Takes an array of bytes and dereferences
 * then to an integral of your choosing
 *
 * Params:
 *   T = the integral type to go to
 *   bytes = the bytes to copy
 * Returns: the integral but `0` if the
 * provided size would cause a overrun
 * read
 */
public T bytesToIntegral(T)(ubyte[] bytes) if(__traits(isIntegral, T))
{
    T value = 0;
    
    if(bytes.length >= T.sizeof)
    {
        value = *cast(T*)bytes.ptr;
    }

    return value;
}

unittest
{
    version(LittleEndian)
    {
        ubyte[] bytes = [1, 0];
        ushort to = bytesToIntegral!(ushort)(bytes);
        assert(to == 1);
    }
    else version(BigEndian)
    {
        ubyte[] bytes = [1, 0];
        ushort to = bytesToIntegral!(ushort)(bytes);
        assert(to == 256);
    }
}