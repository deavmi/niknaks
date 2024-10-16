/** 
 * Template-oriented routiens
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