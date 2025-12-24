# Welcome to BinBuffer docs

## Github repo  [GitHub](https://github.com/GameF200/BinBuffer).

## Quick example

```lua
local BinBuffer = require(path.to.BinBuffer)

local my_buf = BinBuffer.create({size = 10}) -- <- creating empty buffer, size grows automatically
BinBuffer.alloc(my_buf, 20) -- <- manual alloc, for more high perfomance

BinBuffer.writers.addString(my_buf, "This is a string") -- <- writers functions, this is what we need!

local data = BinBuffer.read(my_buf) -- <- reads buffer and returns table of buffer content
print(data) -- <- {[1] = "This is a string"}

local basic_buffer = BinBuffer.tobuffer(my_buf) -- <- returns a BASIC luau buffer primitive

local frombuffer_example = BinBuffer.frombuffer(basic_buffer) -- <- returns a BinBuffer object from BASIC buffer primitive
```
