// Written in the D programming language.

/**
 * Templates to manipulate
 * $(DDSUBLINK spec/template, variadic-templates, template parameter sequences)
 * (also known as $(I alias sequences)).
 *
 * Some operations on alias sequences are built into the language,
 * such as `S[i]`, which accesses the element at index `i` in the
 * sequence. `S[low .. high]` returns a new alias
 * sequence that is a slice of the old one.
 *
 * For more information, see $(DDLINK ctarguments, Compile-time Sequences, Compile-time Sequences).
 *
 * $(B Note:) Several templates in this module use or operate on eponymous templates that
 * take a single argument and evaluate to a boolean constant. Such templates
 * are referred to as $(I template predicates).
 *
 * $(SCRIPT inhibitQuickIndex = 1;)
 * $(DIVC quickindex,
 * $(BOOKTABLE ,
 * $(TR $(TH Category) $(TH Templates))
 * $(TR $(TD Building blocks) $(TD
 *           $(LREF Alias)
 *           $(LREF AliasSeq)
 *           $(LREF aliasSeqOf)
 * ))
 * $(TR $(TD Alias sequence filtering) $(TD
 *           $(LREF Erase)
 *           $(LREF EraseAll)
 *           $(LREF Filter)
 *           $(LREF NoDuplicates)
 *           $(LREF Stride)
 * ))
 * $(TR $(TD Alias sequence type hierarchy) $(TD
 *           $(LREF DerivedToFront)
 *           $(LREF MostDerived)
 * ))
 * $(TR $(TD Alias sequence transformation) $(TD
 *           $(LREF Repeat)
 *           $(LREF Replace)
 *           $(LREF ReplaceAll)
 *           $(LREF Reverse)
 *           $(LREF staticMap)
 *           $(LREF staticSort)
 * ))
 * $(TR $(TD Alias sequence searching) $(TD
 *           $(LREF allSatisfy)
 *           $(LREF anySatisfy)
 *           $(LREF staticIndexOf)
 * ))
 * $(TR $(TD Template predicates) $(TD
 *           $(LREF templateAnd)
 *           $(LREF templateNot)
 *           $(LREF templateOr)
 *           $(LREF staticIsSorted)
 * ))
 * $(TR $(TD Template instantiation) $(TD
 *           $(LREF ApplyLeft)
 *           $(LREF ApplyRight)
 *           $(LREF Instantiate)
 * ))
 * ))
 *
 * References:
 *  Based on ideas in Table 3.1 from
 *  $(LINK2 http://amazon.com/exec/obidos/ASIN/0201704315/ref=ase_classicempire/102-2957199-2585768,
 *      Modern C++ Design),
 *   Andrei Alexandrescu (Addison-Wesley Professional, 2001)
 * Copyright: Copyright The D Language Foundation 2005 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 *     $(HTTP digitalmars.com, Walter Bright),
 *     $(HTTP klickverbot.at, David Nadlinger)
 * Source:    $(PHOBOSSRC std/meta.d)
 */

module ripstd.meta;

import ripstd.traits : isAggregateType, Unqual, isIterable;
import ripstd.range.primitives : isInfinite;

/**
 * Creates a sequence of zero or more aliases. This is most commonly
 * used as template parameters or arguments.
 *
 * In previous versions of Phobos, this was known as `TypeTuple`.
 */
alias AliasSeq(TList...) = TList;

///
@safe unittest
{
    import ripstd.meta;
    alias TL = AliasSeq!(int, double);

    int foo(TL td)  // same as int foo(int, double);
    {
        return td[0] + cast(int) td[1];
    }
}

///
@safe unittest
{
    alias TL = AliasSeq!(int, double);

    alias Types = AliasSeq!(TL, char);
    static assert(is(Types == AliasSeq!(int, double, char)));
}


///
@safe unittest
{
    // Creates a compile-time sequence of function call expressions
    // that each call `func` with the next variadic template argument
    template Map(alias func, args...)
    {
        auto ref lazyItem() {return func(args[0]);}

        static if (args.length == 1)
        {
            alias Map = lazyItem;
        }
        else
        {
            // recurse
            alias Map = AliasSeq!(lazyItem, Map!(func, args[1 .. $]));
        }
    }

    static void test(int a, int b)
    {
        assert(a == 4);
        assert(b == 16);
    }

    static int a = 2;
    static int b = 4;

    test(Map!(i => i ^^ 2, a, b));
    assert(a == 2);
    assert(b == 4);

    test(Map!((ref i) => i *= i, a, b));
    assert(a == 4);
    assert(b == 16);

    static void testRef(ref int a, ref int b)
    {
        assert(a++ == 16);
        assert(b++ == 256);
    }

    testRef(Map!(function ref(ref i) => i *= i, a, b));
    assert(a == 17);
    assert(b == 257);
}

/**
 * Allows `alias`ing of any single symbol, type or compile-time expression.
 *
 * Not everything can be directly aliased. An alias cannot be declared
 * of - for example - a literal:
 * ---
 * alias a = 4; //Error
 * ---
 * With this template any single entity can be aliased:
 * ---
 * alias b = Alias!4; //OK
 * ---
 * See_Also:
 * To alias more than one thing at once, use $(LREF AliasSeq).
 */
alias Alias(alias a) = a;

/// Ditto
alias Alias(T) = T;

///
@safe unittest
{
    // Without Alias this would fail if Args[0] was e.g. a value and
    // some logic would be needed to detect when to use enum instead
    alias Head(Args...) = Alias!(Args[0]);
    alias Tail(Args...) = Args[1 .. $];

    alias Blah = AliasSeq!(3, int, "hello");
    static assert(Head!Blah == 3);
    static assert(is(Head!(Tail!Blah) == int));
    static assert((Tail!Blah)[1] == "hello");
}

///
@safe unittest
{
    alias a = Alias!(123);
    static assert(a == 123);

    enum abc = 1;
    alias b = Alias!(abc);
    static assert(b == 1);

    alias c = Alias!(3 + 4);
    static assert(c == 7);

    alias concat = (s0, s1) => s0 ~ s1;
    alias d = Alias!(concat("Hello", " World!"));
    static assert(d == "Hello World!");

    alias e = Alias!(int);
    static assert(is(e == int));

    alias f = Alias!(AliasSeq!(int));
    static assert(!is(typeof(f[0]))); //not an AliasSeq
    static assert(is(f == int));

    auto g = 6;
    alias h = Alias!g;
    ++h;
    assert(g == 7);
}

package template OldAlias(alias a)
{
    static if (__traits(compiles, { alias x = a; }))
        alias OldAlias = a;
    else static if (__traits(compiles, { enum x = a; }))
        enum OldAlias = a;
    else
        static assert(0, "Cannot alias " ~ a.stringof);
}

