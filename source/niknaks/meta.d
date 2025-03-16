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

/** 
 * Determines if the
 * type `T` is a struct
 * type
 *
 * Returns: `true` if
 * so, `false` otherwise
 */
public bool isStructType(T)()
{
    // FIXME: This isn't the best test yet
    // Primtiive types I believe are POD, so we need to also exlcude those
    import std.traits : isBasicType;
    pragma(msg, __traits(isPOD, T));
    pragma(msg, !isBasicType!(T));
    return __traits(isPOD, T) && !isBasicType!(T);
}

public bool isVariadicArgsOf(T_should, VarArgs...)()
{
	pragma(msg, "All variadic args should be of type: '", T_should, "'");
	pragma(msg, "Variadic args: ", VarArgs);

	static foreach(va; VarArgs)
	{
		static if(!__traits(isSame, va, T_should))
		{
			pragma(msg, "Var-arg '", va, "' not of type '", T_should, "'");
			return false;
		}
	}
	
	return true;
}

/**
 * A function is implemented which
 * wants to ensure its variadic
 * arguments are all of the same
 * type.
 *
 * This tests out two positive cases
 * and one failing case.
 */
unittest
{
    enum SomeType
    {
        UM,
        DOIS,
        TRES,
        QUATRO
    }

    void myFunc(T...)(T, string somethingElse)
    if(isVariadicArgsOf!(SomeType, T)())
    {
        
    }
    static assert(__traits(compiles, myFunc(SomeType.UM, SomeType.DOIS, "Halo")));

    static assert(__traits(compiles, myFunc(SomeType.UM, "Halo")));
    static assert(!__traits(compiles, myFunc(1, "Halo")));
}