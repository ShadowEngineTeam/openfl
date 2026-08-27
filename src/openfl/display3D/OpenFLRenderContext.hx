package openfl.display3D;

#if (!lime_doc_gen || lime_opengl || lime_opengles)
import lime.graphics.opengl.*;
import lime.graphics.OpenGLRenderContext;
import lime.utils.ArrayBuffer;
import lime.utils.ArrayBufferView;
import lime.utils.BytePointer;
import lime.utils.DataPointer;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import lime.utils.UInt32Array;
import lime.graphics.OpenGLES3RenderContext;

/**
	The `OpenFLRenderContext` is the render context OpenFL draws through, and is what
	`OpenGLRenderer.gl` holds. It wraps the `lime.graphics.OpenGLRenderContext` of the
	`Window`, which on this target is desktop OpenGL or OpenGL ES 3.

	It forwards that underlying context, so every entry point the Lime backend exposes is
	reachable here. It declares members of its own only where the signature needs to differ:
	the calls that take an `ArrayBufferView` (`bufferData`, `texImage2D`, `readPixels`, the
	`uniform*v` and `uniformMatrix*fv` families, and friends) translate the view into the
	pointer-and-length pair the native context expects, and three carry an alternate
	spelling of a native name (`clearDepth`, `depthRange`, `getVertexAttribOffset`).

	Previously every member was re-declared here by hand, which left the list drifting
	behind the backend; forwarding keeps the two in step.

	You can convert from `lime.graphics.RenderContext`, `lime.graphics.OpenGLRenderContext`,
	`lime.graphics.OpenGLES3RenderContext` or `lime.graphics.opengl.GL`:

	```haxe
	var gl:OpenFLRenderContext = window.context;
	var gl:OpenFLRenderContext = gl;
	var gl:OpenFLRenderContext = gles3;
	var gl:OpenFLRenderContext = GL;
	```
**/
#if !doc_gen
@:forward()
@:transitive abstract OpenFLRenderContext(OpenGLRenderContext) from OpenGLRenderContext to OpenGLRenderContext
{
#else
@:forward()
abstract OpenFLRenderContext(Dynamic) from Dynamic to Dynamic
{
#end
	private static var __tempPointer = new BytePointer();

	public function bufferData(target:Int, srcData:ArrayBufferView, usage:Int, srcOffset:Int = 0, length:Int = 0):Void
	{
		var size = (srcData != null) ? srcData.byteLength : 0;
		__tempPointer.set(srcData, srcOffset);
		this.bufferData(target, size, __tempPointer, usage);
	}

	public inline function bufferSubData(target:Int, offset:Int, srcData:ArrayBufferView, srcOffset:Int = 0, ?length:Int):Void
	{
		var size = (length != null) ? length : (srcData != null) ? srcData.byteLength : 0;
		__tempPointer.set(srcData, srcOffset);
		this.bufferSubData(target, offset, size, __tempPointer);
	}

	public function clearBufferfv(buffer:Int, drawbuffer:Int, values:ArrayBufferView, srcOffset:Int = 0):Void
	{
		__tempPointer.set(values, srcOffset);
		this.clearBufferfv(buffer, drawbuffer, __tempPointer);
	}

	public function clearBufferiv(buffer:Int, drawbuffer:Int, values:ArrayBufferView, ?srcOffset:Int):Void
	{
		__tempPointer.set(values, srcOffset);
		this.clearBufferiv(buffer, drawbuffer, __tempPointer);
	}

	public function clearBufferuiv(buffer:Int, drawbuffer:Int, values:ArrayBufferView, ?srcOffset:Int):Void
	{
		__tempPointer.set(values, srcOffset);
		this.clearBufferuiv(buffer, drawbuffer, __tempPointer);
	}

	public inline function clearDepth(depth:Float):Void
	{
		this.clearDepthf(depth);
	}

	public function compressedTexImage2D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, border:Int, srcData:ArrayBufferView,
		srcOffset:Int = 0,
		?srcLengthOverride:Int):Void
	{
		var imageSize = (srcLengthOverride != null) ? srcLengthOverride : (srcData != null) ? srcData.byteLength : 0;
		__tempPointer.set(srcData, srcOffset);
		this.compressedTexImage2D(target, level, internalformat, width, height, border, imageSize, __tempPointer);
	}

	public function compressedTexImage3D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, depth:Int, border:Int, srcData:ArrayBufferView,
			srcOffset:Int = 0, ?srcLengthOverride:Int):Void
	{
		var imageSize = (srcLengthOverride != null) ? srcLengthOverride : (srcData != null) ? srcData.byteLength : 0;
		__tempPointer.set(srcData, srcOffset);
		this.compressedTexImage3D(target, level, internalformat, width, height, depth, border, imageSize, __tempPointer);
	}

	public inline function compressedTexSubImage2D(target:Int, level:Int, xoffset:Int, yoffset:Int, width:Int, height:Int, format:Int, srcData:ArrayBufferView,
		srcOffset:Int = 0, ?srcLengthOverride:Int):Void
	{
		var imageSize = (srcLengthOverride != null) ? srcLengthOverride : (srcData != null) ? srcData.byteLength : 0;
		__tempPointer.set(srcData, srcOffset);
		this.compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, __tempPointer);
	}

	public inline function compressedTexSubImage3D(target:Int, level:Int, xoffset:Int, yoffset:Int, zoffset:Int, width:Int, height:Int, depth:Int, format:Int,
			srcData:ArrayBufferView, srcOffset:Int = 0, ?srcLengthOverride:Int):Void
	{
		var imageSize = (srcLengthOverride != null) ? srcLengthOverride : (srcData != null) ? srcData.byteLength : 0;
		__tempPointer.set(srcData, srcOffset);
		this.compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, __tempPointer);
	}

	public inline function depthRange(zNear:Float, zFar:Float):Void
	{
		this.depthRangef(zNear, zFar);
	}

	public inline function getBufferSubData(target:Int, srcByteOffset:DataPointer, dstData:ArrayBuffer, srcOffset:Int = 0, ?length:Int):Void
	{
		#if !js
		var size = (length != null) ? length : (dstData != null) ? dstData.length : 0;
		this.getBufferSubData(target, srcByteOffset + srcOffset, size, dstData);
		#end
	}

	public inline function getVertexAttribOffset(index:Int, pname:Int):DataPointer
	{
		return this.getVertexAttribPointerv(index, pname);
	}

	public inline function readPixels(x:Int, y:Int, width:Int, height:Int, format:Int, type:Int, pixels:ArrayBufferView, dstOffset:Int = 0):Void
	{
		__tempPointer.set(pixels, dstOffset);
		this.readPixels(x, y, width, height, format, type, __tempPointer);
	}

	public inline function texImage2D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, border:Int, format:Int, type:Int,
		srcData:ArrayBufferView,
		srcOffset:Int = 0):Void
	{
		__tempPointer.set(srcData, srcOffset);
		this.texImage2D(target, level, internalformat, width, height, border, format, type, __tempPointer);
	}

	public inline function texImage3D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, depth:Int, border:Int, format:Int, type:Int,
			srcData:ArrayBufferView, srcOffset:Int = 0):Void
	{
		__tempPointer.set(srcData, srcOffset);
		this.texImage3D(target, level, internalformat, width, height, depth, border, format, type, __tempPointer);
	}

	public inline function texSubImage2D(target:Int, level:Int, xoffset:Int, yoffset:Int, width:Int, height:Int, format:Int, type:Int, srcData:ArrayBufferView,
		srcOffset:Int = 0):Void
	{
		__tempPointer.set(srcData, srcOffset);
		this.texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, __tempPointer);
	}

	public inline function texSubImage3D(target:Int, level:Int, xoffset:Int, yoffset:Int, zoffset:Int, width:Int, height:Int, depth:Int, format:Int, type:Int,
			srcData:ArrayBufferView, srcOffset:Int = 0):Void
	{
		__tempPointer.set(srcData, srcOffset);
		this.texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, __tempPointer);
	}

	public inline function uniform1fv(location:GLUniformLocation, v:Float32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform1fv(location, v != null ? v.length : 0, v);
	}

	public inline function uniform1iv(location:GLUniformLocation, v:Int32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform1iv(location, v != null ? v.length : 0, v);
	}

	public inline function uniform1uiv(location:GLUniformLocation, v:UInt32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform1uiv(location, v != null ? v.length : 0, v);
	}

	public inline function uniform2fv(location:GLUniformLocation, v:Float32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform2fv(location, v != null ? v.length >> 1 : 0, v);
	}

	public inline function uniform2iv(location:GLUniformLocation, v:Int32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform2iv(location, v != null ? v.length >> 1 : 0, v);
	}

	public inline function uniform2uiv(location:GLUniformLocation, v:UInt32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform2uiv(location, v != null ? v.length >> 1 : 0, v);
	}

	public inline function uniform3fv(location:GLUniformLocation, v:Float32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform3fv(location, v != null ? Std.int(v.length / 3) : 0, v);
	}

	public inline function uniform3iv(location:GLUniformLocation, v:Int32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform3iv(location, v != null ? Std.int(v.length / 3) : 0, v);
	}

	public inline function uniform3uiv(location:GLUniformLocation, v:UInt32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform3uiv(location, v != null ? Std.int(v.length / 3) : 0, v);
	}

	public inline function uniform4fv(location:GLUniformLocation, v:Float32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform4fv(location, v != null ? v.length >> 2 : 0, v);
	}

	public inline function uniform4iv(location:GLUniformLocation, v:Int32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform4iv(location, v != null ? v.length >> 2 : 0, v);
	}

	public inline function uniform4uiv(location:GLUniformLocation, v:UInt32Array, ?srcOffset:Int, ?srcLength:Int):Void
	{
		this.uniform4uiv(location, v != null ? v.length >> 2 : 0, v);
	}

	public function uniformMatrix2fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = v.length >> 2;
		__tempPointer.set(v, srcOffset);
		this.uniformMatrix2fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix2x3fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 6);

		__tempPointer.set(v, srcOffset);

		this.uniformMatrix2x3fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix2x4fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 8);

		__tempPointer.set(v, srcOffset);

		this.uniformMatrix2x4fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix3fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 9);
		__tempPointer.set(v, srcOffset);
		this.uniformMatrix3fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix3x2fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 6);

		__tempPointer.set(v, srcOffset);

		this.uniformMatrix3x2fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix3x4fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 12);

		__tempPointer.set(v, srcOffset);

		this.uniformMatrix3x4fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix4fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = v.length >> 4;
		__tempPointer.set(v, srcOffset);
		this.uniformMatrix4fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix4x2fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 8);

		__tempPointer.set(v, srcOffset);

		this.uniformMatrix4x2fv(location, count, transpose, __tempPointer);
	}

	public function uniformMatrix4x3fv(location:GLUniformLocation, transpose:Bool, v:Float32Array, srcOffset:Int = 0, ?srcLength:Int):Void
	{
		var count = 0;
		if (srcLength != null) count = srcLength;
		else if (v != null) count = Std.int(v.length / 12);

		__tempPointer.set(v, srcOffset);

		this.uniformMatrix4x3fv(location, count, transpose, __tempPointer);
	}

	#if (!doc_gen && (lime_opengl || lime_opengles))
	@:from private static function fromOpenGLES3RenderContext(gl:OpenGLES3RenderContext):OpenFLRenderContext
	{
		return cast gl;
	}
	#end

	@:from private static function fromGL(gl:Class<GL>):OpenFLRenderContext
	{
		return cast GL.context;
	}
}
#end
