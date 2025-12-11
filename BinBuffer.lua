--!strict
--!optimize 2


-- types
export type Buffer = {
	_buffer: buffer,
	_maxSize: number,
	_callback: (buffer: buffer) -> (),
	_flushTask: thread?,
	_destroyed: boolean,
	_writeOffset: number,
	_instances: {Instance},
	_instancesOffset: number,

	Flush: (self: Buffer) -> boolean,
	Destroy: (self: Buffer) -> (),
	Clear: (self: Buffer) -> (),
	AddNumber: (self: Buffer, value: number) -> boolean,
	AddBoolean: (self: Buffer, value: boolean) -> boolean,
	AddString: (self: Buffer, value: string) -> boolean,
	AddVector3: (self: Buffer, value: Vector3) -> boolean,
	AddVector2: (self: Buffer, value: Vector2) -> boolean,
	AddCFrame: (self: Buffer, value: CFrame) -> boolean,
	AddColor3: (self: Buffer, value: Color3) -> boolean,
	AddUDim: (self: Buffer, value: UDim) -> boolean,
	AddUDim2: (self: Buffer, value: UDim2) -> boolean,
	AddRect: (self: Buffer, value: Rect) -> boolean,
	AddNumberRange: (self: Buffer, value: NumberRange) -> boolean,
	AddNumberSequence: (self: Buffer, value: NumberSequence) -> boolean,
	AddColorSequence: (self: Buffer, value: ColorSequence) -> boolean,
	AddBrickColor: (self: Buffer, value: BrickColor) -> boolean,
	AddInstance: (self: Buffer, value: Instance) -> boolean,
	AddTable: (self: Buffer, value: {[any]: any}) -> boolean,
	AddNil: (self: Buffer) -> boolean,
}

local Buffer = {}
Buffer.__index = Buffer

local buffer_create = buffer.create
local buffer_copy = buffer.copy
local buffer_len = buffer.len
local buffer_writeu8 = buffer.writeu8
local buffer_writeu16 = buffer.writeu16
local buffer_writeu32 = buffer.writeu32
local buffer_writei8 = buffer.writei8
local buffer_writei16 = buffer.writei16
local buffer_writei32 = buffer.writei32
local buffer_writef32 = buffer.writef32
local buffer_writef64 = buffer.writef64
local buffer_writestring = buffer.writestring
local buffer_writebits = buffer.writebits

local buffer_readu8 = buffer.readu8
local buffer_readu16 = buffer.readu16
local buffer_readu32 = buffer.readu32
local buffer_readi8 = buffer.readi8
local buffer_readi16 = buffer.readi16
local buffer_readi32 = buffer.readi32
local buffer_readf32 = buffer.readf32
local buffer_readf64 = buffer.readf64
local buffer_readstring = buffer.readstring
local buffer_readbits = buffer.readbits

local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_abs = math.abs
local math_frexp = math.frexp
local table_insert = table.insert
local table_clear = table.clear
local ipairs = ipairs
local pairs = pairs
local task_cancel = task.cancel
local string_len = string.len

local NIL = 0
local BOOLEAN = 1
local NUMBER_I8 = 2
local NUMBER_I16 = 3
local NUMBER_I32 = 5
local NUMBER_U8 = 6
local NUMBER_U16 = 7
local NUMBER_U32 = 9
local NUMBER_F16 = 10
local NUMBER_F24 = 11
local NUMBER_F32 = 12
local NUMBER_F64 = 13
local STRING = 14
local STRING_LONG = 15
local INSTANCE = 18
local VECTOR2 = 19
local VECTOR3 = 20
local COLOR3 = 21
local UDIM = 22
local UDIM2 = 23
local CFRAME = 24
local RECT = 25
local NUMBER_RANGE = 26
local NUMBER_SEQUENCE = 27
local COLOR_SEQUENCE = 28
local BRICK_COLOR = 29
local TABLE = 30

local INT8_MIN = -128
local INT32_MIN = -2147483648
local UINT8_MAX = 255
local UINT16_MAX = 65535
local UINT32_MAX = 4294967295
local MEGABYTE = 1048576
local MAX_REASONABLE_SIZE = 67108864
local CFRAME_SCALE = 10430.219195527361
local CFRAME_INV_SCALE = 9.587379924285257e-05
local UDIM_SCALE = 1000
local UDIM_INV_SCALE = 0.001
local FLOAT_TO_BYTE_SCALE = 255
local FLOAT_FROM_BYTE_SCALE = 0.00392156862745098

