/** 
 * Template-oriented routines
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module niknaks.meta;

/** 
 * Determines if the
 * type `T` is a class
 * type
 *
 * Returns: `true` if
 * so, `false` otherwise
 */
public bool isClassType(T)()
{
    return __traits(compiles, __traits(classInstanceSize, T));
}

public bool isStructType(T)()
{
    // FIXME: This isn't the best test yet
    // Primtiive types I believe are POD, so we need to also exlcude those
    import std.traits : isBasicType;
    pragma(msg, __traits(isPOD, T));
    pragma(msg, !isBasicType!(T));
    return __traits(isPOD, T) && !isBasicType!(T);
}