package template OldAlias(T)
if (!isAggregateType!T || is(Unqual!T == T))
{
    alias OldAlias = T;
}

@safe unittest
{
    static struct Foo {}
    //static assert(is(OldAlias!(const(Foo)) == const Foo));
    static assert(is(OldAlias!(const(int)) == const(int)));
    static assert(OldAlias!123 == 123);
    enum abc = 123;
    static assert(OldAlias!abc == 123);
}

/**
 * Returns the index of the first occurrence of `args[0]` in the
 * sequence `args[1 .. $]`. `args` may be types or compile-time values.
 * If not found, `-1` is returned.
 */
template staticIndexOf(args...)
if (args.length >= 1)
{
    enum staticIndexOf =
    {
        static foreach (idx, arg; args[1 .. $])
            static if (isSame!(args[0], arg))
                // `if (__ctfe)` is redundant here but avoids the "Unreachable code" warning.
                if (__ctfe) return idx;
        return -1;
    }();
}

///
@safe unittest
{
    import ripstd.stdio;

    void foo()
    {
        writefln("The index of long is %s",
                 staticIndexOf!(long, AliasSeq!(int, long, double)));
        // prints: The index of long is 1
    }
}

@safe unittest
{
    static assert(staticIndexOf!( byte, byte, short, int, long) ==  0);
    static assert(staticIndexOf!(short, byte, short, int, long) ==  1);
    static assert(staticIndexOf!(  int, byte, short, int, long) ==  2);
    static assert(staticIndexOf!( long, byte, short, int, long) ==  3);
    static assert(staticIndexOf!( char, byte, short, int, long) == -1);
    static assert(staticIndexOf!(   -1, byte, short, int, long) == -1);
    static assert(staticIndexOf!(void) == -1);

    static assert(staticIndexOf!("abc", "abc", "def", "ghi", "jkl") ==  0);
    static assert(staticIndexOf!("def", "abc", "def", "ghi", "jkl") ==  1);
    static assert(staticIndexOf!("ghi", "abc", "def", "ghi", "jkl") ==  2);
    static assert(staticIndexOf!("jkl", "abc", "def", "ghi", "jkl") ==  3);
    static assert(staticIndexOf!("mno", "abc", "def", "ghi", "jkl") == -1);
    static assert(staticIndexOf!( void, "abc", "def", "ghi", "jkl") == -1);
    static assert(staticIndexOf!(42) == -1);

    static assert(staticIndexOf!(void, 0, "void", void) == 2);
    static assert(staticIndexOf!("void", 0, void, "void") == 2);
}

/**
 * Returns an `AliasSeq` created from TList with the first occurrence,
 * if any, of T removed.
 */
template Erase(T, TList...)
{
    alias Erase = GenericErase!(T, TList).result;
}

/// Ditto
template Erase(alias T, TList...)
{
    alias Erase = GenericErase!(T, TList).result;
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, long, double, char);
    alias TL = Erase!(long, Types);
    static assert(is(TL == AliasSeq!(int, double, char)));
}

// [internal]
private template GenericErase(args...)
if (args.length >= 1)
{
    alias e     = OldAlias!(args[0]);
    alias tuple = args[1 .. $] ;

    static if (tuple.length)
    {
        alias head = OldAlias!(tuple[0]);
        alias tail = tuple[1 .. $];

        static if (isSame!(e, head))
            alias result = tail;
        else
            alias result = AliasSeq!(head, GenericErase!(e, tail).result);
    }
    else
    {
        alias result = AliasSeq!();
    }
}

@safe unittest
{
    static assert(Pack!(Erase!(int,
                short, int, int, 4)).
        equals!(short,      int, 4));

    static assert(Pack!(Erase!(1,
                real, 3, 1, 4, 1, 5, 9)).
        equals!(real, 3,    4, 1, 5, 9));
}


/**
 * Returns an `AliasSeq` created from TList with the all occurrences,
 * if any, of T removed.
 */
template EraseAll(T, TList...)
{
    alias EraseAll = GenericEraseAll!(T, TList).result;
}

/// Ditto
template EraseAll(alias T, TList...)
{
    alias EraseAll = GenericEraseAll!(T, TList).result;
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, long, long, int);

    alias TL = EraseAll!(long, Types);
    static assert(is(TL == AliasSeq!(int, int)));
}

// [internal]
private template GenericEraseAll(args...)
if (args.length >= 1)
{
    alias e     = OldAlias!(args[0]);
    alias tuple = args[1 .. $];

    static if (tuple.length)
    {
        alias head = OldAlias!(tuple[0]);
        alias tail = tuple[1 .. $];
        alias next = AliasSeq!(
            GenericEraseAll!(e, tail[0..$/2]).result,
            GenericEraseAll!(e, tail[$/2..$]).result
            );

        static if (isSame!(e, head))
            alias result = next;
        else
            alias result = AliasSeq!(head, next);
    }
    else
    {
        alias result = AliasSeq!();
    }
}

@safe unittest
{
    static assert(Pack!(EraseAll!(int,
                short, int, int, 4)).
        equals!(short,           4));

    static assert(Pack!(EraseAll!(1,
                real, 3, 1, 4, 1, 5, 9)).
        equals!(real, 3,    4,    5, 9));
}

/*
 * Erase any occurrence of the first `TList[0 .. N]` elements from `TList[N .. $]`.
 *
 * Params:
 *   N = number of elements to delete from the `TList`
 *   TList = sequence of aliases
 *
 * See_Also: $(LREF EraseAll)
 */
private template EraseAllN(uint N, TList...)
{
    static if (N == 1)
    {
        alias EraseAllN = EraseAll!(TList[0], TList[1 .. $]);
    }
    else
    {
        static if (N & 1)
            alias EraseAllN = EraseAllN!(N / 2, TList[N / 2 + 1 .. N],
                    EraseAllN!(N / 2 + 1, TList[0 .. N / 2 + 1], TList[N .. $]));
        else
            alias EraseAllN = EraseAllN!(N / 2, TList[N / 2 .. N],
                    EraseAllN!(N / 2, TList[0 .. N / 2], TList[N .. $]));
    }
}

/**
 * Returns an `AliasSeq` created from TList with the all duplicate
 * types removed.
 */
template NoDuplicates(TList...)
{
    static if (TList.length >= 2)
    {
        alias fst = NoDuplicates!(TList[0 .. $/2]);
        alias snd = NoDuplicates!(TList[$/2 .. $]);
        alias NoDuplicates = AliasSeq!(fst, EraseAllN!(fst.length, fst, snd));
    }
    else
    {
        alias NoDuplicates = TList;
    }
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, long, long, int, float);

    alias TL = NoDuplicates!(Types);
    static assert(is(TL == AliasSeq!(int, long, float)));
}

