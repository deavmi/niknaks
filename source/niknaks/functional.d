/**
 * Functional tooling
 */
module niknaks.functional;

/** 
 * Predicate for testing an input type
 * against a condition and returning either
 * `true` or `false`
 *
 * Params:
 *    T = the input type
 */
template Predicate(T)
{
	/**
	 * Parameterized function pointer
	 * taking in `T` and returning
	 * either `true` or `false`
	 */
	alias Predicate = bool function(T);
}

version(unittest)
{
	private bool isEven(int number)
	{
		return number%2==0;
	}
}

/**
 * Uses a `Predicate` which tests
 * an integer input for evenness
 */
unittest
{
	Predicate!(int) pred = &isEven;

	assert(pred(0) == true);
	assert(pred(1) == false);
}

public class OptionalException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}

import std.traits : isAssignable;
import std.meta : AliasSeq;

template Optional(T, onEmptyGet = OptionalException, exceptionArgs...)
if(isAssignable!(Throwable, onEmptyGet) // && 
//    __traits(getVirtualMethods, onEmptyGet, "")[0]
  ) // TODO: Check for this() with arity of 1 and string
{
	public struct Optional
	{
		private T value;
		private bool isSet = false;

		this(T value)
		{
			set(value);
		}

		public void set(T value)
		{
			this.value = value;
			this.isSet = true;
		}

		public bool isPresent()
		{
			return isSet;
		}

		public T get()
		{
			if(!isPresent())
			{
				static if(exceptionArgs.length)
				{
					throw new onEmptyGet(exceptionArgs);
				}
				else
				{
					throw new onEmptyGet("Optional has no value yet get was called");
				}
			}

			return value;
		}
	}
}

unittest
{
	Optional!(int) d;
	assert(d.isPresent() == false);

	try
	{
		d.get();
		assert(false);
	}
	catch(OptionalException)
	{
		assert(true);
	}

	Optional!(byte) f = Optional!(byte)(1);
	assert(f.isPresent() == true);

	try
	{
		assert(1 == f.get());
	}
	catch(OptionalException)
	{
		assert(false);
	}
}