const std = @import("std");
const Stack = std.atomic.Stack;
const Mutex = std.Thread.Mutex;

const ErrorStack = @This();

pub const Tag = enum {};

const ErrStack = Stack(Tag);

stack: ErrStack,

pub fn init() ErrorStack {
    return ErrorStack{
        .stack = ErrStack.init(),
    };
}

pub fn push()
