--!strict
--!optimize 2

--[[

	.______    __  .__   __. .______    __    __   _______  _______  _______ .______      
	|   _  \  |  | |  \ |  | |   _  \  |  |  |  | |   ____||   ____||   ____||   _  \     
	|  |_)  | |  | |   \|  | |  |_)  | |  |  |  | |  |__   |  |__   |  |__   |  |_)  |    
	|   _  <  |  | |  . `  | |   _  <  |  |  |  | |   __|  |   __|  |   __|  |      /     
	|  |_)  | |  | |  |\   | |  |_)  | |  `--'  | |  |     |  |     |  |____ |  |\  \----.
	|______/  |__| |__| \__| |______/   \______/  |__|     |__|     |_______|| _| `._____|
          
    BinBuffer - advanced buffering module
    
   	@author super_sonic
   	@version 1.5.0
   	@license MIT
   	
   	@changelog:
   		- removed "create" function args
   		- removed flush function
   		- added i24/u24 types
   		- added "with_capacity" function for creating buffer with preallocated size
   		- removed "alloc" function

]]

local NIL = 0
local BOOLEAN = 1
local NUMBER_I8 = 2
local NUMBER_I16 = 3
local NUMBER_I32 = 4
local NUMBER_U8 = 5
local NUMBER_U16 = 6
local NUMBER_U32 = 7
local NUMBER_F16 = 8
local NUMBER_F24 = 9
local NUMBER_F32 = 10
local NUMBER_F64 = 11
local STRING = 12
local STRING_LONG = 13
local VECTOR2 = 14
local VECTOR3 = 15
local COLOR3 = 16
local UDIM = 17
local UDIM2 = 18
local CFRAME = 19
local RECT = 20
local NUMBER_RANGE = 21
local NUMBER_SEQUENCE = 22  
local COLOR_SEQUENCE = 23 
local BRICK_COLOR = 24
local TABLE = 25
local VECTOR2F16 = 26
local VECTOR3F16 = 27
local VECTOR2F24 = 28
local VECTOR3F24 = 29
local VECTOR2I16 = 30
local VECTOR3I16 = 31
local CFRAMEF16U8 = 32
local CFRAMEF24U8 = 33
local CFRAMEF16U16 = 34
local CFRAMEF24U16 = 35
local NUMBER_I24 = 36
local NUMBER_U24 = 37

local MEGABYTE = 1048576
local MAX_REASONABLE_SIZE = 67108864
local CFRAME_SCALE = 10430.219195527361
local CFRAME_INV_SCALE = 1 / CFRAME_SCALE
local CFRAME_SCALE_U8 = 40.58451048843331
local CFRAME_INV_SCALE_U8 = 1 / CFRAME_SCALE_U8
local UDIM_SCALE = 1000
local UDIM_INV_SCALE = 0.001
local FLOAT_TO_BYTE_SCALE = 255
local FLOAT_FROM_BYTE_SCALE = 0.00392156862745098 -- equailent to 1/255
local U8_MAX = 255
local U16_MAX = 65535
local U32_MAX = 4294967295
local I8_MIN = -128
local I32_MIN = -2147483648
local F16_MAX = 65520.0
local F24_MAX = 4294959104.0
local F32_MAX = 3.4028235e38
local U24_MAX = 16777215

local math_max = math.max
local math_min = math.min

local math_floor          = math.floor
local math_abs            = math.abs
local math_frexp          = math.frexp
local table_insert        = table.insert
local table_clear         = table.clear
local string_len          = string.len

local buffer_create       = buffer.create
local buffer_copy         = buffer.copy
local buffer_len          = buffer.len
local buffer_writeu8      = buffer.writeu8
local buffer_writeu16     = buffer.writeu16
local buffer_writeu32     = buffer.writeu32
local buffer_writei8      = buffer.writei8
local buffer_writei16     = buffer.writei16
local buffer_writei32     = buffer.writei32
local buffer_writef32     = buffer.writef32
local buffer_writef64     = buffer.writef64
local buffer_writestring  = buffer.writestring
local buffer_writebits    = buffer.writebits

local buffer_readu8       = buffer.readu8
local buffer_readu16      = buffer.readu16
local buffer_readu32      = buffer.readu32
local buffer_readi8       = buffer.readi8
local buffer_readi16      = buffer.readi16
local buffer_readi32      = buffer.readi32
local buffer_readf32      = buffer.readf32
local buffer_readf64      = buffer.readf64
local buffer_readstring   = buffer.readstring
local buffer_readbits     = buffer.readbits

export type Buffer = {
	_buffer: buffer,
	_maxSize: number,
	_size: number,
	_destroyed: boolean,
	_writeOffset: number,
}

local writers = {}

local function Alloc(buf: Buffer, requiredBytes: number): boolean
	local targetLength = buf._writeOffset + requiredBytes
	if buf._writeOffset < targetLength then
		while buf._writeOffset < targetLength do buf._writeOffset *= 2 end
		local newBuffer = buffer.create(buf._writeOffset)
		buffer.copy(newBuffer, 0, buf._buffer, 0, buf._writeOffset)
		buf._buffer = newBuffer
	end
	return true
end

local function WriteF16Data(buf: buffer, offset: number, value: number)
	local bitOffset = offset * 8
	if value == 0 then
		buffer_writebits(buf, bitOffset, 16, 0)
	elseif value ~= value then
		buffer_writebits(buf, bitOffset, 16, 31745)
	else
		local sign = 0
		if value < 0 then 
			sign = 1 
			value = -value 
		end
		local mantissa, exponent = math_frexp(value)
		buffer_writebits(buf, bitOffset, 10, mantissa * 2048 - 1023.5)
		buffer_writebits(buf, bitOffset + 10, 5, exponent + 14)
		buffer_writebits(buf, bitOffset + 15, 1, sign)
	end
end



local function WriteU24Data(buf: buffer, offset: number, value: number)
	local bitOffset = offset * 8
	buffer_writebits(buf, bitOffset, 24, value)
end

local function WriteI24Data(buf: buffer, offset: number, value: number)
	local bitOffset = offset * 8
	local unsignedValue
	if value < 0 then
		unsignedValue = (bit32.lshift(1, 24)) + value  
	else
		unsignedValue = value
	end
	buffer_writebits(buf, bitOffset, 24, unsignedValue)
end

local function ReadU24(buf: buffer, offset: number): number
	local bitOffset = offset * 8
	return buffer_readbits(buf, bitOffset, 24)
end

local function ReadI24(buf: buffer, offset: number): number
	local bitOffset = offset * 8
	local unsignedValue = buffer_readbits(buf, bitOffset, 24)
	if unsignedValue >= (bit32.lshift(1, 23)) then
		return unsignedValue - (bit32.lshift(1, 24)) 
	else
		return unsignedValue
	end
end

local function WriteF24Data(buf: buffer, offset: number, value: number)
	local bitOffset = offset * 8
	if value == 0 then
		buffer_writebits(buf, bitOffset, 24, 0)
	elseif value ~= value then
		buffer_writebits(buf, bitOffset, 24, 8323073)
	else
		local sign = 0
		if value < 0 then 
			sign = 1 
			value = -value 
		end
		local mantissa, exponent = math_frexp(value)
		buffer_writebits(buf, bitOffset, 17, mantissa * 262144 - 131071.5)
		buffer_writebits(buf, bitOffset + 17, 6, exponent + 30)
		buffer_writebits(buf, bitOffset + 23, 1, sign)
	end
end

local function ClassifyNumber(value: number): (number, number)
	if value // 1 == value then -- NOTE: value % 1 == 0 in worst case reduced perfomance by 4%
		if value >= 0 then
			if value <= U8_MAX then
				return NUMBER_U8, 2
			elseif value <= U16_MAX then
				return NUMBER_U16, 3
			elseif value <= U24_MAX then
				return NUMBER_U24, 4
			elseif value <= U32_MAX then
				return NUMBER_U32, 5
			end
		else
			if value >= I8_MIN then
				return NUMBER_I8, 2
			elseif value >= -8388608 then  -- I24_MIN
				return NUMBER_I24, 4
			elseif value >= I32_MIN then
				return NUMBER_I32, 5
			end
		end
		return NUMBER_F64, 9
	end

	local absValue = math_abs(value)

	if absValue <= F16_MAX then
		return NUMBER_F16, 3
	elseif absValue <= F24_MAX then
		return NUMBER_F24, 4
	elseif absValue <= F32_MAX then
		return NUMBER_F32, 5
	end

	return NUMBER_F64, 9
end

-- simple help functions
local function bytes(bytes: number): number
	return bytes
end

local function kilobytes(kilobytes: number): number
	return kilobytes * 1024
end

local function megabytes(megabytes: number): number
	return megabytes * 1048576
end

-- creates a new buffer
local function create(): Buffer
	local size = 4
	local maxSize = megabytes(32)

	return {
		_buffer = buffer_create(size),
		_maxSize = maxSize,
		_destroyed = false,
		_size = size,
		_writeOffset = 0,
	} :: Buffer
end

local function with_capacity(capacity: number): Buffer
	if capacity <= 0 then
		error(`[BinBuffer] invalid constructor capacity`)
	end
	local maxSize = megabytes(64)
	
	return {
		_buffer = buffer_create(capacity),
		_maxSize = maxSize,
		_destroyed = false,
		_size = capacity,
		_writeOffset = 0
	}
end

-- clears buffer but not destroys
local function clear(buf: Buffer)
	buf._writeOffset = 0

	local originalSize = buf._size
	buf._buffer = buffer_create(originalSize)
end

-- fully destroys buffer
local function destroy(buf: Buffer)
	buf._destroyed = true
	buf._buffer = nil
	buf._writeOffset = 0
	buf._size = 0
end


-- add* functions
function writers.addNil(buf: Buffer): boolean
	if buf._writeOffset + 1 > buffer_len(buf._buffer) then
		if not Alloc(buf, 1) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NIL)
	buf._writeOffset += 1
	return true
end

function writers.addBoolean(buf: Buffer, value: boolean): boolean
	if buf._writeOffset + 2 > buffer_len(buf._buffer) then
		if not Alloc(buf, 2) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, BOOLEAN)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, value and 1 or 0)
	buf._writeOffset += 2
	return true
end

function writers.addNumber(buf: Buffer, value: number): boolean

	local numType, requiredBytes = ClassifyNumber(value)

	if buf._writeOffset + requiredBytes > buffer_len(buf._buffer) then
		if not Alloc(buf, requiredBytes) then return false end
	end

	local offset = buf._writeOffset
	buffer_writeu8(buf._buffer, offset, numType)

	if numType == NUMBER_U8 then
		buffer_writeu8(buf._buffer, offset + 1, value)
		buf._writeOffset += 2
	elseif numType == NUMBER_U16 then
		buffer_writeu16(buf._buffer, offset + 1, value)
		buf._writeOffset += 3
	elseif numType == NUMBER_U32 then
		buffer_writeu32(buf._buffer, offset + 1, value)
		buf._writeOffset += 5
	elseif numType == NUMBER_I8 then
		buffer_writei8(buf._buffer, offset + 1, value)
		buf._writeOffset += 2
	elseif numType == NUMBER_I32 then
		buffer_writei32(buf._buffer, offset + 1, value)
		buf._writeOffset += 5
	elseif numType == NUMBER_F16 then
		WriteF16Data(buf._buffer, offset + 1, value)
		buf._writeOffset += 3
	elseif numType == NUMBER_F24 then
		WriteF24Data(buf._buffer, offset + 1, value)
		buf._writeOffset += 4
	elseif numType == NUMBER_F32 then
		buffer_writef32(buf._buffer, offset + 1, value)
		buf._writeOffset += 5
	else -- NUMBER_F64
		buffer_writef64(buf._buffer, offset + 1, value)
		buf._writeOffset += 9
	end

	return true
end

function writers.addU8(buf: Buffer, value: number): boolean
	if buf._writeOffset + 2 > buffer_len(buf._buffer) then
		if not Alloc(buf, 2) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U8)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 2
	return true	
end

function writers.addU16(buf: Buffer, value :number): boolean
	if buf._writeOffset + 3 > buffer_len(buf._buffer) then
		if not Alloc(buf, 3) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U16)
	buffer_writeu16(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 3
	return true	
end

function writers.addU32(buf: Buffer, value: number): boolean
	if buf._writeOffset + 5 > buffer_len(buf._buffer) then
		if not Alloc(buf, 5) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U32)
	buffer_writeu32(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 5
	return true	
end


function writers.addI8(buf: Buffer, value: number): boolean
	if buf._writeOffset + 2 > buffer_len(buf._buffer) then
		if not Alloc(buf, 2) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_I8)
	buffer_writei8(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 2
	return true	
end

function writers.addI16(buf: Buffer, value: number): boolean
	if buf._writeOffset + 3 > buffer_len(buf._buffer) then
		if not Alloc(buf, 3) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_I16)
	buffer_writei16(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 3
	return true	
end

function writers.addU24(buf: Buffer, value: number): boolean
	if buf._writeOffset + 4 > buffer_len(buf._buffer) then
		if not Alloc(buf, 4) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U24)
	WriteU24Data(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 4
	return true
end

function writers.addI24(buf: Buffer, value: number): boolean
	if buf._writeOffset + 4 > buffer_len(buf._buffer) then
		if not Alloc(buf, 4) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_I24)
	WriteI24Data(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 4
	return true
end

function writers.addI32(buf: Buffer, value: number): boolean
	if buf._writeOffset + 5 > buffer_len(buf._buffer) then
		if not Alloc(buf, 5) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_I32)
	buffer_writei32(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 5
	return true	
end

function writers.addF16(buf: Buffer, value: number): boolean
	if buf._writeOffset + 3 > buffer_len(buf._buffer) then
		if not Alloc(buf, 3) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F16)
	WriteF16Data(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 3
	return true
end

function writers.addF24(buf: Buffer, value: number): boolean
	if buf._writeOffset + 4 > buffer_len(buf._buffer) then
		if not Alloc(buf, 4) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F24)
	WriteF24Data(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 4
	return true
end

function writers.addF32(buf: Buffer, value: number): boolean
	if buf._writeOffset + 5 > buffer_len(buf._buffer) then
		if not Alloc(buf, 5) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F32)
	buffer_writef32(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 5
	return true	
end

function writers.addF64(buf: Buffer, value: number): boolean
	if buf._writeOffset + 9 > buffer_len(buf._buffer) then
		if not Alloc(buf, 9) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F64)
	buffer_writef64(buf._buffer, buf._writeOffset + 1, value)
	buf._writeOffset += 9
	return true	
end

function writers.addStringShort(buf: Buffer, value: string): boolean
	if buf._writeOffset + 2 + string_len(value) > buffer_len(buf._buffer) then
		if not Alloc(buf, 2 + string_len(value)) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, STRING)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, string_len(value))
	buffer_writestring(buf._buffer, buf._writeOffset + 2, value)
	buf._writeOffset = buf._writeOffset + 2 + string_len(value)
	return true
end

function writers.addStringLong(buf: Buffer, value: string): boolean
	if buf._writeOffset + 3 + string_len(value) > buffer_len(buf._buffer) then
		if not Alloc(buf, 3 + string_len(value)) then return false end
	end
	buffer_writeu8(buf._buffer, buf._writeOffset, STRING_LONG)
	buffer_writeu16(buf._buffer, buf._writeOffset + 1, string_len(value))
	buffer_writestring(buf._buffer, buf._writeOffset + 3, value)
	buf._writeOffset = buf._writeOffset + 3 + string_len(value)
	return true
end

function writers.addString(buf: Buffer, value: string): boolean

	local len = string_len(value)
	if len < 256 then
		local requiredBytes = 2 + len
		if buf._writeOffset + requiredBytes > buffer_len(buf._buffer) then
			if not Alloc(buf, requiredBytes) then return false end
		end
		buffer_writeu8(buf._buffer, buf._writeOffset, STRING)
		buffer_writeu8(buf._buffer, buf._writeOffset + 1, len)
		buffer_writestring(buf._buffer, buf._writeOffset + 2, value)
		buf._writeOffset += requiredBytes
	else
		local requiredBytes = 3 + len
		if buf._writeOffset + requiredBytes > buffer_len(buf._buffer) then
			if not Alloc(buf, requiredBytes) then return false end
		end
		buffer_writeu8(buf._buffer, buf._writeOffset, STRING_LONG)
		buffer_writeu16(buf._buffer, buf._writeOffset + 1, len)
		buffer_writestring(buf._buffer, buf._writeOffset + 3, value)
		buf._writeOffset += requiredBytes
	end

	return true
end

function writers.addVector3(buf: Buffer, value: Vector3): boolean
	if buf._writeOffset + 13 > buffer_len(buf._buffer) then
		if not Alloc(buf, 13) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR3)
	buffer_writef32(buf._buffer, buf._writeOffset + 1, value.X)
	buffer_writef32(buf._buffer, buf._writeOffset + 5, value.Y)
	buffer_writef32(buf._buffer, buf._writeOffset + 9, value.Z)
	buf._writeOffset += 13
	return true
end

function writers.addVector2(buf: Buffer, value: Vector2): boolean
	if buf._writeOffset + 9 > buffer_len(buf._buffer) then
		if not Alloc(buf, 9) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR2)
	buffer_writef32(buf._buffer, buf._writeOffset + 1, value.X)
	buffer_writef32(buf._buffer, buf._writeOffset + 5, value.Y)
	buf._writeOffset += 9
	return true
end

-- CUSTOM VECTOR/CFRAME TYPES, Added in update 1.2.0
function writers.addVector2F16(buf: Buffer, value: Vector2): boolean
	if buf._writeOffset + 5 > buffer_len(buf._buffer) then
		if not Alloc(buf, 5) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR2F16)
	WriteF16Data(buf._buffer, buf._writeOffset + 1, value.X)
	WriteF16Data(buf._buffer, buf._writeOffset + 3, value.Y)
	buf._writeOffset += 5
	return true
end

function writers.addVector3F16(buf: Buffer, value: Vector3): boolean
	if buf._writeOffset + 7 > buffer_len(buf._buffer) then
		if not Alloc(buf, 7) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR3F16)
	WriteF16Data(buf._buffer, buf._writeOffset + 1, value.X)
	WriteF16Data(buf._buffer, buf._writeOffset + 3, value.Y)
	WriteF16Data(buf._buffer, buf._writeOffset + 5, value.Z)
	buf._writeOffset += 7
	return true
end

function writers.addVector2F24(buf: Buffer, value: Vector2): boolean
	if buf._writeOffset + 7 > buffer_len(buf._buffer) then
		if not Alloc(buf, 7) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR2F24)
	WriteF24Data(buf._buffer, buf._writeOffset + 1, value.X)
	WriteF24Data(buf._buffer, buf._writeOffset + 4, value.Y)
	buf._writeOffset += 7
	return true
end

function writers.addVector3F24(buf: Buffer, value: Vector3): boolean
	if buf._writeOffset + 10 > buffer_len(buf._buffer) then
		if not Alloc(buf, 10) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR3F24)
	WriteF24Data(buf._buffer, buf._writeOffset + 1, value.X)
	WriteF24Data(buf._buffer, buf._writeOffset + 4, value.Y)
	WriteF24Data(buf._buffer, buf._writeOffset + 7, value.Z)
	buf._writeOffset += 10
	return true
end

function writers.addVector2I16(buf: Buffer, value: Vector2int16): boolean
	if buf._writeOffset + 5 > buffer_len(buf._buffer) then
		if not Alloc(buf, 5) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR2I16)
	buffer_writei16(buf._buffer, buf._writeOffset + 1, value.X)
	buffer_writei16(buf._buffer, buf._writeOffset + 3, value.Y)
	buf._writeOffset += 5
	return true
end

function writers.addVector3I16(buf: Buffer, value: Vector3int16): boolean
	if buf._destroyed then return false end
	if buf._writeOffset + 7 > buffer_len(buf._buffer) then
		if not Alloc(buf, 7) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, VECTOR3I16)
	buffer_writei16(buf._buffer, buf._writeOffset + 1, value.X)
	buffer_writei16(buf._buffer, buf._writeOffset + 3, value.Y)
	buffer_writei16(buf._buffer, buf._writeOffset + 5, value.Z)
	buf._writeOffset += 7
	return true
end

function writers.addCFrame(buf: Buffer, value: CFrame): boolean
	if buf._writeOffset + 19 > buffer_len(buf._buffer) then
		if not Alloc(buf, 19) then return false end
	end

	local rx, ry, rz = value:ToEulerAnglesXYZ()

	buffer_writeu8(buf._buffer, buf._writeOffset, CFRAME)
	buffer_writeu16(buf._buffer, buf._writeOffset + 1, rx * CFRAME_SCALE + 0.5)
	buffer_writeu16(buf._buffer, buf._writeOffset + 3, ry * CFRAME_SCALE + 0.5)
	buffer_writeu16(buf._buffer, buf._writeOffset + 5, rz * CFRAME_SCALE + 0.5)
	buffer_writef32(buf._buffer, buf._writeOffset + 7, value.X)
	buffer_writef32(buf._buffer, buf._writeOffset + 11, value.Y)
	buffer_writef32(buf._buffer, buf._writeOffset + 15, value.Z)
	buf._writeOffset += 19

	return true
end

function writers.addCFrameF16U8(buf: Buffer, value: CFrame): boolean
	if buf._writeOffset + 10 > buffer_len(buf._buffer) then
		if not Alloc(buf, 10) then return false end
	end

	local rx, ry, rz = value:ToEulerAnglesXYZ()

	buffer_writeu8(buf._buffer, buf._writeOffset, CFRAMEF16U8)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, rx * CFRAME_SCALE_U8 + 0.5)
	buffer_writeu8(buf._buffer, buf._writeOffset + 2, ry * CFRAME_SCALE_U8 + 0.5)
	buffer_writeu8(buf._buffer, buf._writeOffset + 3, rz * CFRAME_SCALE_U8 + 0.5)
	WriteF16Data(buf._buffer, buf._writeOffset + 4, value.X)
	WriteF16Data(buf._buffer, buf._writeOffset + 6, value.Y)
	WriteF16Data(buf._buffer, buf._writeOffset + 8, value.Z)
	buf._writeOffset += 10

	return true
end

function writers.addCFrameF24U8(buf: Buffer, value: CFrame): boolean
	if buf._writeOffset + 13 > buffer_len(buf._buffer) then
		if not Alloc(buf, 13) then return false end
	end

	local rx, ry, rz = value:ToEulerAnglesXYZ()

	buffer_writeu8(buf._buffer, buf._writeOffset, CFRAMEF24U8)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, rx * CFRAME_SCALE_U8 + 0.5)
	buffer_writeu8(buf._buffer, buf._writeOffset + 2, ry * CFRAME_SCALE_U8 + 0.5)
	buffer_writeu8(buf._buffer, buf._writeOffset + 3, rz * CFRAME_SCALE_U8 + 0.5)
	WriteF24Data(buf._buffer, buf._writeOffset + 4, value.X)
	WriteF24Data(buf._buffer, buf._writeOffset + 7, value.Y)
	WriteF24Data(buf._buffer, buf._writeOffset + 10, value.Z)
	buf._writeOffset += 13

	return true
end

function writers.addCFrameF16U16(buf: Buffer, value: CFrame): boolean
	if buf._writeOffset + 13 > buffer_len(buf._buffer) then
		if not Alloc(buf, 13) then return false end
	end

	local rx, ry, rz = value:ToEulerAnglesXYZ()

	buffer_writeu8(buf._buffer, buf._writeOffset, CFRAMEF16U16)
	buffer_writeu16(buf._buffer, buf._writeOffset + 1, rx * CFRAME_SCALE + 0.5)
	buffer_writeu16(buf._buffer, buf._writeOffset + 3, ry * CFRAME_SCALE + 0.5)
	buffer_writeu16(buf._buffer, buf._writeOffset + 5, rz * CFRAME_SCALE + 0.5)
	WriteF16Data(buf._buffer, buf._writeOffset + 7, value.X)
	WriteF16Data(buf._buffer, buf._writeOffset + 9, value.Y)
	WriteF16Data(buf._buffer, buf._writeOffset + 11, value.Z)
	buf._writeOffset += 13

	return true
end

function writers.addCFrameF24U16(buf: Buffer, value: CFrame): boolean
	if buf._writeOffset + 16 > buffer_len(buf._buffer) then
		if not Alloc(buf, 16) then return false end
	end

	local rx, ry, rz = value:ToEulerAnglesXYZ()

	buffer_writeu8(buf._buffer, buf._writeOffset, CFRAMEF24U16)
	buffer_writeu16(buf._buffer, buf._writeOffset + 1, rx * CFRAME_SCALE + 0.5)
	buffer_writeu16(buf._buffer, buf._writeOffset + 3, ry * CFRAME_SCALE + 0.5)
	buffer_writeu16(buf._buffer, buf._writeOffset + 5, rz * CFRAME_SCALE + 0.5)
	WriteF24Data(buf._buffer, buf._writeOffset + 7, value.X)
	WriteF24Data(buf._buffer, buf._writeOffset + 10, value.Y)
	WriteF24Data(buf._buffer, buf._writeOffset + 13, value.Z)
	buf._writeOffset += 16

	return true
end

function writers.addColor3(buf: Buffer, value: Color3): boolean
	if buf._writeOffset + 4 > buffer_len(buf._buffer) then
		if not Alloc(buf, 4) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, COLOR3)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, value.R * FLOAT_TO_BYTE_SCALE + 0.5)
	buffer_writeu8(buf._buffer, buf._writeOffset + 2, value.G * FLOAT_TO_BYTE_SCALE + 0.5)
	buffer_writeu8(buf._buffer, buf._writeOffset + 3, value.B * FLOAT_TO_BYTE_SCALE + 0.5)
	buf._writeOffset += 4
	return true
end

function writers.addNumberSequence(buf: Buffer, value: NumberSequence): boolean

	local len = #value.Keypoints
	local requiredBytes = 2 + len * 3

	if buf._writeOffset + requiredBytes > buffer_len(buf._buffer) then
		if not Alloc(buf, requiredBytes) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_SEQUENCE)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, len)

	local offset = buf._writeOffset + 2
	for _, keypoint in ipairs(value.Keypoints) do
		buffer_writeu8(buf._buffer, offset, keypoint.Time * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(buf._buffer, offset + 1, keypoint.Value * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(buf._buffer, offset + 2, keypoint.Envelope * FLOAT_TO_BYTE_SCALE + 0.5)
		offset += 3
	end

	buf._writeOffset += requiredBytes
	return true
end

function writers.addColorSequence(buf: Buffer, value: ColorSequence): boolean

	local len = #value.Keypoints
	local requiredBytes = 2 + len * 4

	if buf._writeOffset + requiredBytes > buffer_len(buf._buffer) then
		if not Alloc(buf, requiredBytes) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, COLOR_SEQUENCE)
	buffer_writeu8(buf._buffer, buf._writeOffset + 1, len)

	local offset = buf._writeOffset + 2
	for _, keypoint in ipairs(value.Keypoints) do
		buffer_writeu8(buf._buffer, offset, keypoint.Time * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(buf._buffer, offset + 1, keypoint.Value.R * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(buf._buffer, offset + 2, keypoint.Value.G * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(buf._buffer, offset + 3, keypoint.Value.B * FLOAT_TO_BYTE_SCALE + 0.5)
		offset += 4
	end

	buf._writeOffset += requiredBytes
	return true
end

function writers.addUDim(buf: Buffer, value: UDim): boolean
	if buf._writeOffset + 5 > buffer_len(buf._buffer) then
		if not Alloc(buf, 5) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, UDIM)
	buffer_writei16(buf._buffer, buf._writeOffset + 1, value.Scale * UDIM_SCALE)
	buffer_writei16(buf._buffer, buf._writeOffset + 3, value.Offset)
	buf._writeOffset += 5
	return true
end

function writers.addUDim2(buf: Buffer, value: UDim2): boolean
	if buf._writeOffset + 9 > buffer_len(buf._buffer) then
		if not Alloc(buf, 9) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, UDIM2)
	buffer_writei16(buf._buffer, buf._writeOffset + 1, value.X.Scale * UDIM_SCALE)
	buffer_writei16(buf._buffer, buf._writeOffset + 3, value.X.Offset)
	buffer_writei16(buf._buffer, buf._writeOffset + 5, value.Y.Scale * UDIM_SCALE)
	buffer_writei16(buf._buffer, buf._writeOffset + 7, value.Y.Offset)
	buf._writeOffset += 9
	return true
end

function writers.addRect(buf: Buffer, value: Rect): boolean
	if buf._writeOffset + 17 > buffer_len(buf._buffer) then
		if not Alloc(buf, 17) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, RECT)
	buffer_writef32(buf._buffer, buf._writeOffset + 1, value.Min.X)
	buffer_writef32(buf._buffer, buf._writeOffset + 5, value.Min.Y)
	buffer_writef32(buf._buffer, buf._writeOffset + 9, value.Max.X)
	buffer_writef32(buf._buffer, buf._writeOffset + 13, value.Max.Y)
	buf._writeOffset += 17
	return true
end

function writers.addNumberRange(buf: Buffer, value: NumberRange): boolean
	if buf._writeOffset + 9 > buffer_len(buf._buffer) then
		if not Alloc(buf, 9) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_RANGE)
	buffer_writef32(buf._buffer, buf._writeOffset + 1, value.Min)
	buffer_writef32(buf._buffer, buf._writeOffset + 5, value.Max)
	buf._writeOffset += 9
	return true
end


function writers.addBrickColor(buf: Buffer, value: BrickColor): boolean
	if buf._writeOffset + 3 > buffer_len(buf._buffer) then
		if not Alloc(buf, 3) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, BRICK_COLOR)
	buffer_writeu16(buf._buffer, buf._writeOffset + 1, value.Number)
	buf._writeOffset += 3
	return true
end


function writers.addTable(buf: Buffer, value: {[any]: any}): boolean
	if buf._writeOffset + 1 > buffer_len(buf._buffer) then
		if not Alloc(buf, 1) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, TABLE)
	buf._writeOffset += 1

	for key, val in pairs(value) do
		local keyType = typeof(key)
		if keyType == "number" then
			if not writers.addNumber(buf, key) then return false end
		elseif keyType == "string" then
			if not writers.addString(buf, key) then return false end
		elseif keyType == "boolean" then
			if not writers.addBoolean(buf, key) then return false end
		else
			if not writers.addString(buf, tostring(key)) then return false end
		end

		local valType = typeof(val)
		if valType == "number" then
			if not writers.addNumber(buf, val) then return false end
		elseif valType == "string" then
			if not writers.addString(buf, val) then return false end
		elseif valType == "boolean" then
			if not writers.addBoolean(buf, val) then return false end
		elseif valType == "Vector3" then
			if not writers.addVector3(buf, val) then return false end
		elseif valType == "Vector2" then
			if not writers.addVector2(buf, val) then return false end
		elseif valType == "Color3" then
			if not writers.addColor3(buf, val) then return false end
		elseif valType == "CFrame" then
			if not writers.addCFrame(buf, val) then return false end
		elseif valType == "UDim" then
			if not writers.addUDim(buf, val) then return false end
		elseif valType == "UDim2" then
			if not writers.addUDim2(buf, val) then return false end
		elseif valType == "Rect" then
			if not writers.addRect(buf, val) then return false end
		elseif valType == "NumberRange" then
			if not writers.addNumberRange(buf, val) then return false end
		elseif valType == "NumberSequence" then
			if not writers.addNumberSequence(buf, val) then return false end
		elseif valType == "ColorSequence" then
			if not writers.addColorSequence(buf, val) then return false end
		elseif valType == "BrickColor" then
			if not writers.addBrickColor(buf, val) then return false end
		elseif valType == "table" then
			if not writers.addTable(buf, val) then return false end
		elseif valType == "Vector3int16" then
			if not writers.addVector3I16(buf, val) then return false end
		elseif valType == "Vector2int16" then
			if not writers.addVector2I16(buf, val) then return false end
		else
			if not writers.addString(buf, tostring(val)) then return false end
		end
	end

	if buf._writeOffset + 1 > buffer_len(buf._buffer) then
		if not Alloc(buf, 1) then return false end
	end

	buffer_writeu8(buf._buffer, buf._writeOffset, NIL)
	buf._writeOffset += 1
	return true
end

-- creates BinBuffer object from basic buffer
local function fromBuffer(buf: buffer): Buffer?
	local originalBuffer = buf
	local bufferSize = buffer_len(originalBuffer)

	if bufferSize == 0 then
		return nil
	end

	local function PeekU8(offset: number): number?
		if offset >= bufferSize then return nil end
		return buffer_readu8(originalBuffer, offset)
	end

	local function ParseData(startOffset: number): (any?, number, number, {Instance})
		local offset = startOffset
		local instancesArray = {}
		local instancesOffset = 0
		local object = nil

		local dataType = PeekU8(offset)
		if not dataType then return nil, offset - startOffset, instancesOffset, instancesArray end

		offset += 1

		local function ReadU8(): number
			local value = buffer_readu8(originalBuffer, offset)
			offset += 1
			return value
		end

		local function ReadU16(): number
			local value = buffer_readu16(originalBuffer, offset)
			offset += 2
			return value
		end

		local function ReadU32(): number
			local value = buffer_readu32(originalBuffer, offset)
			offset += 4
			return value
		end

		local function ReadI8(): number
			local value = buffer_readi8(originalBuffer, offset)
			offset += 1
			return value
		end

		local function ReadI16(): number
			local value = buffer_readi16(originalBuffer, offset)
			offset += 2
			return value
		end

		local function ReadI32(): number
			local value = buffer_readi32(originalBuffer, offset)
			offset += 4
			return value
		end

		local function ReadF32(): number
			local value = buffer_readf32(originalBuffer, offset)
			offset += 4
			return value
		end

		local function ReadF64(): number
			local value = buffer_readf64(originalBuffer, offset)
			offset += 8
			return value
		end

		local function ReadString(length: number): string
			local value = buffer_readstring(originalBuffer, offset, length)
			offset += length
			return value
		end

		local function ReadF16(): number
			local bitOffset = offset * 8
			offset += 2

			local mantissa = buffer_readbits(originalBuffer, bitOffset, 10)
			local exponent = buffer_readbits(originalBuffer, bitOffset + 10, 5)
			local sign = buffer_readbits(originalBuffer, bitOffset + 15, 1)

			if exponent == 0 and mantissa == 0 then
				return 0
			end
			if exponent == 31 then
				return 0/0
			end

			local value = (mantissa / 1024 + 1) * 2 ^ (exponent - 15)
			return sign == 0 and value or -value
		end

		local function ReadF24(): number
			local bitOffset = offset * 8
			offset += 3

			local mantissa = buffer_readbits(originalBuffer, bitOffset, 17)
			local exponent = buffer_readbits(originalBuffer, bitOffset + 17, 6)
			local sign = buffer_readbits(originalBuffer, bitOffset + 23, 1)

			if exponent == 0 and mantissa == 0 then
				return 0
			end
			if exponent == 63 then
				return 0/0
			end

			local value = (mantissa / 131072 + 1) * 2 ^ (exponent - 31)
			return sign == 0 and value or -value
		end

		local function ReadValue(valueType: number): (any?, boolean)
			if valueType == NIL then
				return nil, true
			elseif valueType == BOOLEAN then
				return ReadU8() == 1, true
			elseif valueType == NUMBER_I8 then
				return ReadI8(), true
			elseif valueType == NUMBER_I16 then
				return ReadI16(), true
			elseif valueType == NUMBER_I32 then
				return ReadI32(), true
			elseif valueType == NUMBER_U8 then
				return ReadU8(), true
			elseif valueType == NUMBER_U16 then
				return ReadU16(), true
			elseif valueType == NUMBER_U24 then
				return ReadU24(buf, offset), true
			elseif valueType == NUMBER_I24 then
				return ReadI24(buf, offset), true
			elseif valueType == NUMBER_U32 then
				return ReadU32(), true
			elseif valueType == NUMBER_F16 then
				return ReadF16(), true
			elseif valueType == NUMBER_F24 then
				return ReadF24(), true
			elseif valueType == NUMBER_F32 then
				return ReadF32(), true
			elseif valueType == NUMBER_F64 then
				return ReadF64(), true
			elseif valueType == STRING then
				return ReadString(ReadU8()), true
			elseif valueType == STRING_LONG then
				return ReadString(ReadU16()), true
			elseif valueType == VECTOR2 then
				return Vector2.new(ReadF32(), ReadF32()), true
			elseif valueType == VECTOR3 then
				return Vector3.new(ReadF32(), ReadF32(), ReadF32()), true
			elseif valueType == COLOR3 then
				return Color3.fromRGB(ReadU8(), ReadU8(), ReadU8()), true
			elseif valueType == UDIM then
				return UDim.new(ReadI16() * UDIM_INV_SCALE, ReadI16()), true
			elseif valueType == UDIM2 then
				return UDim2.new(ReadI16() * UDIM_INV_SCALE, ReadI16(), ReadI16() * UDIM_INV_SCALE, ReadI16()), true
			elseif valueType == CFRAME then
				local rx = ReadU16() * CFRAME_INV_SCALE
				local ry = ReadU16() * CFRAME_INV_SCALE
				local rz = ReadU16() * CFRAME_INV_SCALE
				return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF32(), ReadF32(), ReadF32()), true
			elseif valueType == CFRAMEF16U8 then
				local rx = ReadU8() / CFRAME_INV_SCALE_U8
				local ry = ReadU8() / CFRAME_INV_SCALE_U8
				local rz = ReadU8() / CFRAME_INV_SCALE_U8
				return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF16(), ReadF16(), ReadF16()), true
			elseif valueType == CFRAMEF24U8 then
				local rx = ReadU8() / CFRAME_INV_SCALE_U8
				local ry = ReadU8() / CFRAME_INV_SCALE_U8
				local rz = ReadU8() / CFRAME_INV_SCALE_U8
				return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF24(), ReadF24(), ReadF24()), true
			elseif valueType == CFRAMEF16U16 then
				local rx = ReadU16() / CFRAME_INV_SCALE
				local ry = ReadU16() / CFRAME_INV_SCALE
				local rz = ReadU16() / CFRAME_INV_SCALE
				return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF16(), ReadF16(), ReadF16()), true
			elseif valueType == CFRAMEF24U16 then
				local rx = ReadU16() / CFRAME_INV_SCALE
				local ry = ReadU16() / CFRAME_INV_SCALE
				local rz = ReadU16() / CFRAME_INV_SCALE
				return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF24(), ReadF24(), ReadF24()), true
			elseif valueType == RECT then
				return Rect.new(ReadF32(), ReadF32(), ReadF32(), ReadF32()), true
			elseif valueType == NUMBER_RANGE then
				return NumberRange.new(ReadF32(), ReadF32()), true
			elseif valueType == NUMBER_SEQUENCE then
				local length = ReadU8()
				local keypoints = {}
				for i = 1, length do
					table_insert(keypoints, NumberSequenceKeypoint.new(
						ReadU8() * FLOAT_FROM_BYTE_SCALE,
						ReadU8() * FLOAT_FROM_BYTE_SCALE,
						ReadU8() * FLOAT_FROM_BYTE_SCALE
						))
				end
				return NumberSequence.new(keypoints), true
			elseif valueType == COLOR_SEQUENCE then
				local length = ReadU8()
				local keypoints = {}
				for i = 1, length do
					table_insert(keypoints, ColorSequenceKeypoint.new(
						ReadU8() * FLOAT_FROM_BYTE_SCALE,
						Color3.fromRGB(ReadU8(), ReadU8(), ReadU8())
						))
				end
				return ColorSequence.new(keypoints), true
			elseif valueType == BRICK_COLOR then
				return BrickColor.new(ReadU16()), true
			elseif valueType == VECTOR2F16 then
				return Vector2.new(ReadF16(), ReadF16()), true
			elseif valueType == VECTOR2F24 then
				return Vector2.new(ReadF24(), ReadF24()), true
			elseif valueType == VECTOR2I16 then
				return Vector2int16.new(ReadI16(), ReadI16()), true
			elseif valueType == VECTOR3F16 then
				return Vector3.new(ReadF16(), ReadF16(), ReadF16()), true
			elseif valueType == VECTOR3F24 then
				return Vector3.new(ReadF24(), ReadF24(), ReadF24()), true
			elseif valueType == VECTOR3I16 then
				return Vector3int16.new(ReadI16(), ReadI16(), ReadI16()), true
			elseif valueType == TABLE then
				local tbl = {}
				while offset < bufferSize do
					local keyType = PeekU8(offset)
					if not keyType or keyType == NIL then
						if keyType == NIL then
							offset += 1
						end
						break
					end

					local key, success = ReadValue(keyType)
					if not success then break end

					local valueType = PeekU8(offset)
					if not valueType then break end

					local value, success2 = ReadValue(valueType)
					if not success2 then break end

					tbl[key] = value
				end
				return tbl, true
			else
				return nil, false
			end
		end

		if dataType == NIL then
			object = nil
		else
			object, _ = ReadValue(dataType)
		end

		return object, offset - startOffset, instancesOffset, instancesArray
	end

	local readOffset = 0
	local totalInstancesOffset = 0
	local allInstances = {}

	while readOffset < bufferSize do
		local object, bytesRead, instancesRead, instancesArray = ParseData(readOffset)
		if not bytesRead or bytesRead == 0 then break end

		readOffset += bytesRead
		totalInstancesOffset += instancesRead

		for i = 1, instancesRead do
			table_insert(allInstances, instancesArray[i])
		end
	end

	local dataSize = readOffset

	local dataBuffer = buffer_create(bufferSize)
	buffer_copy(dataBuffer, 0, originalBuffer, 0, bufferSize)

	return {
		_buffer = dataBuffer,
		_callback = function() end,
		_maxSize = megabytes(32),
		_size = bufferSize,
		_destroyed = false,
		_writeOffset = dataSize,
	}
end

-- creates a basic buffer from BinBuffer
local function tobuffer(buf: Buffer): buffer
	return	buf._buffer
end

-- reads all data from BinBuffer
local function read(buf: Buffer): {any}
	local objects = {}
	local offset = 0

	local function ReadU8(): number
		local value = buffer_readu8(buf._buffer, offset)
		offset += 1
		return value
	end

	local function ReadU16(): number
		local value = buffer_readu16(buf._buffer, offset)
		offset += 2
		return value
	end

	local function ReadU32(): number
		local value = buffer_readu32(buf._buffer, offset)
		offset += 4
		return value
	end

	local function ReadI8(): number
		local value = buffer_readi8(buf._buffer, offset)
		offset += 1
		return value
	end

	local function ReadI16(): number
		local value = buffer_readi16(buf._buffer, offset)
		offset += 2
		return value
	end

	local function ReadI32(): number
		local value = buffer_readi32(buf._buffer, offset)
		offset += 4
		return value
	end

	local function ReadF32(): number
		local value = buffer_readf32(buf._buffer, offset)
		offset += 4
		return value
	end

	local function ReadF64(): number
		local value = buffer_readf64(buf._buffer, offset)
		offset += 8
		return value
	end

	local function ReadString(length: number): string
		local value = buffer_readstring(buf._buffer, offset, length)
		offset += length
		return value
	end

	local function ReadF16(): number
		local bitOffset = offset * 8
		offset += 2

		local mantissa = buffer_readbits(buf._buffer, bitOffset, 10)
		local exponent = buffer_readbits(buf._buffer, bitOffset + 10, 5)
		local sign = buffer_readbits(buf._buffer, bitOffset + 15, 1)

		if exponent == 0 and mantissa == 0 then
			return 0
		end
		if exponent == 31 then
			return 0/0
		end

		local value = (mantissa / 1024 + 1) * 2 ^ (exponent - 15)
		return sign == 0 and value or -value
	end

	local function ReadF24(): number
		local bitOffset = offset * 8
		offset += 3

		local mantissa = buffer_readbits(buf._buffer, bitOffset, 17)
		local exponent = buffer_readbits(buf._buffer, bitOffset + 17, 6)
		local sign = buffer_readbits(buf._buffer, bitOffset + 23, 1)

		if exponent == 0 and mantissa == 0 then
			return 0
		end
		if exponent == 63 then
			return 0/0
		end

		local value = (mantissa / 131072 + 1) * 2 ^ (exponent - 31)
		return sign == 0 and value or -value
	end


	local READERS
	READERS = {
		[NIL] = function() return nil end,
		[BOOLEAN] = function() return ReadU8() == 1 end,
		[NUMBER_I8] = ReadI8,
		[NUMBER_I16] = ReadI16,
		[NUMBER_I32] = ReadI32,
		[NUMBER_U8] = ReadU8,
		[NUMBER_U16] = ReadU16,
		[NUMBER_U32] = ReadU32,
		[NUMBER_F16] = ReadF16,
		[NUMBER_F24] = ReadF24,
		[NUMBER_F32] = ReadF32,
		[NUMBER_U24] = function() return ReadU24(buf._buffer, offset) end,
		[NUMBER_I24] = function() return ReadI24(buf._buffer, offset) end,
		[NUMBER_F64] = ReadF64,
		[STRING] = function() return ReadString(ReadU8()) end,
		[STRING_LONG] = function() return ReadString(ReadU16()) end,
		[VECTOR2] = function() return Vector2.new(ReadF32(), ReadF32()) end,
		[VECTOR3] = function() return Vector3.new(ReadF32(), ReadF32(), ReadF32()) end,
		[VECTOR2F16] = function() return Vector2.new(ReadF16(), ReadF16()) end,
		[VECTOR2F24] = function() return Vector2.new(ReadF24(), ReadF24()) end,
		[VECTOR2I16] = function() return Vector2int16.new(ReadI16(), ReadI16()) end,
		[VECTOR3F16] = function() return Vector3.new(ReadF16(), ReadF16(), ReadF16()) end,
		[VECTOR3F24] = function() return Vector3.new(ReadF24(), ReadF24(), ReadF24()) end,
		[VECTOR3I16] = function() return Vector3int16.new(ReadI16(), ReadI16(), ReadI16()) end,
		[COLOR3] = function() return Color3.fromRGB(ReadU8(), ReadU8(), ReadU8()) end,
		[UDIM] = function() return UDim.new(ReadI16() * UDIM_INV_SCALE, ReadI16()) end,
		[UDIM2] = function() return UDim2.new(ReadI16() * UDIM_INV_SCALE, ReadI16(), ReadI16() * UDIM_INV_SCALE, ReadI16()) end,
		[CFRAME] = function()
			local rx = ReadU16() / CFRAME_INV_SCALE
			local ry = ReadU16() / CFRAME_INV_SCALE
			local rz = ReadU16() / CFRAME_INV_SCALE
			return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF32(), ReadF32(), ReadF32())
		end,
		[CFRAMEF16U8] = function()
			local rx = ReadU8() / CFRAME_INV_SCALE_U8
			local ry = ReadU8() / CFRAME_INV_SCALE_U8
			local rz = ReadU8() / CFRAME_INV_SCALE_U8
			return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF16(), ReadF16(), ReadF16())
		end,
		[CFRAMEF24U8] = function()
			local rx = ReadU8() / CFRAME_INV_SCALE_U8
			local ry = ReadU8() / CFRAME_INV_SCALE_U8
			local rz = ReadU8() / CFRAME_INV_SCALE_U8
			return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF24(), ReadF24(), ReadF24())
		end,
		[CFRAMEF16U16] = function()
			local rx = ReadU16() / CFRAME_INV_SCALE
			local ry = ReadU16() / CFRAME_INV_SCALE
			local rz = ReadU16() / CFRAME_INV_SCALE
			return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF16(), ReadF16(), ReadF16())
		end,
		[CFRAMEF24U16] = function()
			local rx = ReadU16() / CFRAME_INV_SCALE
			local ry = ReadU16() / CFRAME_INV_SCALE
			local rz = ReadU16() / CFRAME_INV_SCALE
			return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF24(), ReadF24(), ReadF24())
		end,
		[RECT] = function() return Rect.new(ReadF32(), ReadF32(), ReadF32(), ReadF32()) end,
		[NUMBER_RANGE] = function() return NumberRange.new(ReadF32(), ReadF32()) end,
		[NUMBER_SEQUENCE] = function()
			local length = ReadU8()
			local keypoints = {}
			for i = 1, length do
				table_insert(keypoints, NumberSequenceKeypoint.new(
					ReadU8() * FLOAT_FROM_BYTE_SCALE,
					ReadU8() * FLOAT_FROM_BYTE_SCALE,
					ReadU8() * FLOAT_FROM_BYTE_SCALE
					))
			end
			return NumberSequence.new(keypoints)
		end,
		[COLOR_SEQUENCE] = function()
			local length = ReadU8()
			local keypoints = {}
			for i = 1, length do
				table_insert(keypoints, ColorSequenceKeypoint.new(
					ReadU8() * FLOAT_FROM_BYTE_SCALE,
					Color3.fromRGB(ReadU8(), ReadU8(), ReadU8())
					))
			end
			return ColorSequence.new(keypoints)
		end,
		[BRICK_COLOR] = function() return BrickColor.new(ReadU16()) end,
		[TABLE] = function()
			local tbl = {}
			while offset < buf._writeOffset do
				local keyType = ReadU8()
				if keyType == NIL then break end

				local keyReader = READERS[keyType]
				if not keyReader then break end

				local key = keyReader()
				local valueType = ReadU8()
				local valueReader = READERS[valueType]

				if not valueReader then break end
				tbl[key] = valueReader()
			end
			return tbl
		end,
	}

	while offset < buf._writeOffset do
		local dataType = ReadU8()
		local reader = READERS[dataType]

		if not reader then break end

		local object = reader()
		if object == nil then break end

		table_insert(objects, object)
	end

	return objects
end



-- API
return {
	writers = writers,
	read = read,
	bytes = bytes,
	kilobytes = kilobytes,
	megabytes = megabytes,
	destroy = destroy,
	clear = clear,
	fromBuffer = fromBuffer,
	tobuffer = tobuffer,
	create = create,
	with_capacity = with_capacity,
	

	NIL = 0,
	BOOLEAN = 1,
	NUMBER_I8 = 2,
	NUMBER_I16 = 3,
	NUMBER_I32 = 4,
	NUMBER_U8 = 5,
	NUMBER_U16 = 6,
	NUMBER_U32 = 7,
	NUMBER_F16 = 8,
	NUMBER_F24 = 9,
	NUMBER_F32 = 10,
	NUMBER_F64 = 11,
	STRING = 12,
	STRING_LONG = 13,
	VECTOR2 = 14,
	VECTOR3 = 15,
	COLOR3 = 16,
	UDIM = 17,
	UDIM2 = 18,
	CFRAME = 19,
	RECT = 20,
	NUMBER_RANGE = 21,
	NUMBER_SEQUENCE = 22,
	COLOR_SEQUENCE = 23,
	BRICK_COLOR = 24,
	TABLE = 25,
	VECTOR2F16 = 26,
	VECTOR3F16 = 27,
	VECTOR2F24 = 28,
	VECTOR3F24 = 29,
	VECTOR2I16 = 30,
	VECTOR3I16 = 31,
	CFRAMEF16U8 = 32,
	CFRAMEF24U8 = 33,
	CFRAMEF16U16 = 34,
	CFRAMEF24U16 = 35,
	NUMBER_I24 = 36,
	NUMBER_U24 = 37
}