@safe unittest
{
    import ripstd.range : iota;

    // https://issues.dlang.org/show_bug.cgi?id=14561: huge enums
    alias LongList = Repeat!(1500, int);
    static assert(NoDuplicates!LongList.length == 1);
    // https://issues.dlang.org/show_bug.cgi?id=17995: huge enums, revisited

    alias a = NoDuplicates!(AliasSeq!(1, Repeat!(1000, 3)));
    alias b = NoDuplicates!(AliasSeq!(1, Repeat!(10, 3)));
    static assert(a.length == b.length);

    static assert(NoDuplicates!(aliasSeqOf!(iota(7)), aliasSeqOf!(iota(7))) == aliasSeqOf!(iota(7)));
    static assert(NoDuplicates!(aliasSeqOf!(iota(8)), aliasSeqOf!(iota(8))) == aliasSeqOf!(iota(8)));
}

@safe unittest
{
    static assert(
        Pack!(
            NoDuplicates!(1, int, 1, NoDuplicates, int, NoDuplicates, real))
        .equals!(1, int,    NoDuplicates,                    real));
}


/**
 * Returns an `AliasSeq` created from TList with the first occurrence
 * of T, if found, replaced with U.
 */
template Replace(T, U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

/// Ditto
template Replace(alias T, U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

/// Ditto
template Replace(T, alias U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

/// Ditto
template Replace(alias T, alias U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, long, long, int, float);

    alias TL = Replace!(long, char, Types);
    static assert(is(TL == AliasSeq!(int, char, long, int, float)));
}

// [internal]
private template GenericReplace(args...)
if (args.length >= 2)
{
    alias from  = OldAlias!(args[0]);
    alias to    = OldAlias!(args[1]);
    alias tuple = args[2 .. $];

    static if (tuple.length)
    {
        alias head = OldAlias!(tuple[0]);
        alias tail = tuple[1 .. $];

        static if (isSame!(from, head))
            alias result = AliasSeq!(to, tail);
        else
            alias result = AliasSeq!(head,
                GenericReplace!(from, to, tail).result);
    }
    else
    {
        alias result = AliasSeq!();
    }
 }

@safe unittest
{
    static assert(Pack!(Replace!(byte, ubyte,
                short,  byte, byte, byte)).
        equals!(short, ubyte, byte, byte));

    static assert(Pack!(Replace!(1111, byte,
                2222, 1111, 1111, 1111)).
        equals!(2222, byte, 1111, 1111));

    static assert(Pack!(Replace!(byte, 1111,
                short, byte, byte, byte)).
        equals!(short, 1111, byte, byte));

    static assert(Pack!(Replace!(1111, "11",
                2222, 1111, 1111, 1111)).
        equals!(2222, "11", 1111, 1111));
}

/**
 * Returns an `AliasSeq` created from TList with all occurrences
 * of T, if found, replaced with U.
 */
template ReplaceAll(T, U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

/// Ditto
template ReplaceAll(alias T, U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

/// Ditto
template ReplaceAll(T, alias U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

/// Ditto
template ReplaceAll(alias T, alias U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, long, long, int, float);

    alias TL = ReplaceAll!(long, char, Types);
    static assert(is(TL == AliasSeq!(int, char, char, int, float)));
}

// [internal]
private template GenericReplaceAll(args...)
if (args.length >= 2)
{
    alias from  = OldAlias!(args[0]);
    alias to    = OldAlias!(args[1]);
    alias tuple = args[2 .. $];

    static if (tuple.length)
    {
        alias head = OldAlias!(tuple[0]);
        alias tail = tuple[1 .. $];
        alias next = GenericReplaceAll!(from, to, tail).result;

        static if (isSame!(from, head))
            alias result = AliasSeq!(to, next);
        else
            alias result = AliasSeq!(head, next);
    }
    else
    {
        alias result = AliasSeq!();
    }
}

@safe unittest
{
    static assert(Pack!(ReplaceAll!(byte, ubyte,
                 byte, short,  byte,  byte)).
        equals!(ubyte, short, ubyte, ubyte));

    static assert(Pack!(ReplaceAll!(1111, byte,
                1111, 2222, 1111, 1111)).
        equals!(byte, 2222, byte, byte));

    static assert(Pack!(ReplaceAll!(byte, 1111,
                byte, short, byte, byte)).
        equals!(1111, short, 1111, 1111));

    static assert(Pack!(ReplaceAll!(1111, "11",
                1111, 2222, 1111, 1111)).
        equals!("11", 2222, "11", "11"));
}

/**
 * Returns an `AliasSeq` created from TList with the order reversed.
 */
template Reverse(TList...)
{
    static if (TList.length <= 1)
    {
        alias Reverse = TList;
    }
    /* Cases 2 to 8 are to speed up compile times
     */
    else static if (TList.length == 2)
    {
        alias Reverse = AliasSeq!(TList[1], TList[0]);
    }
    else static if (TList.length == 3)
    {
        alias Reverse = AliasSeq!(TList[2], TList[1], TList[0]);
    }
    else static if (TList.length == 4)
    {
        alias Reverse = AliasSeq!(TList[3], TList[2], TList[1], TList[0]);
    }
    else static if (TList.length == 5)
    {
        alias Reverse = AliasSeq!(TList[4], TList[3], TList[2], TList[1], TList[0]);
    }
    else static if (TList.length == 6)
    {
        alias Reverse = AliasSeq!(TList[5], TList[4], TList[3], TList[2], TList[1], TList[0]);
    }
    else static if (TList.length == 7)
    {
        alias Reverse = AliasSeq!(TList[6], TList[5], TList[4], TList[3], TList[2], TList[1], TList[0]);
    }
    else static if (TList.length == 8)
    {
        alias Reverse = AliasSeq!(TList[7], TList[6], TList[5], TList[4], TList[3], TList[2], TList[1], TList[0]);
    }
    else
    {
        alias Reverse =
            AliasSeq!(
                Reverse!(TList[$/2 ..  $ ]),
                Reverse!(TList[ 0  .. $/2]));
    }
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, long, long, int, float, byte, ubyte, short, ushort, uint);

    alias TL = Reverse!(Types);
    static assert(is(TL == AliasSeq!(uint, ushort, short, ubyte, byte, float, int, long, long, int)));
}

/**
 * Returns the type from TList that is the most derived from type T.
 * If none are found, T is returned.
 */
template MostDerived(T, TList...)
{
    static if (TList.length == 0)
        alias MostDerived = T;
    else static if (is(TList[0] : T))
        alias MostDerived = MostDerived!(TList[0], TList[1 .. $]);
    else
        alias MostDerived = MostDerived!(T, TList[1 .. $]);
}

///
@safe unittest
{
    class A { }
    class B : A { }
    class C : B { }
    alias Types = AliasSeq!(A, C, B);

    MostDerived!(Object, Types) x;  // x is declared as type C
    static assert(is(typeof(x) == C));
}

/**
 * Returns an `AliasSeq` with the elements of TList sorted so that the most
 * derived types come first.
 */
template DerivedToFront(TList...)
{
    static if (TList.length == 0)
        alias DerivedToFront = TList;
    else
        alias DerivedToFront =
            AliasSeq!(MostDerived!(TList[0], TList[1 .. $]),
                       DerivedToFront!(ReplaceAll!(MostDerived!(TList[0], TList[1 .. $]),
                                TList[0],
                                TList[1 .. $])));
}

///
@safe unittest
{
    class A { }
    class B : A { }
    class C : B { }
    alias Types = AliasSeq!(A, C, B);

    alias TL = DerivedToFront!(Types);
    static assert(is(TL == AliasSeq!(C, B, A)));
}

private enum staticMapExpandFactor = 150;
private string generateCases()
{
    string[staticMapExpandFactor] chunks;
    chunks[0] = q{};
    static foreach (enum i; 0 .. staticMapExpandFactor - 1)
        chunks[i + 1] = chunks[i] ~ `F!(Args[` ~ i.stringof ~ `]),`;
    string ret = `AliasSeq!(`;
    foreach (chunk; chunks)
        ret ~= `q{alias staticMap = AliasSeq!(` ~ chunk ~ `);},`;
    return ret ~ `)`;
}
private alias staticMapBasicCases = AliasSeq!(mixin(generateCases()));

/**
Evaluates to $(D AliasSeq!(F!(T[0]), F!(T[1]), ..., F!(T[$ - 1]))).
 */
template staticMap(alias F, Args ...)
{
    static if (Args.length < staticMapExpandFactor)
        mixin(staticMapBasicCases[Args.length]);
    else
        alias staticMap = AliasSeq!(staticMap!(F, Args[0 .. $/2]), staticMap!(F, Args[$/2 .. $]));
}

///
@safe unittest
{
    import ripstd.traits : Unqual;
    alias TL = staticMap!(Unqual, int, const int, immutable int, uint, ubyte, byte, short, ushort);
    static assert(is(TL == AliasSeq!(int, int, int, uint, ubyte, byte, short, ushort)));
}

@safe unittest
{
    import ripstd.traits : Unqual;

    // empty
    alias Empty = staticMap!(Unqual);
    static assert(Empty.length == 0);

    // single
    alias Single = staticMap!(Unqual, const int);
    static assert(is(Single == AliasSeq!int));

    alias T = staticMap!(Unqual, int, const int, immutable int, uint, ubyte, byte, short, ushort, long);
    static assert(is(T == AliasSeq!(int, int, int, uint, ubyte, byte, short, ushort, long)));
}

// regression test for https://issues.dlang.org/show_bug.cgi?id=21088
@system unittest // typeid opEquals is @system
{
    enum getTypeId(T) = typeid(T);
    alias A = staticMap!(getTypeId, int);

    assert(A == typeid(int));
}

/**
Tests whether all given items satisfy a template predicate, i.e. evaluates to
$(D F!(T[0]) && F!(T[1]) && ... && F!(T[$ - 1])).

Evaluation is $(I not) short-circuited if a false result is encountered; the
template predicate must be instantiable with all the given items.
 */
template allSatisfy(alias F, T...)
{
    import core.internal.traits : allSat = allSatisfy;
    alias allSatisfy = allSat!(F, T);
}

///
@safe unittest
{
    import ripstd.traits : isIntegral;

    static assert(!allSatisfy!(isIntegral, int, double));
    static assert( allSatisfy!(isIntegral, int, long));
}

/**
Tests whether any given items satisfy a template predicate, i.e. evaluates to
$(D F!(T[0]) || F!(T[1]) || ... || F!(T[$ - 1])).

Evaluation is short-circuited if a true result is encountered; the
template predicate must be instantiable with one of the given items.
 */
template anySatisfy(alias F, T...)
{
    import core.internal.traits : anySat = anySatisfy;
    alias anySatisfy = anySat!(F, T);
}

///
@safe unittest
{
    import ripstd.traits : isIntegral;

    static assert(!anySatisfy!(isIntegral, string, double));
    static assert( anySatisfy!(isIntegral, int, double));
}

private alias FilterShortCode = AliasSeq!(
    q{
        alias Filter = Nothing;
    },
    q{
        static if (pred!(TList[0]))
            alias Filter = AliasSeq!(TList[0]);
        else
            alias Filter = Nothing;
    },
    q{
        static if (pred!(TList[0]))
        {
            static if (pred!(TList[1]))
                alias Filter = AliasSeq!(TList[0], TList[1]);
            else
                alias Filter = AliasSeq!(TList[0]);
        }
        else
        {
            static if (pred!(TList[1]))
                alias Filter = AliasSeq!(TList[1]);
            else
                alias Filter = Nothing;
        }
    },
    q{
        static if (pred!(TList[0]))
        {
            static if (pred!(TList[1]))
            {
                static if (pred!(TList[2]))
                    alias Filter = AliasSeq!(TList[0], TList[1], TList[2]);
                else
                    alias Filter = AliasSeq!(TList[0], TList[1]);
            }
            else
            {
                static if (pred!(TList[2]))
                    alias Filter = AliasSeq!(TList[0], TList[2]);
                else
                    alias Filter = AliasSeq!(TList[0]);
            }
        }
        else
        {
            static if (pred!(TList[1]))
            {
                static if (pred!(TList[2]))
                    alias Filter = AliasSeq!(TList[1], TList[2]);
                else
                    alias Filter = AliasSeq!(TList[1]);
            }
            else
            {
                static if (pred!(TList[2]))
                    alias Filter = AliasSeq!(TList[2]);
                else
                    alias Filter = Nothing;
            }
        }
    },
    q{
        static if (pred!(TList[0]))
        {
            static if (pred!(TList[1]))
            {
                static if (pred!(TList[2]))
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[0], TList[1], TList[2], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[0], TList[1], TList[2]);
                }
                else
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[0], TList[1], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[0], TList[1]);
                }
            }
            else
            {
                static if (pred!(TList[2]))
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[0], TList[2], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[0], TList[2]);
                }
                else
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[0], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[0]);
                }
            }
        }
        else
        {
            static if (pred!(TList[1]))
            {
                static if (pred!(TList[2]))
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[1], TList[2], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[1], TList[2]);
                }
                else
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[1], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[1]);
                }
            }
            else
            {
                static if (pred!(TList[2]))
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[2], TList[3]);
                    else
                        alias Filter = AliasSeq!(TList[2]);
                }
                else
                {
                    static if (pred!(TList[3]))
                        alias Filter = AliasSeq!(TList[3]);
                    else
                        alias Filter = Nothing;
                }
            }
        }
    }
);

