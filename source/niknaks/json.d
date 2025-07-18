/**
  * JSON-related routines
  *
  * Authors: Tristan Brice Velloza Kildaire (deavmi)
  */
module niknaks.json;

import std.json : JSONValue;

/**
 * Given a dot-path in the form of `x.y.z`
 * this will traverse the given JSON document
 * starting from `start` and accessing the
 * first node at `x`, then recursing with
 * that node in order to access the node
 * at `y` etc.
 *
 * Params:
 *   path = the dot-path
 *   start = the starting node
 * Returns: the pointer to the found `JSONValue`
 * if found, else `null`
 */
public JSONValue* traverseTo(string path, JSONValue* start)
{
    if(start is null)
    {
        return null;
    }

    import std.string : split, indexOf;

    // no dots `.` in the name
    if(indexOf(path, ".") < 0)
    {
        JSONValue* p = path in *start;

        return p;
    }
    // if there are dots present like `x.y`
    else
    {
        string[] cmps = split(path, ".");

        JSONValue* root = cmps[0] in *start;

        // todo: range check?
        string[] rem = cmps[1..$];
        import std.string : join;

        return traverseTo(join(rem, "."), root);
    }
}

private version(unittest)
{
    import std.json : parseJSON;
}

/**
 * Tests out the traversing of
 * a JSON data structure
 */
unittest
{
    JSONValue z_node = parseJSON("1");

    JSONValue y_node;
    y_node["z"] = z_node;

    JSONValue x_node;
    x_node["y"] = y_node;

    JSONValue root;
    root["x"] = x_node;

    auto f = traverseTo("x.y.z", &root);
    assert(f);
    assert(f.integer() == 1);
}