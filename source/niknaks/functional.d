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