private enum filterExpandFactor = FilterShortCode.length;

package alias Nothing = AliasSeq!(); // yes, this really does speed up compilation!
/**
 * Filters an `AliasSeq` using a template predicate. Returns an
 * `AliasSeq` of the elements which satisfy the predicate.
 */
template Filter(alias pred, TList ...)
{
    static if (TList.length < filterExpandFactor)
    {
        mixin(FilterShortCode[TList.length]);
    }
    else
    {
        template MaybeNothing(Q ...)
        {
            static if (pred!(Q[0]))
                alias MaybeNothing = AliasSeq!(Q[0]);
            else
                alias MaybeNothing = Nothing;
        }
        alias Filter = staticMap!(MaybeNothing, TList);
    }
}

///
@safe unittest
{
    import ripstd.traits : isNarrowString, isUnsigned;

    alias Types1 = AliasSeq!(string, wstring, dchar[], char[], dstring, int);
    alias TL1 = Filter!(isNarrowString, Types1);
    static assert(is(TL1 == AliasSeq!(string, wstring, char[])));

    alias Types2 = AliasSeq!(int, byte, ubyte, dstring, dchar, uint, ulong);
    alias TL2 = Filter!(isUnsigned, Types2);
    static assert(is(TL2 == AliasSeq!(ubyte, uint, ulong)));
}

