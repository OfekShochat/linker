# linker
this is the start of my linker in zig.
what Im trying to do differently is the way I'm arranging the symbols. they should be arranged in a tree, and when we're getting close to a symbol we did not load yet (for example its dependencies) we can load them asynchronously. the implementation can use a struct with a memory allocated array that maps to a map, and that tree we're working on. so we can use both representations.
note that this is a very rough idea, and I didn't think about it much. currently, this repo only includes the elf header parser.
