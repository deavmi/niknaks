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

/** 
 * Optionals for a given type and 
 * with a customizable exception
 * to be thrown when a value is
 * not present and `get()` is
 * called.
 *
 * Params:
 *    T = the value type
 *    onEmptyGet = the `Throwable`
 * to be called when `get()` is
 * called and no value is present
 */
template Optional(T, onEmptyGet = OptionalException, exceptionArgs...)
if(isAssignable!(Throwable, onEmptyGet) // && 
//    __traits(getVirtualMethods, onEmptyGet, "")[0]
  ) // TODO: Check for this() with arity of 1 and string
{
	public struct Optional
	{
		private T value;
		private bool isSet = false;

		/** 
		 * Constructs an optional with
		 * the value already set
		 *
		 * Params:
		 *   value = the value to set
		 */
		this(T value)
		{
			set(value);
		}

		/** 
		 * Sets the optional's value
		 *
		 * Params:
		 *   value = the value to set
		 */
		public void set(T value)
		{
			this.value = value;
			this.isSet = true;
		}

		/** 
		 * Checks if a value is present
		 * or not
		 *
		 * Returns: `true` if present,
		 * otherwise `false`
		 */
		public bool isPresent()
		{
			return isSet;
		}

		/** 
		 * Returns the value of this
		 * optional if it is set. If
		 * not set then an exception
		 * is thrown.
		 *
		 * Returns: the value
		 * Throws:
		 *    Throwable if no value
		 * is present
		 */
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

/**
 * Creating an `Optional!(T)` with no 
 * value present and then trying to
 * get the value, which results in
 * an exception
 */
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
}

/**
 * Creating an `Optional!(T)` with a
 * value present and then trying to
 * get the value, which results in
 * said value being returned
 */
unittest
{
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