@safe unittest
{
    import ripstd.traits : isPointer;

    static assert(is(Filter!(isPointer, int, void*, char[], int*) == AliasSeq!(void*, int*)));
    static assert(is(Filter!isPointer == AliasSeq!()));
}

@safe unittest
{
    enum Yes(T) = true;
    static struct S {}
    static assert(is(Filter!(Yes, const(int), const(S)) == AliasSeq!(const(int), const(S))));
}

// Used in template predicate unit tests below.
private version (RIPStdUnittest)
{
    template testAlways(T...)
    {
        enum testAlways = true;
    }

    template testNever(T...)
    {
        enum testNever = false;
    }

    template testError(T...)
    {
        static assert(false, "Should never be instantiated.");
    }
}


/**
 * Negates the passed template predicate.
 */
template templateNot(alias pred)
{
    enum templateNot(T...) = !pred!T;
}

///
@safe unittest
{
    import ripstd.traits : isPointer;

    alias isNoPointer = templateNot!isPointer;
    static assert(!isNoPointer!(int*));
    static assert(allSatisfy!(isNoPointer, string, char, float));
}

@safe unittest
{
    static foreach (T; AliasSeq!(int, staticMap, 42))
    {
        static assert(!Instantiate!(templateNot!testAlways, T));
        static assert(Instantiate!(templateNot!testNever, T));
    }
}


/**
 * Combines several template predicates using logical AND, i.e. constructs a new
 * predicate which evaluates to true for a given input T if and only if all of
 * the passed predicates are true for T.
 *
 * The predicates are evaluated from left to right, aborting evaluation in a
 * short-cut manner if a false result is encountered, in which case the latter
 * instantiations do not need to compile.
 */
template templateAnd(Preds...)
{
    template templateAnd(T...)
    {
        static if (Preds.length == 0)
        {
            enum templateAnd = true;
        }
        else
        {
            static if (Instantiate!(Preds[0], T))
                alias templateAnd = Instantiate!(.templateAnd!(Preds[1 .. $]), T);
            else
                enum templateAnd = false;
        }
    }
}

///
@safe unittest
{
    import ripstd.traits : isNumeric, isUnsigned;

    alias storesNegativeNumbers = templateAnd!(isNumeric, templateNot!isUnsigned);
    static assert(storesNegativeNumbers!int);
    static assert(!storesNegativeNumbers!string && !storesNegativeNumbers!uint);

    // An empty sequence of predicates always yields true.
    alias alwaysTrue = templateAnd!();
    static assert(alwaysTrue!int);
}

@safe unittest
{
    static foreach (T; AliasSeq!(int, staticMap, 42))
    {
        static assert( Instantiate!(templateAnd!(), T));
        static assert( Instantiate!(templateAnd!(testAlways), T));
        static assert( Instantiate!(templateAnd!(testAlways, testAlways), T));
        static assert(!Instantiate!(templateAnd!(testNever), T));
        static assert(!Instantiate!(templateAnd!(testAlways, testNever), T));
        static assert(!Instantiate!(templateAnd!(testNever, testAlways), T));

        static assert(!Instantiate!(templateAnd!(testNever, testError), T));
        static assert(!is(typeof(Instantiate!(templateAnd!(testAlways, testError), T))));
    }
}


/**
 * Combines several template predicates using logical OR, i.e. constructs a new
 * predicate which evaluates to true for a given input T if and only at least
 * one of the passed predicates is true for T.
 *
 * The predicates are evaluated from left to right, aborting evaluation in a
 * short-cut manner if a true result is encountered, in which case the latter
 * instantiations do not need to compile.
 */
template templateOr(Preds...)
{
    template templateOr(T...)
    {
        static if (Preds.length == 0)
        {
            enum templateOr = false;
        }
        else
        {
            static if (Instantiate!(Preds[0], T))
                enum templateOr = true;
            else
                alias templateOr = Instantiate!(.templateOr!(Preds[1 .. $]), T);
        }
    }
}

///
@safe unittest
{
    import ripstd.traits : isPointer, isUnsigned;

    alias isPtrOrUnsigned = templateOr!(isPointer, isUnsigned);
    static assert( isPtrOrUnsigned!uint &&  isPtrOrUnsigned!(short*));
    static assert(!isPtrOrUnsigned!int  && !isPtrOrUnsigned!(string));

    // An empty sequence of predicates never yields true.
    alias alwaysFalse = templateOr!();
    static assert(!alwaysFalse!int);
}

