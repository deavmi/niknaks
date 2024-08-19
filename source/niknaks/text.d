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