local function EnsureCapacity(buf: Buffer, requiredBytes: number): boolean
	local currentBufferSize = buffer_len(buf._buffer)
	local target_len = buf._writeOffset + requiredBytes

	if target_len > buf._maxSize then
		return false
	end

	if target_len > currentBufferSize then
		local currentSize = currentBufferSize
		local growthFactor = 1.5
		if currentSize > MEGABYTE then growthFactor = 1.25 end
		if currentSize > 10485760 then growthFactor = 1.1 end

		local newSize = math_floor(currentSize * growthFactor)
		newSize = math_max(newSize, target_len)
		newSize = math_floor(newSize / 64) * 64
		newSize = math_min(newSize, MAX_REASONABLE_SIZE)

		if newSize < target_len then
			return false
		end

		local newBuf = buffer_create(newSize)
		if not newBuf then
			return false
		end

		local bytes_to_copy = buf._writeOffset
		if bytes_to_copy > 0 then
			buffer_copy(newBuf, 0, buf._buffer, 0, bytes_to_copy)
		end

		buf._buffer = newBuf
	end

	return true
end

local function ClassifyNumber(value: number): number
	if value == value // 1 then
		if value >= 0 then
			if value <= UINT8_MAX then return 1
			elseif value <= UINT16_MAX then return 2
			elseif value <= UINT32_MAX then return 3
			else return 10 end
		else
			if value >= INT8_MIN then return 4
			elseif value >= INT32_MIN then return 5
			else return 10 end
		end
	else
		local absValue = math_abs(value)
		if absValue <= 65520 then return 6
		elseif absValue <= 4294959104 then return 7
		elseif absValue <= 3.4028235e38 then return 8
		else return 9 end
	end
end

local NUMBER_SIZES = {[1] = 2,[2] = 3,[3] = 5,[4] = 2,[5] = 5,[6] = 3,[7] = 4,[8] = 5,[9] = 9,[10] = 9}

local NUMBER_WRITERS = {
	[1] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U8)
		buffer_writeu8(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 2
		return true
	end,
	[2] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U16)
		buffer_writeu16(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 3
		return true
	end,
	[3] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_U32)
		buffer_writeu32(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 5
		return true
	end,
	[4] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_I8)
		buffer_writei8(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 2
		return true
	end,
	[5] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_I32)
		buffer_writei32(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 5
		return true
	end,
	[6] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F16)
		local bitOffset = buf._writeOffset * 8
		buf._writeOffset += 2
		if value == 0 then
			buffer_writebits(buf._buffer, bitOffset, 16, 0)
		elseif value ~= value then
			buffer_writebits(buf._buffer, bitOffset, 16, 31745)
		else
			local sign = 0
			if value < 0 then sign = 1 value = -value end
			local mantissa, exponent = math_frexp(value)
			buffer_writebits(buf._buffer, bitOffset + 0, 10, mantissa * 2048 - 1023.5)
			buffer_writebits(buf._buffer, bitOffset + 10, 5, exponent + 14)
			buffer_writebits(buf._buffer, bitOffset + 15, 1, sign)
		end
		return true
	end,
	[7] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F24)
		local bitOffset = buf._writeOffset * 8
		buf._writeOffset += 3
		if value == 0 then
			buffer_writebits(buf._buffer, bitOffset, 24, 0)
		elseif value ~= value then
			buffer_writebits(buf._buffer, bitOffset, 24, 8323073)
		else
			local sign = 0
			if value < 0 then sign = 1 value = -value end
			local mantissa, exponent = math_frexp(value)
			buffer_writebits(buf._buffer, bitOffset + 0, 17, mantissa * 262144 - 131071.5)
			buffer_writebits(buf._buffer, bitOffset + 17, 6, exponent + 30)
			buffer_writebits(buf._buffer, bitOffset + 23, 1, sign)
		end
		return true
	end,
	[8] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F32)
		buffer_writef32(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 5
		return true
	end,
	[9] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F64)
		buffer_writef64(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 9
		return true
	end,
	[10] = function(buf: Buffer, value: number)
		buffer_writeu8(buf._buffer, buf._writeOffset, NUMBER_F64)
		buffer_writef64(buf._buffer, buf._writeOffset + 1, value)
		buf._writeOffset += 9
		return true
	end,
}

