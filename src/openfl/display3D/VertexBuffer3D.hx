package openfl.display3D;

import openfl.display3D._internal.GLBuffer;
import openfl.utils._internal.ArrayBufferView;
import openfl.utils._internal.Float32Array;
import openfl.utils.ByteArray;
import openfl.Vector;
#if (lime && !js)
import lime.graphics.bgfx.BGFX;
import lime.graphics.bgfx.BGFXVertexLayout;
#end

/**
	The VertexBuffer3D class represents a set of vertex data uploaded to a rendering context.

	Use a VertexBuffer3D object to define the data associated with each point in a set
	of vertexes. You can upload the vertex data either from a Vector array or a ByteArray.
	(Once uploaded, the data in the original array is no longer referenced; changing or
	discarding the source array does not change the vertex data.)

	The data associated with each vertex is in an application-defined format and is used
	as the input for the vertex shader program. Identify which values belong to which
	vertex program input using the Context3D `setVertexBufferAt()` function. A vertex
	program can use up to eight inputs (also known as vertex attribute registers). Each
	input can require between one and four 32-bit values. For example, the [x,y,z]
	position coordinates of a vertex can be passed to a vertex program as a vector
	containing three 32 bit values. The Context3DVertexBufferFormat class defines
	constants for the supported formats for shader inputs. You can supply up to
	sixty-four 32-bit values (256 bytes) of data for each point (but a single vertex
	shader cannot use all of the data in this case).

	The `setVertexBufferAt()` function also identifies which vertex buffer to use for
	rendering any subsequent `drawTriangles()` calls. To render data from a different
	vertex buffer, call setVertexBufferAt() again with the appropriate arguments. (You
	can store data for the same point in multiple vertex buffers, say position data in
	one buffer and texture coordinates in another, but typically rendering is more
	efficient if all the data for a point comes from a single buffer.)

	The Index3DBuffer object passed to the Context3D `drawTriangles()` method organizes
	the vertex data into triangles. Each value in the index buffer is the index to a
	vertex in the vertex buffer. A set of three indexes, in sequence, defines a triangle.

	You cannot create a VertexBuffer3D object directly. Use the Context3D
	`createVertexBuffer()` method instead.

	To free the render context resources associated with a vertex buffer, call the object's
	`dispose()` method.
**/
@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)
class VertexBuffer3D
{
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __id:GLBuffer;
	@:noCompletion private var __memoryUsage:Int = -1;
	@:noCompletion private var __numVertices:Int;
	@:noCompletion private var __stride:Int;
	@:noCompletion private var __tempFloat32Array:Float32Array;
	@:noCompletion private var __usage:Int;
	@:noCompletion private var __vertexSize:Int;

	#if (lime && !js)
	// generic creation layouts keyed by data32PerVertex: only the stride
	// matters at creation — draws override with the real attribute layout
	// via setVertexBufferWithLayout
	@:noCompletion private static var __bgfxGenericLayouts:Map<Int, BGFXVertexLayout> = new Map();
	@:noCompletion private var __bgfxBuffer:Int = -1;
	@:noCompletion private var __bgfxData:Float32Array;
	@:noCompletion private var __bgfxDataLength:Int = 0;
	#end

	@:noCompletion private function new(context3D:Context3D, numVertices:Int, dataPerVertex:Int, bufferUsage:String)
	{
		__context = context3D;
		__numVertices = numVertices;
		__vertexSize = dataPerVertex;
		__stride = __vertexSize * 4;

		#if (lime && !js)
		// no GPU-side buffer: draws feed transient buffers from the CPU copy
		// (creating one here would leak — OpenFL recreates VertexBuffer3D on
		// every growth without disposing the old one)
		#else
		var gl = __context.gl;

		__id = gl.createBuffer();
		__usage = (bufferUsage == Context3DBufferUsage.DYNAMIC_DRAW) ? gl.DYNAMIC_DRAW : gl.STATIC_DRAW;
		#end
	}

	#if (lime && !js)
	@:noCompletion private static function __bgfxGenericLayout(dataPerVertex:Int):BGFXVertexLayout
	{
		var layout = __bgfxGenericLayouts.get(dataPerVertex);

		if (layout == null)
		{
			var components = dataPerVertex > 4 ? 4 : dataPerVertex;

			layout = new BGFXVertexLayout();
			layout.begin().add(TEXCOORD7, components, FLOAT);
			if (dataPerVertex > components) layout.skip((dataPerVertex - components) * 4);
			layout.end();

			__bgfxGenericLayouts.set(dataPerVertex, layout);
		}

		return layout;
	}
	#end

	/**
		Frees all resources associated with this object. After disposing a vertex
		buffer, calling `upload()` and rendering using this object will fail.
	**/
	public function dispose():Void
	{
		#if (lime && !js)
		if (__bgfxBuffer != -1)
		{
			BGFX.destroyDynamicVertexBuffer(__bgfxBuffer);
			__bgfxBuffer = -1;
		}
		#else
		var gl = __context.gl;
		gl.deleteBuffer(__id);
		#end
	}