@safe unittest
{
    static foreach (T; AliasSeq!(int, staticMap, 42))
    {
        static assert( Instantiate!(templateOr!(testAlways), T));
        static assert( Instantiate!(templateOr!(testAlways, testAlways), T));
        static assert( Instantiate!(templateOr!(testAlways, testNever), T));
        static assert( Instantiate!(templateOr!(testNever, testAlways), T));
        static assert(!Instantiate!(templateOr!(), T));
        static assert(!Instantiate!(templateOr!(testNever), T));

        static assert( Instantiate!(templateOr!(testAlways, testError), T));
        static assert( Instantiate!(templateOr!(testNever, testAlways, testError), T));
        // DMD @@BUG@@: Assertion fails for int, seems like a error gagging
        // problem. The bug goes away when removing some of the other template
        // instantiations in the module.
        // static assert(!is(typeof(Instantiate!(templateOr!(testNever, testError), T))));
    }
}

/**
 * Converts any foreach-iterable entity (e.g. an input range) to an alias sequence.
 *
 * Params:
 *     iter = the entity to convert into an `AliasSeq`. It must be able to be able to be iterated over using
 *            a $(LINK2 https://dlang.org/spec/statement.html#foreach-statement, foreach-statement).
 *
 * Returns:
 *     An `AliasSeq` containing the values produced by iterating over `iter`.
 */
template aliasSeqOf(alias iter)
if (isIterable!(typeof(iter)) && !isInfinite!(typeof(iter)))
{
    import ripstd.array : array;

    struct Impl
    {
        static foreach (size_t i, el; iter.array)
            mixin(`auto e` ~ i.stringof ~ ` = el;`);
    }
    enum aliasSeqOf = Impl.init.tupleof;
}

///
@safe unittest
{
    import ripstd.algorithm.iteration : map;
    import ripstd.algorithm.sorting : sort;
    import ripstd.string : capitalize;

    struct S
    {
        int a;
        int c;
        int b;
    }

    alias capMembers = aliasSeqOf!([__traits(allMembers, S)].sort().map!capitalize());
    static assert(capMembers[0] == "A");
    static assert(capMembers[1] == "B");
    static assert(capMembers[2] == "C");
}

///
@safe unittest
{
    static immutable REF = [0, 1, 2, 3];
    foreach (I, V; aliasSeqOf!([0, 1, 2, 3]))
    {
        static assert(V == I);
        static assert(V == REF[I]);
    }
}

@safe unittest
{
    import ripstd.conv : to, octal;
    import ripstd.range : iota;
    //Testing compile time octal
    foreach (I2; aliasSeqOf!(iota(0, 8)))
        foreach (I1; aliasSeqOf!(iota(0, 8)))
        {
            enum oct = I2 *  8 + I1;
            enum dec = I2 * 10 + I1;
            enum str = to!string(dec);
            static assert(octal!dec == oct);
            static assert(octal!str == oct);
        }
}

@safe unittest
{
    enum REF = "日本語"d;
    foreach (I, V; aliasSeqOf!"日本語"c)
    {
        static assert(V == REF[I]);
    }
}

@safe unittest
{
    struct S
    {
        int opApply(scope int delegate(ref int) dg)
        {
            foreach (int i; 3 .. 5)
                if (auto r = dg(i))
                    return r;
            return 0;
        }
    }
    static assert(aliasSeqOf!(S.init) == AliasSeq!(3, 4));
}

@safe unittest
{
    struct Infinite
    {
        int front();
        void popFront();
        enum empty = false;
    }
    enum infinite = Infinite();
    static assert(isInfinite!Infinite);
    static assert(!__traits(compiles, aliasSeqOf!infinite));
}

/**
  * $(LINK2 http://en.wikipedia.org/wiki/Partial_application, Partially applies)
  * $(D_PARAM Template) by binding its first (left) or last (right) arguments
  * to $(D_PARAM args).
  *
  * Behaves like the identity function when $(D_PARAM args) is empty.
  * Params:
  *    Template = template to partially apply
  *    args     = arguments to bind
  * Returns:
  *    _Template with arity smaller than or equal to $(D_PARAM Template)
  */
template ApplyLeft(alias Template, args...)
{
    alias ApplyLeft(right...) = SmartAlias!(Template!(args, right));
}

/// Ditto
template ApplyRight(alias Template, args...)
{
    alias ApplyRight(left...) = SmartAlias!(Template!(left, args));
}

///
@safe unittest
{
    // enum bool isImplicitlyConvertible(From, To)
    import ripstd.traits : isImplicitlyConvertible;

    static assert(allSatisfy!(
        ApplyLeft!(isImplicitlyConvertible, ubyte),
        short, ushort, int, uint, long, ulong));

    static assert(is(Filter!(ApplyRight!(isImplicitlyConvertible, short),
        ubyte, string, short, float, int) == AliasSeq!(ubyte, short)));
}

///
@safe unittest
{
    import ripstd.traits : hasMember, ifTestable;

    struct T1
    {
        bool foo;
    }

    struct T2
    {
        struct Test
        {
            bool opCast(T : bool)() { return true; }
        }

        Test foo;
    }

    static assert(allSatisfy!(ApplyRight!(hasMember, "foo"), T1, T2));
    static assert(allSatisfy!(ApplyRight!(ifTestable, a => a.foo), T1, T2));
}

///
@safe unittest
{
    import ripstd.traits : Largest;

    alias Types = AliasSeq!(byte, short, int, long);

    static assert(is(staticMap!(ApplyLeft!(Largest, short), Types) ==
                AliasSeq!(short, short, int, long)));
    static assert(is(staticMap!(ApplyLeft!(Largest, int), Types) ==
                AliasSeq!(int, int, int, long)));
}

///
@safe unittest
{
    import ripstd.traits : FunctionAttribute, SetFunctionAttributes;

    static void foo() @system;
    static int bar(int) @system;

    alias SafeFunctions = AliasSeq!(
        void function() @safe,
        int function(int) @safe);

    static assert(is(staticMap!(ApplyRight!(
        SetFunctionAttributes, "D", FunctionAttribute.safe),
        typeof(&foo), typeof(&bar)) == SafeFunctions));
}

private template SmartAlias(T...)
{
    static if (T.length == 1)
    {
        alias SmartAlias = Alias!T;
    }
    else
    {
        alias SmartAlias = T;
    }
}

@safe unittest
{
    static assert(is(typeof({
        alias T(T0, int a, double b, alias T1, string c) = AliasSeq!(T0, a, b, T1, c);
        alias T0 = ApplyRight!(ApplyLeft, ApplyRight);
        alias T1 = T0!ApplyLeft;
        alias T2 = T1!T;
        alias T3 = T2!(3, "foo");
        alias T4 = T3!(short, 3, 3.3);
        static assert(Pack!T4.equals!(short, 3, 3.3, 3, "foo"));

        import ripstd.traits : isImplicitlyConvertible;
        alias U1 = ApplyLeft!(ApplyRight, isImplicitlyConvertible);
        alias U2 = U1!int;
        enum U3 = U2!short;
        static assert(U3);
    })));
}