function Buffer:AddNumber(value: number): boolean
	if self._destroyed then return false end
	local numType = ClassifyNumber(value)
	local requiredBytes = NUMBER_SIZES[numType]
	if self._writeOffset + requiredBytes > buffer_len(self._buffer) then
		if not EnsureCapacity(self, requiredBytes) then return false end
	end
	return NUMBER_WRITERS[numType](self, value)
end

function Buffer:AddBoolean(value: boolean): boolean
	if self._destroyed then return false end
	if self._writeOffset + 2 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 2) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, BOOLEAN)
	buffer_writeu8(self._buffer, self._writeOffset + 1, value and 1 or 0)
	self._writeOffset += 2
	return true
end

function Buffer:AddString(value: string): boolean
	if self._destroyed then return false end
	local len = string_len(value)
	if len < 256 then
		local requiredBytes = 2 + len
		if self._writeOffset + requiredBytes > buffer_len(self._buffer) then
			if not EnsureCapacity(self, requiredBytes) then return false end
		end
		buffer_writeu8(self._buffer, self._writeOffset, STRING)
		buffer_writeu8(self._buffer, self._writeOffset + 1, len)
		buffer_writestring(self._buffer, self._writeOffset + 2, value)
		self._writeOffset += requiredBytes
		return true
	else
		local requiredBytes = 3 + len
		if self._writeOffset + requiredBytes > buffer_len(self._buffer) then
			if not EnsureCapacity(self, requiredBytes) then return false end
		end
		buffer_writeu8(self._buffer, self._writeOffset, STRING_LONG)
		buffer_writeu16(self._buffer, self._writeOffset + 1, len)
		buffer_writestring(self._buffer, self._writeOffset + 3, value)
		self._writeOffset += requiredBytes
		return true
	end
end

function Buffer:AddVector3(value: Vector3): boolean
	if self._destroyed then return false end
	if self._writeOffset + 13 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 13) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, VECTOR3)
	buffer_writef32(self._buffer, self._writeOffset + 1, value.X)
	buffer_writef32(self._buffer, self._writeOffset + 5, value.Y)
	buffer_writef32(self._buffer, self._writeOffset + 9, value.Z)
	self._writeOffset += 13
	return true
end

function Buffer:AddVector2(value: Vector2): boolean
	if self._destroyed then return false end
	if self._writeOffset + 9 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 9) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, VECTOR2)
	buffer_writef32(self._buffer, self._writeOffset + 1, value.X)
	buffer_writef32(self._buffer, self._writeOffset + 5, value.Y)
	self._writeOffset += 9
	return true
end

function Buffer:AddCFrame(value: CFrame): boolean
	if self._destroyed then return false end
	if self._writeOffset + 19 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 19) then return false end
	end
	local rx, ry, rz = value:ToEulerAnglesXYZ()
	buffer_writeu8(self._buffer, self._writeOffset, CFRAME)
	buffer_writeu16(self._buffer, self._writeOffset + 1, rx * CFRAME_SCALE + 0.5)
	buffer_writeu16(self._buffer, self._writeOffset + 3, ry * CFRAME_SCALE + 0.5)
	buffer_writeu16(self._buffer, self._writeOffset + 5, rz * CFRAME_SCALE + 0.5)
	buffer_writef32(self._buffer, self._writeOffset + 7, value.X)
	buffer_writef32(self._buffer, self._writeOffset + 11, value.Y)
	buffer_writef32(self._buffer, self._writeOffset + 15, value.Z)
	self._writeOffset += 19
	return true
end

function Buffer:AddColor3(value: Color3): boolean
	if self._destroyed then return false end
	if self._writeOffset + 4 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 4) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, COLOR3)
	buffer_writeu8(self._buffer, self._writeOffset + 1, value.R * FLOAT_TO_BYTE_SCALE + 0.5)
	buffer_writeu8(self._buffer, self._writeOffset + 2, value.G * FLOAT_TO_BYTE_SCALE + 0.5)
	buffer_writeu8(self._buffer, self._writeOffset + 3, value.B * FLOAT_TO_BYTE_SCALE + 0.5)
	self._writeOffset += 4
	return true
end

function Buffer:AddUDim(value: UDim): boolean
	if self._destroyed then return false end
	if self._writeOffset + 5 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 5) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, UDIM)
	buffer_writei16(self._buffer, self._writeOffset + 1, value.Scale * UDIM_SCALE)
	buffer_writei16(self._buffer, self._writeOffset + 3, value.Offset)
	self._writeOffset += 5
	return true
