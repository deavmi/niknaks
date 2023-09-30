/**
 * Functional tooling
 */
module niknaks.functional;

template Predicate(T)
{
	alias Predicate = bool function(T);
}

version(unittest)
{
	bool isEven(int number)
	{
		return number%2==0;
	}
}

unittest
{
	Predicate!(int) pred = &isEven;

	assert(pred(0) == true);
	assert(pred(1) == false);
}