/**
 * Creates an `AliasSeq` which repeats `TList` exactly `n` times.
 */
template Repeat(size_t n, TList...)
{
    static if (n == 0)
    {
        alias Repeat = AliasSeq!();
    }
    else static if (n == 1)
    {
        alias Repeat = AliasSeq!TList;
    }
    else static if (n == 2)
    {
        alias Repeat = AliasSeq!(TList, TList);
    }
    /* Cases 3 to 8 are to speed up compilation
     */
    else static if (n == 3)
    {
        alias Repeat = AliasSeq!(TList, TList, TList);
    }
    else static if (n == 4)
    {
        alias Repeat = AliasSeq!(TList, TList, TList, TList);
    }
    else static if (n == 5)
    {
        alias Repeat = AliasSeq!(TList, TList, TList, TList, TList);
    }
    else static if (n == 6)
    {
        alias Repeat = AliasSeq!(TList, TList, TList, TList, TList, TList);
    }
    else static if (n == 7)
    {
        alias Repeat = AliasSeq!(TList, TList, TList, TList, TList, TList, TList);
    }
    else static if (n == 8)
    {
        alias Repeat = AliasSeq!(TList, TList, TList, TList, TList, TList, TList, TList);
    }
    else
    {
        alias R = Repeat!((n - 1) / 2, TList);
        static if ((n - 1) % 2 == 0)
        {
            alias Repeat = AliasSeq!(TList, R, R);
        }
        else
        {
            alias Repeat = AliasSeq!(TList, TList, R, R);
        }
    }
}

///
@safe unittest
{
    alias ImInt0 = Repeat!(0, int);
    static assert(is(ImInt0 == AliasSeq!()));

    alias ImInt1 = Repeat!(1, immutable(int));
    static assert(is(ImInt1 == AliasSeq!(immutable(int))));

    alias Real3 = Repeat!(3, real);
    static assert(is(Real3 == AliasSeq!(real, real, real)));

    alias Real12 = Repeat!(4, Real3);
    static assert(is(Real12 == AliasSeq!(real, real, real, real, real, real,
        real, real, real, real, real, real)));

    alias Composite = AliasSeq!(uint, int);
    alias Composite2 = Repeat!(2, Composite);
    static assert(is(Composite2 == AliasSeq!(uint, int, uint, int)));

    alias ImInt10 = Repeat!(10, int);
    static assert(is(ImInt10 == AliasSeq!(int, int, int, int, int, int, int, int, int, int)));
}


///
@safe unittest
{
    auto staticArray(T, size_t n)(Repeat!(n, T) elems)
    {
        T[n] a = [elems];
        return a;
    }

    auto a = staticArray!(long, 3)(3, 1, 4);
    assert(is(typeof(a) == long[3]));
    assert(a == [3, 1, 4]);
}

/**
 * Sorts an $(LREF AliasSeq) using `cmp`.
 *
 * Parameters:
 *     cmp = A template that returns a `bool` (if its first argument is less than the second one)
 *         or an `int` (-1 means less than, 0 means equal, 1 means greater than)
 *
 *     Seq = The  $(LREF AliasSeq) to sort
 *
 * Returns: The sorted alias sequence
 */
template staticSort(alias cmp, Seq...)
{
    static if (Seq.length < 2)
    {
        alias staticSort = Seq;
    }
    else
    {
        private alias btm = staticSort!(cmp, Seq[0 .. $ / 2]);
        private alias top = staticSort!(cmp, Seq[$ / 2 .. $]);

        static if (isLessEq!(cmp, btm[$ - 1], top[0]))
            alias staticSort = AliasSeq!(btm, top); // already ascending
        else static if (isLessEq!(cmp, top[$ - 1], btm[0]))
            alias staticSort = AliasSeq!(top, btm); // already descending
        else
            alias staticSort = staticMerge!(cmp, Seq.length / 2, btm, top);
    }
}

///
@safe unittest
{
    alias Nums = AliasSeq!(7, 2, 3, 23);
    enum Comp(int N1, int N2) = N1 < N2;
    static assert(AliasSeq!(2, 3, 7, 23) == staticSort!(Comp, Nums));
}

///
@safe unittest
{
    alias Types = AliasSeq!(uint, short, ubyte, long, ulong);
    enum Comp(T1, T2) = __traits(isUnsigned, T2) - __traits(isUnsigned, T1);
    static assert(is(AliasSeq!(uint, ubyte, ulong, short, long) == staticSort!(Comp,
        Types)));
}

private template staticMerge(alias cmp, int half, Seq...)
{
    static if (half == 0 || half == Seq.length)
    {
        alias staticMerge = Seq;
    }
    else
    {
        static if (isLessEq!(cmp, Seq[0], Seq[half]))
        {
            alias staticMerge = AliasSeq!(Seq[0],
                staticMerge!(cmp, half - 1, Seq[1 .. $]));
        }
        else
        {
            alias staticMerge = AliasSeq!(Seq[half],
                staticMerge!(cmp, half, Seq[0 .. half], Seq[half + 1 .. $]));
        }
    }
}

private template isLessEq(alias cmp, Seq...)
if (Seq.length == 2)
{
    private enum Result = cmp!(Seq[1], Seq[0]);
    static if (is(typeof(Result) == bool))
        enum isLessEq = !Result;
    else static if (is(typeof(Result) : int))
        enum isLessEq = Result >= 0;
    else
        static assert(0, typeof(Result).stringof ~ " is not a value comparison type");
}

/**
 * Checks if an $(LREF AliasSeq) is sorted according to `cmp`.
 *
 * Parameters:
 *     cmp = A template that returns a `bool` (if its first argument is less than the second one)
 *         or an `int` (-1 means less than, 0 means equal, 1 means greater than)
 *
 *     Seq = The  $(LREF AliasSeq) to check
 *
 * Returns: `true` if `Seq` is sorted; otherwise `false`
 */
enum staticIsSorted(alias cmp, items...) =
    {
        static if (items.length > 1)
            static foreach (i, item; items[1 .. $])
                static if (!isLessEq!(cmp, items[i], item))
                    if (__ctfe) return false;
        return true;
    }();

///
@safe unittest
{
    enum Comp(int N1, int N2) = N1 < N2;
    static assert( staticIsSorted!(Comp, 2, 2));
    static assert( staticIsSorted!(Comp, 2, 3, 7, 23));
    static assert(!staticIsSorted!(Comp, 7, 2, 3, 23));
}