end

function Buffer:AddUDim2(value: UDim2): boolean
	if self._destroyed then return false end
	if self._writeOffset + 9 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 9) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, UDIM2)
	buffer_writei16(self._buffer, self._writeOffset + 1, value.X.Scale * UDIM_SCALE)
	buffer_writei16(self._buffer, self._writeOffset + 3, value.X.Offset)
	buffer_writei16(self._buffer, self._writeOffset + 5, value.Y.Scale * UDIM_SCALE)
	buffer_writei16(self._buffer, self._writeOffset + 7, value.Y.Offset)
	self._writeOffset += 9
	return true
end

function Buffer:AddRect(value: Rect): boolean
	if self._destroyed then return false end
	if self._writeOffset + 17 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 17) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, RECT)
	buffer_writef32(self._buffer, self._writeOffset + 1, value.Min.X)
	buffer_writef32(self._buffer, self._writeOffset + 5, value.Min.Y)
	buffer_writef32(self._buffer, self._writeOffset + 9, value.Max.X)
	buffer_writef32(self._buffer, self._writeOffset + 13, value.Max.Y)
	self._writeOffset += 17
	return true
end

function Buffer:AddNumberRange(value: NumberRange): boolean
	if self._destroyed then return false end
	if self._writeOffset + 9 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 9) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, NUMBER_RANGE)
	buffer_writef32(self._buffer, self._writeOffset + 1, value.Min)
	buffer_writef32(self._buffer, self._writeOffset + 5, value.Max)
	self._writeOffset += 9
	return true
end

function Buffer:AddNumberSequence(value: NumberSequence): boolean
	if self._destroyed then return false end
	local len = #value.Keypoints
	local requiredBytes = 2 + len * 3
	if self._writeOffset + requiredBytes > buffer_len(self._buffer) then
		if not EnsureCapacity(self, requiredBytes) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, NUMBER_SEQUENCE)
	buffer_writeu8(self._buffer, self._writeOffset + 1, len)
	local offset = self._writeOffset + 2
	for _, keypoint in ipairs(value.Keypoints) do
		buffer_writeu8(self._buffer, offset, keypoint.Time * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(self._buffer, offset + 1, keypoint.Value * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(self._buffer, offset + 2, keypoint.Envelope * FLOAT_TO_BYTE_SCALE + 0.5)
		offset += 3
	end
	self._writeOffset += requiredBytes
	return true
end

function Buffer:AddColorSequence(value: ColorSequence): boolean
	if self._destroyed then return false end
	local len = #value.Keypoints
	local requiredBytes = 2 + len * 4
	if self._writeOffset + requiredBytes > buffer_len(self._buffer) then
		if not EnsureCapacity(self, requiredBytes) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, COLOR_SEQUENCE)
	buffer_writeu8(self._buffer, self._writeOffset + 1, len)
	local offset = self._writeOffset + 2
	for _, keypoint in ipairs(value.Keypoints) do
		buffer_writeu8(self._buffer, offset, keypoint.Time * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(self._buffer, offset + 1, keypoint.Value.R * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(self._buffer, offset + 2, keypoint.Value.G * FLOAT_TO_BYTE_SCALE + 0.5)
		buffer_writeu8(self._buffer, offset + 3, keypoint.Value.B * FLOAT_TO_BYTE_SCALE + 0.5)
		offset += 4
	end
	self._writeOffset += requiredBytes
	return true
end

function Buffer:AddBrickColor(value: BrickColor): boolean
	if self._destroyed then return false end
	if self._writeOffset + 3 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 3) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, BRICK_COLOR)
	buffer_writeu16(self._buffer, self._writeOffset + 1, value.Number)
	self._writeOffset += 3
	return true
end

function Buffer:AddInstance(value: Instance): boolean
	if self._destroyed then return false end
	if self._writeOffset + 1 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 1) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, INSTANCE)
	self._writeOffset += 1
	self._instancesOffset += 1
	self._instances[self._instancesOffset] = value
	return true
end

