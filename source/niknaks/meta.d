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
 * Checking if a given data type
 * is a class type
 */
unittest
{
	int g;
	string[] arr;

	enum D
	{
		J
	}

	struct F
	{
		
	}

	class C
	{
		public void f()
		{
			
		}
	}

	assert(isClassType!(int) == false);
	assert(isClassType!(D) == false);
	assert(isClassType!(F) == false);
	assert(isClassType!(string[]) == false);
	assert(isClassType!(C) == true);	
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
    // Primtiive types I believe are POD, so we need to also exlcude those
    import std.traits : isBasicType, isArray;
    pragma(msg, T, "::isPOD: ", __traits(isPOD, T));
    pragma(msg, T, "::isBasicType: ", isBasicType!(T));
    pragma(msg, T, "::isArray: ", isArray!(T));
    pragma(msg, T, "::isClassType: ", isClassType!(T));



    // POD: struct, string, array of string, class
    // NOT: Basic type, means struct, class and
    // string[]
    // hence, we need to also add !isArray!(T),
    // then only struct and class left, so we
    // need !isClassType!(T)
    return
    		__traits(isPOD, T) &&
    		!isBasicType!(T) &&
    		!isArray!(T) &&
    		!isClassType!(T);
}

/**
 * Checking if a given data type
 * is a struct type
 */
unittest
{
	int g;
	string[] arr;

	enum D
	{
		J
	}

	struct F
	{
		
	}

	class C
	{
		public void f()
		{
			
		}
	}

	assert(isStructType!(int) == false);
	assert(isStructType!(D) == false);
	assert(isStructType!(F) == true);
	assert(isStructType!(string[]) == false);
	assert(isStructType!(C) == false);
}

/** 
 * Ensures that the given variadic arguments
 * are all of the given type
 *
 * Returns: `true` if so, `false` otherwise
 */
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