///
@safe unittest
{
    enum Comp(T1, T2) = __traits(isUnsigned, T2) - __traits(isUnsigned, T1);
    static assert( staticIsSorted!(Comp, uint, ubyte, ulong, short, long));
    static assert(!staticIsSorted!(Comp, uint, short, ubyte, long, ulong));
}

/**
Selects a subset of `Args` by stepping with fixed `stepSize` over the sequence.
A negative `stepSize` starts iteration with the last element.

Params:
    stepSize = Number of elements to increment on each iteration. Can't be `0`.
    Args = Template arguments.

Returns: An `AliasSeq` filtered by the selected stride.
*/
template Stride(int stepSize, Args...)
if (stepSize != 0)
{
    static if (Args.length == 0)
    {
        alias Stride = AliasSeq!();
    }
    else static if (stepSize > 0)
    {
        static if (stepSize >= Args.length)
            alias Stride = AliasSeq!(Args[0]);
        else
            alias Stride = AliasSeq!(Args[0], Stride!(stepSize, Args[stepSize .. $]));
    }
    else
    {
        static if (-stepSize >= Args.length)
            alias Stride = AliasSeq!(Args[$ - 1]);
        else
            alias Stride = AliasSeq!(Args[$ - 1], Stride!(stepSize, Args[0 .. $ + stepSize]));
    }
}

///
@safe unittest
{
    static assert(is(Stride!(1, short, int, long) == AliasSeq!(short, int, long)));
    static assert(is(Stride!(2, short, int, long) == AliasSeq!(short, long)));
    static assert(is(Stride!(-1, short, int, long) == AliasSeq!(long, int, short)));
    static assert(is(Stride!(-2, short, int, long) == AliasSeq!(long, short)));

    alias attribs = AliasSeq!(short, int, long, ushort, uint, ulong);
    static assert(is(Stride!(3, attribs) == AliasSeq!(short, ushort)));
    static assert(is(Stride!(3, attribs[1 .. $]) == AliasSeq!(int, uint)));
    static assert(is(Stride!(-3, attribs) == AliasSeq!(ulong, long)));
}

@safe unittest
{
    static assert(Pack!(Stride!(5, int)).equals!(int));
    static assert(Pack!(Stride!(-5, int)).equals!(int));
    static assert(!__traits(compiles, Stride!(0, int)));
}

/**
 * Instantiates the given template with the given parameters.
 *
 * Used to work around syntactic limitations of D with regard to instantiating
 * a template from an alias sequence (e.g. `T[0]!(...)` is not valid) or a
 * template returning another template (e.g. `Foo!(Bar)!(Baz)` is not allowed).
 *
 * Params:
 *    Template = The template to instantiate.
 *    Params = The parameters with which to instantiate the template.
 * Returns:
 *    The instantiated template.
 */
alias Instantiate(alias Template, Params...) = Template!Params;

///
@safe unittest
{
    // ApplyRight combined with Instantiate can be used to apply various
    // templates to the same parameters.
    import ripstd.string : leftJustify, center, rightJustify;
    alias functions = staticMap!(ApplyRight!(Instantiate, string),
                                 leftJustify, center, rightJustify);
    string result = "";
    static foreach (f; functions)
    {
        {
            auto x = &f; // not a template, but a function instantiation
            result ~= x("hello", 7);
            result ~= ";";
        }
    }

    assert(result == "hello  ; hello ;  hello;");
}

// : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : //
private:

/*
 * [internal] Returns true if a and b are the same thing, or false if
 * not. Both a and b can be types, literals, or symbols.
 *
 * How:                     When:
 *        a == b          - at least one rvalue (literals, enums, function calls)
 * __traits(isSame, a, b) - other cases (types, variables, functions, templates, etc.)
 */
private template isSame(alias a, alias b)
{
    static if (!is(typeof(&a && &b)) // at least one is an rvalue
            && __traits(compiles, { enum isSame = a == b; })) // c-t comparable
    {
        enum isSame = a == b;
    }
    else
    {
        enum isSame = __traits(isSame, a, b);
    }
}
// TODO: remove after https://github.com/dlang/dmd/pull/11320 and https://issues.dlang.org/show_bug.cgi?id=21889 are fixed
private template isSame(A, B)
{
    enum isSame = is(A == B);
}

@safe unittest
{
    static assert(!isSame!(Object, const Object));
    static assert(!isSame!(Object, immutable Object));

    static struct S {}
    static assert(!isSame!(S, const S));
    static assert( isSame!(S(), S()));

    static class C {}
    static assert(!isSame!(C, const C));

    static assert( isSame!(int, int));
    static assert(!isSame!(int, const int));
    static assert(!isSame!(const int, immutable int));
    static assert(!isSame!(int, short));

    enum a = 1, b = 1, c = 2, s = "a", t = "a";
    static assert( isSame!(1, 1));
    static assert( isSame!(a, 1));
    static assert( isSame!(a, b));
    static assert(!isSame!(b, c));
    static assert( isSame!("a", "a"));
    static assert( isSame!(s, "a"));
    static assert( isSame!(s, t));
    static assert(!isSame!(1, "1"));
    static assert(!isSame!(a, "a"));
    static assert( isSame!(isSame, isSame));
    static assert(!isSame!(isSame, a));

    static assert(!isSame!(byte, a));
    static assert(!isSame!(short, isSame));
    static assert(!isSame!(a, int));
    static assert(!isSame!(long, isSame));

    static immutable X = 1, Y = 1, Z = 2;
    static assert( isSame!(X, X));
    static assert(!isSame!(X, Y));
    static assert(!isSame!(Y, Z));
    static assert( isSame!(X, 1));
    static assert( isSame!(1, X));

    int  foo();
    int  bar();
    real baz(int);
    static assert( isSame!(foo, foo));
    static assert(!isSame!(foo, bar));
    static assert(!isSame!(bar, baz));
    static assert( isSame!(baz, baz));
    static assert(!isSame!(foo, 0));

    int  x, y;
    real z;
    static assert( isSame!(x, x));
    static assert(!isSame!(x, y));
    static assert(!isSame!(y, z));
    static assert( isSame!(z, z));
    static assert(!isSame!(x, 0));
}

/*
 * [internal] Wraps a sequence in a template. Used only in unittests.
 */
private template Pack(T...)
{
    alias Expand = T;
    enum equals(U...) = isSame!(Pack!T, Pack!U);
}

@safe unittest
{
    static assert( Pack!(1, int, "abc").equals!(1, int, "abc"));
    static assert(!Pack!(1, int, "abc").equals!(1, int, "cba"));
}