function Buffer:AddTable(value: {[any]: any}): boolean
	if self._destroyed then return false end
	if self._writeOffset + 1 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 1) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, TABLE)
	self._writeOffset += 1

	for key, val in pairs(value) do
		local keyType = typeof(key)
		if keyType == "number" then
			if not self:AddNumber(key) then return false end
		elseif keyType == "string" then
			if not self:AddString(key) then return false end
		elseif keyType == "boolean" then
			if not self:AddBoolean(key) then return false end
		elseif keyType == "Instance" then
			if not self:AddInstance(key) then return false end
		else
			if not self:AddString(tostring(key)) then return false end
		end

		local valType = typeof(val)
		if valType == "number" then
			if not self:AddNumber(val) then return false end
		elseif valType == "string" then
			if not self:AddString(val) then return false end
		elseif valType == "boolean" then
			if not self:AddBoolean(val) then return false end
		elseif valType == "Instance" then
			if not self:AddInstance(val) then return false end
		elseif valType == "Vector3" then
			if not self:AddVector3(val) then return false end
		elseif valType == "Vector2" then
			if not self:AddVector2(val) then return false end
		elseif valType == "Color3" then
			if not self:AddColor3(val) then return false end
		elseif valType == "CFrame" then
			if not self:AddCFrame(val) then return false end
		elseif valType == "UDim" then
			if not self:AddUDim(val) then return false end
		elseif valType == "UDim2" then
			if not self:AddUDim2(val) then return false end
		elseif valType == "Rect" then
			if not self:AddRect(val) then return false end
		elseif valType == "NumberRange" then
			if not self:AddNumberRange(val) then return false end
		elseif valType == "NumberSequence" then
			if not self:AddNumberSequence(val) then return false end
		elseif valType == "ColorSequence" then
			if not self:AddColorSequence(val) then return false end
		elseif valType == "BrickColor" then
			if not self:AddBrickColor(val) then return false end
		elseif valType == "table" then
			if not self:AddTable(val) then return false end
		else
			if not self:AddString(tostring(val)) then return false end
		end
	end

	if self._writeOffset + 1 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 1) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, NIL)
	self._writeOffset += 1
	return true
end

function Buffer:AddNil(): boolean
	if self._destroyed then return false end
	if self._writeOffset + 1 > buffer_len(self._buffer) then
		if not EnsureCapacity(self, 1) then return false end
	end
	buffer_writeu8(self._buffer, self._writeOffset, NIL)
	self._writeOffset += 1
	return true
end

function Buffer:Flush(): boolean
	if self._writeOffset == 0 or self._destroyed then return false end
	local actualDataSize = math_min(self._writeOffset, buffer_len(self._buffer))
	if actualDataSize == 0 then return false end
	local filled = buffer_create(actualDataSize)
	buffer_copy(filled, 0, self._buffer, 0, actualDataSize)
	if self._callback then self._callback(filled) end
	self:Clear()
	return true
end

function Buffer:Clear()
	if self._destroyed then return end
	self._writeOffset = 0
	self._instancesOffset = 0
	table_clear(self._instances)
	local currentSize = buffer_len(self._buffer)
	if currentSize > MEGABYTE and currentSize > self._maxSize * 4 then
		self._buffer = buffer_create(self._maxSize)
	end
end

function Buffer:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self._flushTask then
		task_cancel(self._flushTask)
		self._flushTask = nil
	end
	self._buffer = nil
	self._writeOffset = 0
	self._instancesOffset = 0
	table_clear(self._instances)
end

function Buffer.bytes(bytes: number) return bytes end
function Buffer.kilobytes(kilobytes: number) return kilobytes * 1024 end
function Buffer.megabytes(megabytes: number) return Buffer.kilobytes(megabytes * 1024) end

