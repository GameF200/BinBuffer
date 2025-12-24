
# BinBuffer API Reference

## Constants

These constants represent type identifiers used internally and exposed publicly.

*   `NIL = 0,`
*	`BOOLEAN = 1,`
*	`NUMBER_I8 = 2,`
*	`NUMBER_I16 = 3,`
*	`NUMBER_I32 = 5,`
*	`NUMBER_U8 = 6,`
*	`NUMBER_U16 = 7,`
*	`NUMBER_U32 = 9,`
*	`NUMBER_F16 = 10,`
*	`NUMBER_F24 = 11,`
*	`NUMBER_F32 = 12,`
*	`NUMBER_F64 = 13,`
*	`STRING = 14,`
*	`STRING_LONG = 15,`
*	`VECTOR2 = 16,`
*	`VECTOR3 = 17,`
*	`COLOR3 = 18,`
*	`UDIM = 19,`
*	`UDIM2 = 20,`
*	`CFRAME = 21,`
*	`RECT = 22,`
*	`NUMBER_RANGE = 23,`
*	`NUMBER_SEQUENCE = 24,`
*	`COLOR_SEQUENCE = 25,`
*	`BRICK_COLOR = 26,`
*	`TABLE = 27,`
*	`VECTOR2F16 = 28,`
*	`VECTOR3F16 = 29,`
*	`VECTOR2F24 = 30,`
*	`VECTOR3F24 = 31,`
*	`VECTOR2I16 = 32,`
*	`VECTOR3I16 = 3,`
*	`CFRAMEF16U8 = 37,`
*	`CFRAMEF24U8 = 38,`
*	`CFRAMEF16U16 = 39,`
*	`CFRAMEF24U16 = 40,`

## Utility Functions

`bytes(n: number): number`

Returns the input unchanged; syntactic sugar for specifying buffer sizes in bytes.

`kilobytes(n: number): number`

Converts kilobytes to bytes (multiplies by 1024).

`megabytes(n: number): number`

Converts megabytes to bytes (multiplies by 1,048,576).

## Buffer Management

```lua 
create(options: { size?: number, callback?: (buffer) -> () }): Buffer
```

Creates a new BinBuffer instance. Default size is 32 bytes. Maximum buffer size is capped at 32 MB.

```lua 
clear(buf: Buffer)
```

Resets the write offset and instance list, reallocating internal buffer to its original size.

```lua
destroy(buf: Buffer)
```

Destroys the buffer by clearing all internal references and setting it to nil.

```lua
flush(buf: Buffer): boolean
```

Copies the written data into a new buffer, invokes the callback with it, and clears the buffer. Returns `false` if nothing to flush or buffer is destroyed.

```lua
alloc(buf: Buffer, requiredBytes: number): boolean
```

Ensures the internal buffer can accommodate `requiredBytes`. Grows buffer using dynamic sizing strategy. Returns `false` if capacity exceeds maximum allowed size (64 megabytes).

```lua
tobuffer(buf: Buffer): buffer
```

Returns a copy of the internal buffer containing only the written data.

```lua
fromBuffer(buf: buffer): Buffer?
```
Reconstructs a BinBuffer from a raw buffer by analyzing its structure and extracting instance metadata. Returns `nil` if buffer is empty.

## Serialization (Writers)

All writer functions are accessible via the `writers` table. Each returns `true` on success or `false` if allocation fails.

```lua
writers.addNil(buf)
```

Writes a nil value.

```lua
writers.addBoolean(buf, value)
```
Writes a boolean.

```lua
writers.addNumber(buf, value)
```

Automatically selects the most compact numeric representation (integer or float, signed/unsigned, with optimized bit-widths).

```lua
writers.addU8(buf, value)
```

Writes an unsigned 8-bit integer.

```lua
writers.addU16(buf, value)
```

Writes an unsigned 16-bit integer.

```lua
writers.addU32(buf, value)
```

Writes an unsigned 32-bit integer.

```lua
writers.addI8(buf, value)
```

