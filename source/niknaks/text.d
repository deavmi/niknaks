/**
 * Text manipulation
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module niknaks.text;

import std.string : join, format, split;

version(unittest)
{
    import std.stdio;
}

/** 
 * Generates a string containing
 * the provided pattern repeated
 * by the given number of times
 *
 * Params:
 *   count = the number of times
 * to repeat the pattern
 *   pattern = the pattern itself
 * Returns: the repeated pattern
 */
public string genX(size_t count, string pattern)
{
    string strOut;
    for(ubyte i = 0; i < count; i++)
    {
        strOut ~= pattern;
    }
    return strOut;
}

/**
 * Tests the generation of a pattern
 */
unittest
{
    string pattern = "YOLO";
    size_t count = 2;

    string output = genX(count, pattern);
    assert(output == "YOLOYOLO");
}

/** 
 * Generates a string containing
 * the number of tabs specified
 *
 * Params:
 *   count = the number of tabs
 * Returns: the tabbed string
 */
public string genTabs(size_t count)
{
    return genX(count, "\t");
}

/**
 * Tests `genTabs(size_t)`
 */
unittest
{
    size_t count = 2;

    string output = genTabs(count);
    assert(output == "\t\t");
}

/** 
 * Pads the left-hand margin of a multi-line
 * string with the given text
 *
 * Params:
 *   bodyText = the text to pad
 *   withText = the padding text
 * Returns: the padded text
 */
public string padLeft(string bodyText, string withText)
{
    string[] lines_out;
    string[] lines_in = split(bodyText, "\n");
    foreach(string l; lines_in)
    {
        lines_out ~= format("%s%s", withText, l);
    }

    return join(lines_out, "\n");
}


/**
 * Tests out the left-padding of text
 * with a custom text segment
 */
unittest
{
    string input = `Hello
World
`;

    string output = padLeft(input, "%");

    string[] output_segments = output.split("\n");
    writeln(output_segments);
    assert(output_segments[0] == "%Hello");
    assert(output_segments[1] == "%World");
    assert(output_segments[2] == "%");
}