function Buffer.Read(buf: Buffer): ({any})
	local objects = {}
	local offset = 0
	local instancesOffset = 0
	local instancesArray = buf._instances

	local function ReadS8(): number local value = buffer_readi8(buf._buffer, offset) offset += 1 return value end
	local function ReadS16(): number local value = buffer_readi16(buf._buffer, offset) offset += 2 return value end
	local function ReadS32(): number local value = buffer_readi32(buf._buffer, offset) offset += 4 return value end
	local function ReadU8(): number local value = buffer_readu8(buf._buffer, offset) offset += 1 return value end
	local function ReadU16(): number local value = buffer_readu16(buf._buffer, offset) offset += 2 return value end
	local function ReadU32(): number local value = buffer_readu32(buf._buffer, offset) offset += 4 return value end
	local function ReadF32(): number local value = buffer_readf32(buf._buffer, offset) offset += 4 return value end
	local function ReadF64(): number local value = buffer_readf64(buf._buffer, offset) offset += 8 return value end
	local function ReadString(length: number): string local value = buffer_readstring(buf._buffer, offset, length) offset += length return value end
	local function ReadInstance(): Instance instancesOffset += 1 return instancesArray[instancesOffset] end

	local function ReadF16(): number
		local bitOffset = offset * 8
		offset += 2
		local mantissa = buffer_readbits(buf._buffer, bitOffset + 0, 10)
		local exponent = buffer_readbits(buf._buffer, bitOffset + 10, 5)
		local sign = buffer_readbits(buf._buffer, bitOffset + 15, 1)
		if exponent == 0 and mantissa == 0 then return 0 end
		if exponent == 31 then return 0/0 end
		local value = (mantissa / 1024 + 1) * 2 ^ (exponent - 15)
		return sign == 0 and value or -value
	end

	local function ReadF24(): number
		local bitOffset = offset * 8
		offset += 3
		local mantissa = buffer_readbits(buf._buffer, bitOffset + 0, 17)
		local exponent = buffer_readbits(buf._buffer, bitOffset + 17, 6)
		local sign = buffer_readbits(buf._buffer, bitOffset + 23, 1)
		if exponent == 0 and mantissa == 0 then return 0 end
		if exponent == 63 then return 0/0 end
		local value = (mantissa / 131072 + 1) * 2 ^ (exponent - 31)
		return sign == 0 and value or -value
	end

	local DATA_READERS = {
		[NIL] = function() return nil end,
		[BOOLEAN] = function() return ReadU8() == 1 end,
		[NUMBER_I8] = ReadS8,
		[NUMBER_I16] = ReadS16,
		[NUMBER_I32] = ReadS32,
		[NUMBER_U8] = ReadU8,
		[NUMBER_U16] = ReadU16,
		[NUMBER_U32] = ReadU32,
		[NUMBER_F16] = ReadF16,
		[NUMBER_F24] = ReadF24,
		[NUMBER_F32] = ReadF32,
		[NUMBER_F64] = ReadF64,
		[STRING] = function() return ReadString(ReadU8()) end,
		[STRING_LONG] = function() return ReadString(ReadU16()) end,
		[INSTANCE] = ReadInstance,
		[VECTOR2] = function() return Vector2.new(ReadF32(), ReadF32()) end,
		[VECTOR3] = function() return Vector3.new(ReadF32(), ReadF32(), ReadF32()) end,
		[COLOR3] = function() return Color3.fromRGB(ReadU8(), ReadU8(), ReadU8()) end,
		[UDIM] = function() return UDim.new(ReadS16() * UDIM_INV_SCALE, ReadS16()) end,
		[UDIM2] = function() return UDim2.new(ReadS16() * UDIM_INV_SCALE, ReadS16(), ReadS16() * UDIM_INV_SCALE, ReadS16()) end,
		[CFRAME] = function()
			local rx = ReadU16() * CFRAME_INV_SCALE
			local ry = ReadU16() * CFRAME_INV_SCALE
			local rz = ReadU16() * CFRAME_INV_SCALE
			return CFrame.fromEulerAnglesXYZ(rx, ry, rz) + Vector3.new(ReadF32(), ReadF32(), ReadF32())
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
				local keyReader = DATA_READERS[keyType]
				if not keyReader then break end
				local key = keyReader()
				local valueType = ReadU8()
				local valueReader = DATA_READERS[valueType]
				if not valueReader then break end
				local value = valueReader()
				tbl[key] = value
			end
			return tbl
		end,
	}

	local function ReadData(): any
		local dataType = ReadU8()
		local reader = DATA_READERS[dataType]
		return reader and reader() or nil
	end

	while offset < buf._writeOffset do
		local object = ReadData()
		if object == nil then break end
		table_insert(objects, object)
	end

	return objects
end

function Buffer.create(options: {
	size: number?, 
	callback: (buf: buffer) -> ()
	}): Buffer
	local size = options and options.size or 32
	local maxSize = Buffer.megabytes(32)
	local callback = options and options.callback or function() end

	local bufferObj = buffer_create(size)

	local self = setmetatable({
		_buffer = bufferObj,
		_callback = callback,
		_maxSize = maxSize,
		_flushTask = nil,
		_destroyed = false,
		_writeOffset = 0, 
		_instances = {},
		_instancesOffset = 0,
	}, Buffer)

	return self
end

return setmetatable(Buffer, {
	__call = function(_, options)
		return Buffer.create(options)
	end,
})