Writes a signed 8-bit integer.

```lua
writers.addI16(buf, value)
```

Writes a signed 16-bit integer.

```lua
writers.addI32(buf, value)
```

Writes a signed 32-bit integer.

```lua
writers.addF16(buf, value)
```

Writes a 16-bit floating-point number.

```lua
writers.addF24(buf, value)
```

Writes a 24-bit floating-point number.

```lua
writers.addF32(buf, value)
```

Writes a 32-bit floating-point number.

```lua
writers.addF64(buf, value)
```

Writes a 64-bit floating-point number.

```lua
writers.addString(buf, value)
```

Writes a string; uses `STRING` for lengths < 256, otherwise `STRING_LONG`.

```lua
writers.addStringShort(buf, value)
```

Writes a short string (length < 256) using 1-byte length header.

```lua
writers.addStringLong(buf, value)
```

Writes a long string (length ≥ 256) using 2-byte length header.

```lua
writers.addVector2(buf, value)
```

Writes a `Vector2` using three 32-bit floats.

```lua
writers.addVector3(buf, value)
```

Writes a `Vector3` using three 32-bit floats.

```lua
writers.addVector2F16(buf, value)
```

Writes a `Vector2` using two 16-bit floats (5 bytes total).

```lua
writers.addVector3F16(buf, value)
```

Writes a `Vector3` using three 16-bit floats (7 bytes total).

```lua
writers.addVector2F24(buf, value)
```

Writes a `Vector2` using two 24-bit floats (7 bytes total).

```lua
writers.addVector3F24(buf, value)
```

Writes a `Vector3` using three 24-bit floats (10 bytes total).

```lua
writers.addVector2I16(buf, value)
```

Writes a `Vector2int16` using two 16-bit signed integers.

```lua
writers.addVector3I16(buf, value)
```

Writes a `Vector3int16` using three 16-bit signed integers.

```lua
writers.addCFrame(buf, value)
```

Writes a `CFrame` as Euler angles (3×U16) + position (3×F32), total 19 bytes.

```lua
writers.addCFrameF16U8(buf, value)
```

Writes a `CFrame` with 8-bit Euler angles and 16-bit float positions (10 bytes).

```lua
writers.addCFrameF24U8(buf, value)
```

Writes a `CFrame` with 8-bit Euler angles and 24-bit float positions (13 bytes).

```lua
writers.addCFrameF16U16(buf, value)
```

Writes a `CFrame` with 16-bit Euler angles and 16-bit float positions (13 bytes).

```lua
writers.addCFrameF24U16(buf, value)
```

Writes a `CFrame` with 16-bit Euler angles and 24-bit float positions (16 bytes).

```lua
writers.addColor3(buf, value)
```

Writes a `Color3` as 3×U8 (RGB ×255).

```lua
writers.addUDim(buf, value)
```

Writes a `UDim` as scale (I16 ×1000) and offset (I16).

```lua
writers.addUDim2(buf, value)
```

Writes a `UDim2` as two `UDim` values.
```lua
writers.addRect(buf, value)
```
Writes a `Rect` as four F32 values (Min/Max X/Y).

```lua
writers.addNumberRange(buf, value)
```

Writes a `NumberRange` as two F32 values (Min/Max).

```lua
writers.addNumberSequence(buf, value)
```

Writes a NumberSequence by encoding each keypoint as three U8 values (Time, Value, Envelope scaled to \[0,255\]).

```lua
writers.addColorSequence(buf, value)
```

Writes a `ColorSequence` by encoding each keypoint as U8 (Time) + 3×U8 (RGB).

```lua
writers.addBrickColor(buf, value)
```

Writes a `BrickColor` by storing its numeric ID as U16.

```lua
writers.addTable(buf, value)
```

Recursively serializes a table as alternating key-value pairs, terminated by a `NIL` marker.

## Deserialization

```lua
read(buf: Buffer): {any}
```

Deserializes the entire buffer into a list of reconstructed values. Resolves stored Instance references and supports all serialized types including nested tables.