	/**
		Uploads the data for a set of points to the rendering context from a byte array.

		@param	data	a byte array containing the vertex data. Each data value is four
		bytes long. The number of values in a vertex is specified at buffer creation
		using the data32PerVertex parameter to the Context3D `createVertexBuffer3D()`
		method. The length of the data in bytes must be `byteArrayOffset` plus four times
		the number of values per vertex times the number of vertices. The ByteArray object
		must use the little endian format.
		@param	byteArrayOffset	number of bytes to skip from the beginning of data
		@param	startVertex	The index of the first vertex to be loaded. A value for
		startVertex not equal to zero may be used to load a sub-region of the vertex data.
		@param	numVertices	The number of vertices to be loaded from data.
		@throws	TypeError	Null Pointer Error: when data is `null`.
		@throws	RangeError	Bad Input Size: if `byteArrayOffset` is less than 0, or if
		`byteArrayOffset` is greater than or equal to the length of data, or if no. of
		elements in data - `byteArrayOffset` is less than `numVertices*data32pervertex*4`
		given in Context3D `createVertexBuffer()`.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function uploadFromByteArray(data:ByteArray, byteArrayOffset:Int, startVertex:Int, numVertices:Int):Void
	{
		#if lime
		var offset = byteArrayOffset + startVertex * __stride;
		var length = numVertices * __vertexSize;

		uploadFromTypedArray(new Float32Array(data, offset, length));
		#end
	}

	/**
		Uploads the data for a set of points to the rendering context from a typed array.

		@param	data	a typed array of 32-bit values. A single vertex is comprised of a
		number of values stored sequentially in the vector. The number of values in a
		vertex is specified at buffer creation using the `data32PerVertex` parameter to the
		Context3D `createVertexBuffer3D()` method.
		@param	byteLength	The number of bytes to read.
	**/
	public function uploadFromTypedArray(data:ArrayBufferView, byteLength:Int = -1):Void
	{
		if (data == null) return;

		#if (lime && !js)
		// keep a CPU copy: bgfx defers dynamic buffer updates to frame
		// execution, so re-uploading between draws inside one frame would
		// make every draw see the last upload. Draws feed a transient
		// buffer from this copy instead (GL-style immediate semantics).
		var floats:Float32Array = cast data;
		var length = Std.int(data.byteLength / 4);

		if (__bgfxData == null || __bgfxData.length < length)
		{
			__bgfxData = new Float32Array(length);
		}

		for (i in 0...length)
		{
			__bgfxData[i] = floats[i];
		}

		__bgfxDataLength = length;
		__memoryUsage = data.byteLength;
		#else
		var gl = __context.gl;

		__context.__bindGLArrayBuffer(__id);
		if (__memoryUsage == data.byteLength) gl.bufferSubData(gl.ARRAY_BUFFER, 0, data);
		else
			gl.bufferData(gl.ARRAY_BUFFER, data, __usage);
		__memoryUsage = data.byteLength;
		#end
	}

	/**
		Uploads the data for a set of points to the rendering context from a vector array.

		@param	data	a vector of 32-bit values. A single vertex is comprised of a
		number of values stored sequentially in the vector. The number of values in a
		vertex is specified at buffer creation using the data32PerVertex parameter to the
		Context3D `createVertexBuffer3D()` method. The length of the vector must be the
		number of values per vertex times the number of vertexes.
		@param	startVertex	The index of the first vertex to be loaded. A value for
		`startVertex` not equal to zero may be used to load a sub-region of the vertex data.
		@param	numVertices	The number of vertices represented by data.
		@throws	TypeError	Null Pointer Error: when `data` is `null`.
		@throws	RangeError	Bad Input Size: when number of elements in data is less than
		`numVertices * data32PerVertex` given in Context3D `createVertexBuffer()`, or
		when `startVertex + numVertices` is greater than `numVertices` given in Context3D
		`createVertexBuffer()`.
	**/
	public function uploadFromVector(data:Vector<Float>, startVertex:Int, numVertices:Int):Void
	{
		#if lime
		if (data == null) return;
		var gl = __context.gl;

		// TODO: Optimize more

		var start = startVertex * __vertexSize;
		var count = numVertices * __vertexSize;
		var length = start + count;

		var existingFloat32Array = __tempFloat32Array;

		if (__tempFloat32Array == null || __tempFloat32Array.length < count)
		{
			__tempFloat32Array = new Float32Array(count);

			if (existingFloat32Array != null)
			{
				__tempFloat32Array.set(existingFloat32Array);
			}
		}

		for (i in start...length)
		{
			__tempFloat32Array[i - start] = data[i];
		}

		uploadFromTypedArray(__tempFloat32Array);
		#end
	}

	/**
		Uploads the data for a set of points to the rendering context from an array.

		@param	data	an array of 32-bit values. A single vertex is comprised of a
		number of values stored sequentially in the array. The number of values in a
		vertex is specified at buffer creation using the data32PerVertex parameter to the
		Context3D `createVertexBuffer3D()` method. The length of the array must be the
		number of values per vertex times the number of vertexes.
		@param	startVertex	The index of the first vertex to be loaded. A value for
		`startVertex` not equal to zero may be used to load a sub-region of the vertex data.
		@param	numVertices	The number of vertices represented by data.
		@throws	TypeError	Null Pointer Error: when `data` is `null`.
		@throws	RangeError	Bad Input Size: when number of elements in data is less than
		`numVertices * data32PerVertex` given in Context3D `createVertexBuffer()`, or
		when `startVertex + numVertices` is greater than `numVertices` given in Context3D
		`createVertexBuffer()`.
	**/
	public function uploadFromArray(data:Array<Float>, startVertex:Int, numVertices:Int):Void
	{
		#if lime
		if (data == null) return;
		var gl = __context.gl;

		// TODO: Optimize more

		var start = startVertex * __vertexSize;
		var count = numVertices * __vertexSize;
		var length = start + count;

		var existingFloat32Array = __tempFloat32Array;

		if (__tempFloat32Array == null || __tempFloat32Array.length < count)
		{
			__tempFloat32Array = new Float32Array(count);

			if (existingFloat32Array != null)
			{
				__tempFloat32Array.set(existingFloat32Array);
			}
		}

		for (i in start...length)
		{
			__tempFloat32Array[i - start] = data[i];
		}

		uploadFromTypedArray(__tempFloat32Array);
		#end
	}
}
