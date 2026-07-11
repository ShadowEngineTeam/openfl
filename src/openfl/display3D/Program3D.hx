package openfl.display3D;

import openfl.display3D._internal.GLProgram;
import openfl.display3D._internal.GLShader;
import openfl.display3D._internal.GLUniformLocation;
import openfl.display3D._internal.AGALConverter;
import openfl.display._internal.SamplerState;
import openfl.utils._internal.Float32Array;
import openfl.utils._internal.Log;
import openfl.display.ShaderParameterType;
import openfl.errors.IllegalOperationError;
import openfl.utils.ByteArray;
import openfl.Vector;
#if lime
import lime.graphics.opengl.GL;
import lime.utils.BytePointer;
#end
#if (lime && !js)
import lime.graphics.bgfx.BGFX;
#end

/**
	The Program3D class represents a pair of rendering programs (also called "shaders")
	uploaded to the rendering context.

	Programs managed by a Program3D object control the entire rendering of triangles
	during a Context3D drawTriangles() call. Upload the binary bytecode to the rendering
	context using the upload method. (Once uploaded, the program in the original byte
	array is no longer referenced; changing or discarding the source byte array does
	not change the program.)

	Programs always consist of two linked parts: A vertex and a fragment program.

	1. The vertex program operates on data defined in VertexBuffer3D objects and is
	responsible for projecting vertices into clip space and passing any required vertex
	data, such as color, to the fragment shader.
	2. The fragment shader operates on the attributes passed to it by the vertex program
	and produces a color for every rasterized fragment of a triangle, resulting in pixel
	colors. Note that fragment programs have several names in 3D programming literature,
	including fragment shader and pixel shader.

	Designate which program pair to use for subsequent rendering operations by passing the
	corresponding Program3D instance to the Context3D `setProgram()` method.

	You cannot create a Program3D object directly; use the Context3D `createProgram()`
	method instead.
**/
@:access(openfl.display3D.Context3D)
@:access(openfl.display.ShaderInput)
@:access(openfl.display.ShaderParameter)
@:access(openfl.display.Stage)
@:final class Program3D
{
	@:noCompletion private var __agalAlphaSamplerEnabled:Array<Uniform>;
	@:noCompletion private var __agalAlphaSamplerUniforms:List<Uniform>;
	@:noCompletion private var __agalFragmentUniformMap:UniformMap;
	@:noCompletion private var __agalPositionScale:Uniform;
	@:noCompletion private var __agalSamplerUniforms:List<Uniform>;
	@:noCompletion private var __agalSamplerUsageMask:Int;
	@:noCompletion private var __agalUniforms:List<Uniform>;
	@:noCompletion private var __agalVertexUniformMap:UniformMap;
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __format:Context3DProgramFormat;
	@:noCompletion private var __glFragmentShader:GLShader;
	@:noCompletion private var __glFragmentSource:String;
	@:noCompletion private var __glProgram:GLProgram;
	@:noCompletion private var __glslAttribNames:Array<String>;
	@:noCompletion private var __glslAttribTypes:Array<ShaderParameterType>;
	@:noCompletion private var __glslSamplerNames:Array<String>;
	@:noCompletion private var __glslUniformLocations:Array<GLUniformLocation>;
	@:noCompletion private var __glslUniformNames:Array<String>;
	@:noCompletion private var __glslUniformTypes:Array<ShaderParameterType>;
	@:noCompletion private var __glVertexShader:GLShader;
	@:noCompletion private var __glVertexSource:String;
	// @:noCompletion private var __memUsage:Int;
	@:noCompletion private var __samplerStates:Array<SamplerState>;

	#if (lime && !js)
	// BGFX program state (native): handle + uniform staging flushed per submit
	@:noCompletion private var __bgfxProgram:Int = -1;
	@:noCompletion private var __bgfxTranslated:openfl.display3D._internal.BGFXGLSLTranslator.BGFXTranslatedProgram;
	@:noCompletion private var __bgfxVertexGLSL:String;
	@:noCompletion private var __bgfxFragmentGLSL:String;
	@:noCompletion private var __bgfxComplexPrograms:Map<Int, Int>;
	@:noCompletion private var __bgfxDstSampler:Int = -1;
	@:noCompletion private var __bgfxDstSamplerStage:Int = -1;
	@:noCompletion private var __bgfxUniformHandles:Array<Int>;
	@:noCompletion private var __bgfxUniformStaging:Array<openfl.utils._internal.Float32Array>;
	@:noCompletion private var __bgfxUniformDirty:Array<Bool>;
	@:noCompletion private var __bgfxUniformVec4Counts:Array<Int>; // vec4 regs (0 = mat3, -1 = mat4)
	@:noCompletion private var __bgfxSamplerHandles:Array<Int>;

	@:noCompletion private function __uploadBGFX(vertexGLSL:String, fragmentGLSL:String):Bool
	{
		#if openfl_bgfx_upload_guard
		try
		{
			return __uploadBGFXInner(vertexGLSL, fragmentGLSL);
		}
		catch (e:Dynamic)
		{
			try
			{
				var f = sys.io.File.append(Sys.getEnv("TEMP") + "/upload-guard.txt", false);
				f.writeString("EXCEPTION: " + Std.string(e) + "\n" + haxe.CallStack.toString(haxe.CallStack.exceptionStack()) + "\n---- vertex ----\n"
					+ vertexGLSL + "\n---- fragment ----\n" + fragmentGLSL + "\n");
				f.close();
			}
			catch (e2:Dynamic) {}
			return false;
		}
	}

	@:noCompletion private function __uploadBGFXInner(vertexGLSL:String, fragmentGLSL:String):Bool
	{
		#end
		__bgfxVertexGLSL = vertexGLSL;
		__bgfxFragmentGLSL = fragmentGLSL;

		var translated = openfl.display3D._internal.BGFXGLSLTranslator.translate(vertexGLSL, fragmentGLSL);
		__bgfxTranslated = translated;

		var vs = BGFX.compileShader(translated.vertexSC, "v", null, null, translated.varyingDef);
		if (vs == null)
		{
			Log.error("BGFX vertex shader failed:\n" + BGFX.getShaderCompileMessages() + "\n" + translated.vertexSC);
			return false;
		}

		var fs = BGFX.compileShader(translated.fragmentSC, "f", null, null, translated.varyingDef);
		if (fs == null)
		{
			Log.error("BGFX fragment shader failed:\n" + BGFX.getShaderCompileMessages() + "\n" + translated.fragmentSC);
			return false;
		}

		// ALL uniform handles (samplers especially) must exist BEFORE program
		// creation: bgfx attaches shader-reflected uniforms to existing handles
		// at createProgram time. A sampler uniform created afterwards doesn't
		// attach, and its stage assignment silently defaults to 0 — harmless
		// for single-sampler shaders, but multi-sampler shaders (filter
		// combine passes) alias every sampler onto stage 0. (Same failure
		// class as the complex-blend dst-sampler first-draw bug.)
		__bgfxUniformHandles = [];
		__bgfxUniformStaging = [];
		__bgfxUniformDirty = [];
		__bgfxUniformVec4Counts = [];
		__bgfxSamplerHandles = [];

		for (i in 0...translated.uniformNames.length)
		{
			var glslType = translated.uniformGLSLTypes[i];
			var arrayLength = translated.uniformArrayLengths[i];
			var name = translated.uniformNames[i];
			var handle:Int, floats:Int, vec4Count:Int;

			switch (glslType)
			{
				case "mat4":
					handle = BGFX.createUniform(name, MAT4, arrayLength > 0 ? arrayLength : 1);
					floats = 16 * (arrayLength > 0 ? arrayLength : 1);
					vec4Count = -1;
				case "mat3":
					handle = BGFX.createUniform(name, MAT3, arrayLength > 0 ? arrayLength : 1);
					floats = 9 * (arrayLength > 0 ? arrayLength : 1);
					vec4Count = 0;
				case "vec4":
					handle = BGFX.createUniform(name, VEC4, arrayLength > 0 ? arrayLength : 1);
					floats = 4 * (arrayLength > 0 ? arrayLength : 1);
					vec4Count = arrayLength > 0 ? arrayLength : 1;
				default:
					// packed scalar/small vector: the translator renamed the
					// uniform to name_ofl4 (vec4); arrays stay under their name
					var uniformName = arrayLength > 0 ? name : name + "_ofl4";
					handle = BGFX.createUniform(uniformName, VEC4, arrayLength > 0 ? arrayLength : 1);
					floats = 4 * (arrayLength > 0 ? arrayLength : 1);
					vec4Count = arrayLength > 0 ? arrayLength : 1;
			}

			__bgfxUniformHandles.push(handle);
			__bgfxUniformStaging.push(new openfl.utils._internal.Float32Array(floats));
			__bgfxUniformDirty.push(false);
			__bgfxUniformVec4Counts.push(vec4Count);
		}

		for (name in translated.samplerNames)
		{
			__bgfxSamplerHandles.push(BGFX.createUniform(name, SAMPLER, 1));
		}

		// pre-create the complex-blend snapshot sampler so the handle exists
		// before any program (base or variant) references the name
		__bgfxDstSampler = BGFX.createUniform("openfl_DstSampler", SAMPLER, 1);
		__bgfxDstSamplerStage = translated.samplerNames.length;

		__bgfxProgram = BGFX.createProgram(BGFX.createShader(vs), BGFX.createShader(fs), true);

		// expose reflection data the GLSL bookkeeping expects
		__glslAttribNames = translated.attribNames.copy();
		__glslSamplerNames = translated.samplerNames.copy();
		__glslUniformNames = translated.uniformNames.copy();

		return true;
	}

	/** index of a uniform name in the staging tables, or -1 (stripped/unknown) **/
	@:noCompletion private function __bgfxUniformIndex(name:String):Int
	{
		if (__bgfxTranslated == null) return -1;
		return __bgfxTranslated.uniformNames.indexOf(name);
	}

	/** index of a sampler name = its texture stage, or -1 **/
	@:noCompletion private function __bgfxSamplerIndex(name:String):Int
	{
		if (__bgfxTranslated == null) return -1;
		return __bgfxTranslated.samplerNames.indexOf(name);
	}

	/**
		Lazily compiled fragment-shader variant that evaluates a KHR advanced
		blend equation against the sampled render target. Returns the bgfx
		program handle, or -1 when compilation failed.
	**/
	@:noCompletion private function __bgfxGetComplexProgram(mode:Int):Int
	{
		if (__bgfxVertexGLSL == null) return -1;
		if (__bgfxComplexPrograms == null) __bgfxComplexPrograms = new Map();

		var cached = __bgfxComplexPrograms.get(mode);
		if (cached != null) return cached;

		var translated = openfl.display3D._internal.BGFXGLSLTranslator.translate(__bgfxVertexGLSL, __bgfxFragmentGLSL, mode);
		var program = -1;

		var vs = BGFX.compileShader(translated.vertexSC, "v", null, null, translated.varyingDef);
		var fs = vs != null ? BGFX.compileShader(translated.fragmentSC, "f", null, null, translated.varyingDef) : null;

		if (fs != null)
		{
			#if openfl_bgfx_debug_shaders
			sys.io.File.saveContent("complex-blend-ok-" + StringTools.hex(mode) + ".txt", translated.fragmentSC);
			#end
			program = BGFX.createProgram(BGFX.createShader(vs), BGFX.createShader(fs), true);
			__bgfxDstSamplerStage = translated.dstSamplerStage;

			if (__bgfxDstSampler == -1)
			{
				__bgfxDstSampler = BGFX.createUniform("openfl_DstSampler", SAMPLER, 1);
			}
		}
		else
		{
			Log.warn("BGFX complex blend shader variant failed:\n" + BGFX.getShaderCompileMessages());
			#if openfl_bgfx_debug_shaders
			sys.io.File.saveContent("complex-blend-fail-" + StringTools.hex(mode) + ".txt",
				BGFX.getShaderCompileMessages() + "\n---- vertex ----\n" + translated.vertexSC + "\n---- fragment ----\n" + translated.fragmentSC);
			#end
		}

		__bgfxComplexPrograms.set(mode, program);
		return program;
	}

	/** submit-time flush of dirty staged uniforms **/
	@:noCompletion private function __bgfxFlushUniforms():Void
	{
		

		for (i in 0...__bgfxUniformHandles.length)
		{
			if (__bgfxUniformDirty[i])
			{
				var count = __bgfxUniformVec4Counts[i];
				BGFX.setUniform(__bgfxUniformHandles[i], __bgfxUniformStaging[i], count > 0 ? count : 1);
				// bgfx encoder state resets after submit; keep dirty so the
				// next draw with this program re-applies the values
			}
		}
	}

	@:noCompletion private function __bgfxSetUniformFloats(index:Int, values:Array<Float>, count:Int):Void
	{
		if (index < 0 || __bgfxUniformStaging == null || index >= __bgfxUniformStaging.length) return;

		var staging = __bgfxUniformStaging[index];
		if (count > staging.length) count = staging.length;

		for (i in 0...count)
		{
			staging[i] = (values != null && i < values.length) ? values[i] : 0;
		}

		__bgfxUniformDirty[index] = true;
	}

	@:noCompletion private function __bgfxSetUniformFromBuffer(index:Int, buffer:openfl.utils._internal.Float32Array, position:Int, count:Int):Void
	{
		if (index < 0 || __bgfxUniformStaging == null || index >= __bgfxUniformStaging.length) return;

		var staging = __bgfxUniformStaging[index];
		if (count > staging.length) count = staging.length;

		for (i in 0...count)
		{
			staging[i] = buffer[position + i];
		}

		__bgfxUniformDirty[index] = true;
	}

	@:noCompletion private function __bgfxSetUniformMatrix(index:Int, rawData:Vector<Float>, transposed:Bool):Void
	{
		if (index < 0 || __bgfxUniformStaging == null || index >= __bgfxUniformStaging.length) return;

		var staging = __bgfxUniformStaging[index];
		if (staging.length < 16) return;

		if (transposed)
		{
			for (row in 0...4)
			{
				for (column in 0...4)
				{
					staging[row * 4 + column] = rawData[column * 4 + row];
				}
			}
		}
		else
		{
			for (i in 0...16)
			{
				staging[i] = rawData[i];
			}
		}

		__bgfxUniformDirty[index] = true;
	}
	#end

	@:noCompletion private function new(context3D:Context3D, format:Context3DProgramFormat)
	{
		__context = context3D;
		__format = format;

		if (__format == AGAL)
		{
			// __memUsage = 0;
			__agalSamplerUsageMask = 0;
			__agalUniforms = new List<Uniform>();
			__agalSamplerUniforms = new List<Uniform>();
			__agalAlphaSamplerUniforms = new List<Uniform>();
			__agalAlphaSamplerEnabled = new Array<Uniform>();
		}
		else
		{
			__glslAttribNames = new Array();
			__glslAttribTypes = new Array();
			__glslSamplerNames = new Array();
			__glslUniformLocations = new Array();
			__glslUniformNames = new Array();
			__glslUniformTypes = new Array();
		}

		__samplerStates = new Array<SamplerState>();
	}

	/**
		Frees all resources associated with this object. After disposing a
		Program3D object, calling `upload()` and rendering using this object will fail.
	**/
	public function dispose():Void
	{
		__deleteShaders();
	}

	/**
		**BETA**

		Get the index for the specified shader attribute.

		@returns	The index, or -1 if the attribute is not bound or
		was not found in the shader sources
	**/
	public function getAttributeIndex(name:String):Int
	{
		if (__format == AGAL)
		{
			// TODO: Validate that it exists in the current program

			if (StringTools.startsWith(name, "va"))
			{
				return Std.parseInt(name.substring(2));
			}
			else
			{
				return -1;
			}
		}
		else
		{
			for (i in 0...__glslAttribNames.length)
			{
				if (__glslAttribNames[i] == name) return i;
			}

			return -1;
		}
	}

	/**
		**BETA**

		Get the index for the specified shader constant.

		@returns	The index, or -1 if the constant is not bound or
		was not found in the shader sources
	**/
	public function getConstantIndex(name:String):Int
	{
		if (__format == AGAL)
		{
			// TODO: Validate that it exists in the current program

			if (StringTools.startsWith(name, "vc"))
			{
				return Std.parseInt(name.substring(2));
			}
			else if (StringTools.startsWith(name, "fc"))
			{
				return Std.parseInt(name.substring(2));
			}
			else
			{
				return -1;
			}
		}
		else
		{
			for (i in 0...__glslUniformNames.length)
			{
				if (__glslUniformNames[i] == name) return cast __glslUniformLocations[i];
			}

			return -1;
		}
	}

	/**
		Uploads a pair of rendering programs expressed in AGAL (Adobe Graphics Assembly
		Language) bytecode.

		Program bytecode can be created using the Pixel Bender 3D offline tools. It can
		also be created dynamically. The AGALMiniAssembler class is a utility class
		that compiles AGAL assembly language programs to AGAL bytecode. The class is not
		part of the runtime. When you upload the shader programs, the bytecode is
		compiled into the native shader language for the current device (for example,
		OpenGL or Direct3D). The runtime validates the bytecode on upload.

		The programs run whenever the Context3D `drawTriangles()` method is invoked. The
		vertex program is executed once for each vertex in the list of triangles to be
		drawn. The fragment program is executed once for each pixel on a triangle surface.

		The "variables" used by a shader program are called registers. The following
		registers are defined:

		| Name | Number per Fragment program | Number per Vertex program | Purpose |
		| --- | --- | --- | --- |
		| Attribute | n/a | 8 | Vertex shader input; read from a vertex buffer specified using `Context3D.setVertexBufferAt()`. |
		| Constant | 28 | 128 | Shader input; set using the `Context3D.setProgramConstants()` family of functions. |
		| Temporary | 8 | 8 | Temporary register for computation, not accessible outside program. |
		| Output | 1 | 1 | Shader output: in a vertex program, the output is the clipspace position; in a fragment program, the output is a color. |
		| Varying | 8 | 8 | Transfer interpolated data between vertex and fragment shaders. The varying registers from the vertex program are applied as input to the fragment program. Values are interpolated according to the distance from the triangle vertices. |
		| Sampler | 8 | n/a | Fragment shader input; read from a texture specified using `Context3D.setTextureAt()` |

		A vertex program receives input from two sources: vertex buffers and constant
		registers. Specify which vertex data to use for a particular vertex attribute
		register using the Context3D `setVertexBufferAt()` method. You can define up to
		eight input registers for vertex attributes. The vertex attribute values are read
		from the vertex buffer for each vertex in the triangle list and placed in the
		attribute register. Specify constant registers using the Context3D
		`setProgramConstantsFromMatrix()` or `setProgramConstantsFromVector()`
		methods. Constant registers retain the same value for every vertex in the
		triangle list. (You can only modify the constant values between calls to
		`drawTriangles().`)

		The vertex program is responsible for projecting the triangle vertices into
		clip space (the canonical viewing area within ±1 on the x and y axes and 0-1 on
		the z axis) and placing the transformed coordinates in its output register.
		(Typically, the appropriate projection matrix is provided to the shader in a set
		of constant registers.) The vertex program must also copy any vertex attributes
		or computed values needed by the fragment program to a special set of variables
		called varying registers. When a fragment shader runs, the value supplied in a
		varying register is linearly interpolated according to the distance of the
		current fragment from each triangle vertex.

		A fragment program receives input from the varying registers and from a separate
		set of constant registers (set with `setProgramConstantsFromMatrix()` or
		`setProgramConstantsFromVector()`). You can also read texture data from textures
		uploaded to the rendering context using sampler registers. Specify which texture
		to access with a particular sampler register using the Context3D `setTextureAt()`
		method. The fragment program is responsible for setting its output register to a
		color value.

		@param	vertexProgram	AGAL bytecode for the Vertex program. The ByteArray object
		must use the little endian format.
		@param	fragmentProgram	AGAL bytecode for the Fragment program. The ByteArray
		object must use the little endian format.
		@throws	TypeError	Null Pointer Error: if vertexProgram or fragmentProgram is
		`null`.
		@throws	Error	Object Disposed: if the Program3D object was disposed either
		directly by a call to `dispose()`, or indirectly by calling the Context3D
		`dispose()` or because the rendering context was disposed because of device loss.
		@throws	ArgumentError	Agal Program Too Small: when either program code array
		is smaller than 31 bytes length. This is the size of the shader bytecode of a
		one-instruction program.
		@throws	ArgumentError	Program Must Be Little Endian: if either of the program
		byte code arrays is not little endian.
		@throws	Error	Native Shader Compilation Failed: if the output of the AGAL
		translator is not a compilable native shader language program. This error is only
		thrown in release players.
		@throws	Error	Native Shader Compilation Failed OpenGL: if the output of the
		AGAL translator is not a compilable OpengGL shader language program, and
		includes compilation diagnostics. This error is only thrown in debug players.
		@throws	Error	Native Shader Compilation Failed D3D9: if the output of the AGAL
		translator is not a compilable Direct3D shader language program, and includes
		compilation diagnostics. This error is only thrown in debug players.

		The following errors are thrown when the AGAL bytecode validation fails:

		@throws	Error	Not An Agal Program: if the header "magic byte" is wrong. The
		first byte of the bytecode must be 0xa0. This error can indicate that the byte
		array is set to the wrong endian order.
		@throws	Error	Bad Agal Version: if the AGAL version is not supported by the
		current SWF version. The AGAL version must be set to 1 for SWF version 13.
		@throws	Error	Bad Agal Program Type: if the AGAL program type identifier is
		not valid. The third byte in the byte code must be 0xa1. This error can indicates
		that the byte array is set to the wrong endian order.
		@throws	Error	Bad Agal Shader Type: if the shader type code is not either
		fragment or vertex (1 or 0).
		@throws	Error	Invalid Agal Opcode Out Of Range: if an invalid opcode is
		encountered in the token stream.
		@throws	Error	Invalid Agal Opcode Not Implemented: if an invalid opcode is
		encountered in the token stream.
		@throws	Error	Agal Opcode Only Allowed In Fragment Program: if an opcode is
		encountered in the token stream of the vertex program that is only allowed in fragment programs, such as KIL or TEX.
		@throws	Error	Bad Agal Source Operands: if both source operands are constant
		registers. You must compute the result outside the shader program and pass it
		in using a single constant register.
		@throws	Error	Both Operands Are Indirect Reads: if both operands are indirect
		reads.
		@throws	Error	Opcode Destination Must Be All Zero: if a token with an opcode
		(such as KIL) that has no destination sets a non-zero value for the destination
		register.
		@throws	Error	Opcode Destination Must Use Mask: if an opcode that produces
		only a 3 component result is used without masking.
		@throws	Error	Too Many Tokens: if there are too many tokens (more than 200) in
		an AGAL program.
		@throws	Error	Fragment Shader Type: if the fragment program type (byte 6 of
		fragmentProgram parameter) is not set to 1.
		@throws	Error	Vertex Shader Type: if the vertex program type (byte 6 of
		vertexProgram parameter) is not set to 0.
		@throws	Error	Varying Read But Not Written To: if the fragment shader reads a
		varying register that was never written to by the vertex shader.
		@throws	Error	Varying Partial Write: if a varying register is only partially
		written to. All components of a varying register must be written to.
		@throws	Error	Fragment Write All Components: if a fragment color output is only
		partially written to. All four components of the color output must be written to.
		@throws	Error	Vertex Write All Components: if a vertex clip space output is only
		partially written to. All components of the vertex clip space output must be
		written to.
		@throws	Error	Unused Operand: if an unused operand in a token is not set to all
		zero.
		@throws	Error	Sampler Register Only In Fragment: if a texture sampler register
		is used in a vertex program.
		@throws	Error	Sampler Register Second Operand: if a sampler register is used
		as a destination or first operand of an AGAL token.
		@throws	Error	Indirect Only Allowed In Vertex: if indirect addressing is used
		in a fragment program.
		@throws	Error	Indirect Only Into Constant Registers: if indirect addressing
		is used on a non-constant register.
		@throws	Error	Indirect Source Type: if the indirect source type is not
		attribute, constant or temporary register.
		@throws	Error	Indirect Addressing Fields Must Be Zero: if not all indirect
		addressing fields are zero for direct addressing.
		@throws	Error	Varying Registers Only Read In Fragment: if a varying register is
		read in a vertex program. Varying registers can only be written in vertex
		programs and read in fragment programs.
		@throws	Error	Attribute Registers Only Read In Vertex: if an attribute
		registers is read in a fragment program. Attribute registers can only be read
		in vertex programs.
		@throws	Error	Can Not Read Output Register: if an output (position or color)
		register is read. Output registers can only be written to, not read.
		@throws	Error	Temp Register Read Without Write: if a temporary register is read
		without being written to earlier.
		@throws	Error	Temp Register Component Read Without Write: if a specific
		temporary register component is read without being written to earlier.
		@throws	Error	Sampler Register Cannot Be Written To: if a sampler register is
		written to. Sampler registers can only be read, not written to.
		@throws	Error	Varying Registers Write: if a varying register is written to in
		a fragment program. Varying registers can only be written in vertex programs and
		read in fragment programs.
		@throws	Error	Attribute Register Cannot Be Written To: if an attribute
		register is written to. Attribute registers are read-only.
		@throws	Error	Constant Register Cannot Be Written To: if a constant register
		is written to inside a shader program.
		@throws	Error	Destination Writemask Is Zero: if a destination writemask is
		zero. All components of an output register must be set.
		@throws	Error	AGAL Reserved Bits Should Be Zero: if any reserved bits in a
		token are not zero. This indicates an error in creating the bytecode (or
		malformed bytecode).
		@throws	Error	Unknown Register Type: if an invalid register type index is used.
		@throws	Error	Sampler Register Out Of Bounds: if an invalid sampler register
		index is used.
		@throws	Error	Varying Register Out Of Bounds: if an invalid varying register
		index is used.
		@throws	Error	Attribute Register Out Of Bounds: if an invalid attribute
		register index is used.
		@throws	Error	Constant Register Out Of Bounds: if an invalid constant
		register index is used.
		@throws	Error	Output Register Out Of Bounds: if an invalid output register
		index is used.
		@throws	Error	Temporary Register Out Of Bounds: if an invalid temporary
		register index is used.
		@throws	Error	Cube Map Sampler Must Use Clamp: if a cube map sampler does not
		set the wrap mode to clamp.
		@throws	Error	Unknown Sampler Dimension: if a sample uses an unknown sampler
		dimension. (Only 2D and cube textures are supported.)
		@throws	Error	Unknown Filter Mode: if a sampler uses an unknown filter mode.
		(Only nearest neighbor and linear filtering are supported.)
		@throws	Error	Unknown Mipmap Mode: if a sampler uses an unknown mipmap mode.
		(Only none, nearest neighbor, and linear mipmap modes are supported.)
		@throws	Error	Unknown Wrapping Mode if a sampler uses an unknown wrapping mode.
		(Only clamp and repeat wrapping modes are supported.)
		@throws	Error	Unknown Special Flag: if a sampler uses an unknown special flag.
		@throws	Error	Output Color Not Maskable: You cannot mask the color output
		register in a fragment program. All components of the color register must be set.
		@throws	Error	Second Operand Must Be Sampler Register: The AGAL tex opcode must
		have a sampler as the second source operand.
		@throws	Error	Indirect Not Allowed: indirect addressing used where not allowed.
		@throws	Error	Swizzle Must Be Scalar: swizzling error.
		@throws	Error	Cant Swizzle 2nd Source: swizzling error.
		@throws	Error	Second Use Of Sampler Must Have Same Params: all samplers that
		access the same texture must use the same dimension, wrap, filter, special, and
		mipmap settings.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function upload(vertexProgram:ByteArray, fragmentProgram:ByteArray):Void
	{
		if (__format != AGAL) return;

		// var samplerStates = new Vector<SamplerState> (Context3D.MAX_SAMPLERS);
		var samplerStates = new Array<SamplerState>();

		var glslVertex = AGALConverter.convertToGLSL(vertexProgram, null);
		var glslFragment = AGALConverter.convertToGLSL(fragmentProgram, samplerStates);

		if (Log.level == LogLevel.VERBOSE)
		{
			Log.info(glslVertex);
			Log.info(glslFragment);
		}

		#if (lime && !js)
		// AGAL programs run through the same GLSL → bgfx path; the register
		// constant API (setProgramConstantsFrom*) is not wired up yet, so
		// AGAL content renders but only with default uniform values
		__deleteShaders();
		__uploadBGFX(glslVertex, glslFragment);
		#else
		__deleteShaders();
		__uploadFromGLSL(glslVertex, glslFragment);
		__buildAGALUniformList();
		#end

		for (i in 0...samplerStates.length)
		{
			__samplerStates[i] = samplerStates[i];
		}
	}

	/**
		**BETA**

		Uploads a pair of rendering programs expressed in GLSL (GL Shader Language).
	**/
	public function uploadSources(vertexSource:String, fragmentSource:String):Void
	{
		if (__format != GLSL) return;

		// TODO: Precision hint?

		var prefix = "#ifdef GL_ES
			#ifdef GL_FRAGMENT_PRECISION_HIGH
			precision highp float;
			#else
			precision mediump float;
			#endif
			#endif
			";

		var vertex = prefix + vertexSource;
		var fragment = prefix + fragmentSource;

		if (vertex == __glVertexSource && fragment == __glFragmentSource) return;

		__processGLSLData(vertexSource, "attribute");
		__processGLSLData(vertexSource, "uniform");
		__processGLSLData(fragmentSource, "uniform");

		#if (lime && !js)
		__deleteShaders();
		__uploadBGFX(vertexSource, fragmentSource);

		// locations are staging-table indices on the BGFX backend
		__glslUniformLocations = [];

		for (i in 0...__glslUniformNames.length)
		{
			__glslUniformLocations[i] = cast __bgfxUniformIndex(__glslUniformNames[i]);
		}

		return;
		#end

		__deleteShaders();
		__uploadFromGLSL(vertex, fragment);

		// Sort by index

		var samplerNames = __glslSamplerNames;
		var attribNames = __glslAttribNames;
		var attribTypes = __glslAttribTypes;
		var uniformNames = __glslUniformNames;

		__glslSamplerNames = new Array();
		__glslAttribNames = new Array();
		__glslAttribTypes = new Array();
		__glslUniformLocations = new Array();

		var gl = __context.gl;
		var index:Int, location;

		for (name in samplerNames)
		{
			index = cast gl.getUniformLocation(__glProgram, name);
			__glslSamplerNames[index] = name;
		}

		for (i in 0...attribNames.length)
		{
			index = gl.getAttribLocation(__glProgram, attribNames[i]);
			__glslAttribNames[index] = attribNames[i];
			__glslAttribTypes[index] = attribTypes[i];
		}

		for (i in 0...uniformNames.length)
		{
			location = gl.getUniformLocation(__glProgram, uniformNames[i]);
			__glslUniformLocations[i] = location;
		}
	}

	@:noCompletion private function __buildAGALUniformList():Void
	{
		if (__format == GLSL) return;

		#if lime
		var gl = __context.gl;

		__agalUniforms.clear();
		__agalSamplerUniforms.clear();
		__agalAlphaSamplerUniforms.clear();
		__agalAlphaSamplerEnabled = [];

		__agalSamplerUsageMask = 0;

		var numActive = 0;
		numActive = gl.getProgramParameter(__glProgram, gl.ACTIVE_UNIFORMS);

		var vertexUniforms = new List<Uniform>();
		var fragmentUniforms = new List<Uniform>();

		for (i in 0...numActive)
		{
			var info = gl.getActiveUniform(__glProgram, i);
			var name = info.name;
			var size = info.size;
			var uniformType = info.type;

			var uniform = new Uniform(__context);
			uniform.name = name;
			uniform.size = size;
			uniform.type = uniformType;

			uniform.location = gl.getUniformLocation(__glProgram, uniform.name);

			var indexBracket = uniform.name.indexOf("[");

			if (indexBracket >= 0)
			{
				uniform.name = uniform.name.substring(0, indexBracket);
			}

			switch (uniform.type)
			{
				case GL.FLOAT_MAT2:
					uniform.regCount = 2;
				case GL.FLOAT_MAT3:
					uniform.regCount = 3;
				case GL.FLOAT_MAT4:
					uniform.regCount = 4;
				default:
					uniform.regCount = 1;
			}

			uniform.regCount *= uniform.size;

			__agalUniforms.add(uniform);

			if (uniform.name == "vcPositionScale")
			{
				__agalPositionScale = uniform;
			}
			else if (StringTools.startsWith(uniform.name, "vc"))
			{
				uniform.regIndex = Std.parseInt(uniform.name.substring(2));
				uniform.regData = __context.__vertexConstants;
				vertexUniforms.add(uniform);
			}
			else if (StringTools.startsWith(uniform.name, "fc"))
			{
				uniform.regIndex = Std.parseInt(uniform.name.substring(2));
				uniform.regData = __context.__fragmentConstants;
				fragmentUniforms.add(uniform);
			}
			else if (StringTools.startsWith(uniform.name, "sampler") && uniform.name.indexOf("alpha") == -1)
			{
				uniform.regIndex = Std.parseInt(uniform.name.substring(7));
				__agalSamplerUniforms.add(uniform);

				for (reg in 0...uniform.regCount)
				{
					__agalSamplerUsageMask |= (1 << (uniform.regIndex + reg));
				}
			}
			else if (StringTools.startsWith(uniform.name, "sampler") && StringTools.endsWith(uniform.name, "_alpha"))
			{
				var len = uniform.name.indexOf("_") - 7;
				uniform.regIndex = Std.parseInt(uniform.name.substring(7, 7 + len)) + 4;
				__agalAlphaSamplerUniforms.add(uniform);
			}
			else if (StringTools.startsWith(uniform.name, "sampler") && StringTools.endsWith(uniform.name, "_alphaEnabled"))
			{
				uniform.regIndex = Std.parseInt(uniform.name.substring(7));
				__agalAlphaSamplerEnabled[uniform.regIndex] = uniform;
			}

			if (Log.level == LogLevel.VERBOSE)
			{
				Log.verbose('${i} name:${uniform.name} type:${uniform.type} size:${uniform.size} location:${uniform.location}');
			}
		}

		__agalVertexUniformMap = new UniformMap(Lambda.array(vertexUniforms));
		__agalFragmentUniformMap = new UniformMap(Lambda.array(fragmentUniforms));
		#end
	}

	@:noCompletion private function __deleteShaders():Void
	{
		#if (lime && !js)
		if (__bgfxProgram != -1)
		{
			BGFX.destroyProgram(__bgfxProgram);
			__bgfxProgram = -1;
		}

		if (__bgfxUniformHandles != null)
		{
			for (handle in __bgfxUniformHandles)
			{
				BGFX.destroyUniform(handle);
			}

			__bgfxUniformHandles = null;
		}

		if (__bgfxSamplerHandles != null)
		{
			for (handle in __bgfxSamplerHandles)
			{
				BGFX.destroyUniform(handle);
			}

			__bgfxSamplerHandles = null;
		}

		__bgfxTranslated = null;
		return;
		#end

		var gl = __context.gl;

		if (__glProgram != null)
		{
			__glProgram = null;
		}

		if (__glVertexShader != null)
		{
			gl.deleteShader(__glVertexShader);
			__glVertexShader = null;
		}

		if (__glFragmentShader != null)
		{
			gl.deleteShader(__glFragmentShader);
			__glFragmentShader = null;
		}
	}

	@:noCompletion private function __disable():Void
	{
		if (__format == GLSL)
		{
			// var gl = __context.gl;
			// var textureCount = 0;

			// for (input in __glslInputBitmapData) {

			// 	input.__disableGL (__context, textureCount);
			// 	textureCount++;

			// }

			// for (parameter in __glslParamBool) {

			// 	parameter.__disableGL (__context);

			// }

			// for (parameter in __glslParamFloat) {

			// 	parameter.__disableGL (__context);

			// }

			// for (parameter in __glslParamInt) {

			// 	parameter.__disableGL (__context);

			// }

			// // __context.__bindGLArrayBuffer (null);

			// if (__context.__context.type == OPENGL) {

			// 	gl.disable (gl.TEXTURE_2D);

			// }
		}
	}

	@:noCompletion private function __enable():Void
	{
		#if (lime && !js)
		// bgfx binds the program at submit time
		return;
		#end

		var gl = __context.gl;
		gl.useProgram(__glProgram);

		if (__format == AGAL)
		{
			__agalVertexUniformMap.markAllDirty();
			__agalFragmentUniformMap.markAllDirty();

			for (sampler in __agalSamplerUniforms)
			{
				if (sampler.regCount == 1)
				{
					gl.uniform1i(sampler.location, sampler.regIndex);
				}
				else
				{
					throw new IllegalOperationError("!!! TODO: uniform location on webgl");
				}
			}

			for (sampler in __agalAlphaSamplerUniforms)
			{
				if (sampler.regCount == 1)
				{
					gl.uniform1i(sampler.location, sampler.regIndex);
				}
				else
				{
					throw new IllegalOperationError("!!! TODO: uniform location on webgl");
				}
			}
		}
		else
		{
			// var textureCount = 0;

			// var gl = __context.gl;

			// for (input in __glslInputBitmapData) {

			// 	gl.uniform1i (input.index, textureCount);
			// 	textureCount++;

			// }

			// if (__context.__context.type == OPENGL && textureCount > 0) {

			// 	gl.enable (gl.TEXTURE_2D);

			// }
		}
	}

	@:noCompletion private function __flush():Void
	{
		if (__format == AGAL)
		{
			__agalVertexUniformMap.flush();
			__agalFragmentUniformMap.flush();
		}
		else
		{
			// TODO
			return;

			// var textureCount = 0;

			// for (input in __glslInputBitmapData) {

			// 	input.__updateGL (__context, textureCount);
			// 	textureCount++;

			// }

			// for (parameter in __glslParamBool) {

			// 	parameter.__updateGL (__context);

			// }

			// for (parameter in __glslParamFloat) {

			// 	parameter.__updateGL (__context);

			// }

			// for (parameter in __glslParamInt) {

			// 	parameter.__updateGL (__context);

			// }
		}
	}

	@:noCompletion private function __getSamplerState(sampler:Int):SamplerState
	{
		return __samplerStates[sampler];
	}

	@:noCompletion private function __markDirty(isVertex:Bool, index:Int, count:Int):Void
	{
		if (__format == GLSL) return;

		if (isVertex)
		{
			__agalVertexUniformMap.markDirty(index, count);
		}
		else
		{
			__agalFragmentUniformMap.markDirty(index, count);
		}
	}

	@:noCompletion private function __processGLSLData(source:String, storageType:String):Void
	{
		var lastMatch = 0, position, regex, name, type;

		if (storageType == "uniform")
		{
			regex = ~/uniform ([A-Za-z0-9]+) ([A-Za-z0-9_]+)/;
		}
		else
		{
			regex = ~/attribute ([A-Za-z0-9]+) ([A-Za-z0-9_]+)/;
		}

		while (regex.matchSub(source, lastMatch))
		{
			type = regex.matched(1);
			name = regex.matched(2);

			if (StringTools.startsWith(name, "gl_"))
			{
				continue;
			}

			if (StringTools.startsWith(type, "sampler"))
			{
				__glslSamplerNames.push(name);
			}
			else
			{
				var parameterType:ShaderParameterType = switch (type)
				{
					case "bool": BOOL;
					case "double", "float": FLOAT;
					case "int", "uint": INT;
					case "bvec2": BOOL2;
					case "bvec3": BOOL3;
					case "bvec4": BOOL4;
					case "ivec2", "uvec2": INT2;
					case "ivec3", "uvec3": INT3;
					case "ivec4", "uvec4": INT4;
					case "vec2", "dvec2": FLOAT2;
					case "vec3", "dvec3": FLOAT3;
					case "vec4", "dvec4": FLOAT4;
					case "mat2", "mat2x2": MATRIX2X2;
					case "mat2x3": MATRIX2X3;
					case "mat2x4": MATRIX2X4;
					case "mat3x2": MATRIX3X2;
					case "mat3", "mat3x3": MATRIX3X3;
					case "mat3x4": MATRIX3X4;
					case "mat4x2": MATRIX4X2;
					case "mat4x3": MATRIX4X3;
					case "mat4", "mat4x4": MATRIX4X4;
					default: null;
				}

				if (storageType == "uniform")
				{
					__glslUniformNames.push(name);
					__glslUniformTypes.push(parameterType);
				}
				else
				{
					__glslAttribNames.push(name);
					__glslAttribTypes.push(parameterType);
				}
			}

			position = regex.matchedPos();
			lastMatch = position.pos + position.len;
		}
	}

	@:noCompletion private function __setPositionScale(positionScale:Float32Array):Void
	{
		if (__format == GLSL) return;

		if (__agalPositionScale != null)
		{
			var gl = __context.gl;
			gl.uniform4fv(__agalPositionScale.location, positionScale);
		}
	}

	@:noCompletion private function __setSamplerState(sampler:Int, state:SamplerState):Void
	{
		__samplerStates[sampler] = state;
	}

	@:noCompletion private function __uploadFromGLSL(vertexShaderSource:String, fragmentShaderSource:String):Void
	{
		var gl = __context.gl;

		__glVertexSource = vertexShaderSource;
		__glFragmentSource = fragmentShaderSource;

		__glVertexShader = gl.createShader(gl.VERTEX_SHADER);
		gl.shaderSource(__glVertexShader, vertexShaderSource);
		gl.compileShader(__glVertexShader);

		if (gl.getShaderParameter(__glVertexShader, gl.COMPILE_STATUS) == 0)
		{
			var message = "Error compiling vertex shader";
			message += "\n" + gl.getShaderInfoLog(__glVertexShader);
			message += "\n" + vertexShaderSource;
			Log.error(message);
		}

		__glFragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
		gl.shaderSource(__glFragmentShader, fragmentShaderSource);
		gl.compileShader(__glFragmentShader);

		if (gl.getShaderParameter(__glFragmentShader, gl.COMPILE_STATUS) == 0)
		{
			var message = "Error compiling fragment shader";
			message += "\n" + gl.getShaderInfoLog(__glFragmentShader);
			message += "\n" + fragmentShaderSource;
			Log.error(message);
		}

		__glProgram = gl.createProgram();

		if (__format == AGAL)
		{
			// TODO: AGAL version specific number of attributes?
			for (i in 0...16)
			{
				// for (i in 0...Context3D.MAX_ATTRIBUTES) {

				var name = "va" + i;

				if (vertexShaderSource.indexOf(" " + name) != -1)
				{
					gl.bindAttribLocation(__glProgram, i, name);
				}
			}
		}
		else
		{
			// Fix support for drivers that don't draw if attribute 0 is disabled
			for (name in __glslAttribNames)
			{
				if (name.indexOf("Position") > -1 && StringTools.startsWith(name, "openfl_"))
				{
					gl.bindAttribLocation(__glProgram, 0, name);
					break;
				}
			}
		}

		gl.attachShader(__glProgram, __glVertexShader);
		gl.attachShader(__glProgram, __glFragmentShader);
		gl.linkProgram(__glProgram);

		if (gl.getProgramParameter(__glProgram, gl.LINK_STATUS) == 0)
		{
			var message = "Unable to initialize the shader program";
			message += "\n" + gl.getProgramInfoLog(__glProgram);
			Log.error(message);
		}
	}
}

@:access(openfl.display3D.Context3D)
@SuppressWarnings("checkstyle:FieldDocComment")
@:dox(hide) @:noCompletion class Uniform
{
	public var name:String;
	public var location:GLUniformLocation;
	public var type:Int;
	public var size:Int;
	public var regData:Float32Array;
	public var regIndex:Int;
	public var regCount:Int;
	public var isDirty:Bool;
	public var context:Context3D;
	#if lime
	public var regDataPointer:BytePointer;
	#end

	public function new(context:Context3D)
	{
		this.context = context;

		isDirty = true;

		#if lime
		regDataPointer = new BytePointer();
		#end
	}

	public function flush():Void
	{
		#if (lime && !js)
		// AGAL register uniforms are not wired to the BGFX backend yet
		return;
		#elseif lime
		#if (js && html5)
		var gl = context.gl;
		#else
		var gl = context.__context.gles2;
		#end

		var index:Int = regIndex * 4;
		switch (type)
		{
			#if (js && html5)
			case GL.FLOAT_MAT2:
				gl.uniformMatrix2fv(location, false, __getUniformRegisters(index, size * 2 * 2));
			case GL.FLOAT_MAT3:
				gl.uniformMatrix3fv(location, false, __getUniformRegisters(index, size * 3 * 3));
			case GL.FLOAT_MAT4:
				gl.uniformMatrix4fv(location, false, __getUniformRegisters(index, size * 4 * 4));
			case GL.FLOAT_VEC2:
				gl.uniform2fv(location, __getUniformRegisters(index, regCount * 2));
			case GL.FLOAT_VEC3:
				gl.uniform3fv(location, __getUniformRegisters(index, regCount * 3));
			case GL.FLOAT_VEC4:
				gl.uniform4fv(location, __getUniformRegisters(index, regCount * 4));
			default:
				gl.uniform4fv(location, __getUniformRegisters(index, regCount * 4));
			#else
			case GL.FLOAT_MAT2:
				gl.uniformMatrix2fv(location, size, false, __getUniformRegisters(index, size * 2 * 2));
			case GL.FLOAT_MAT3:
				gl.uniformMatrix3fv(location, size, false, __getUniformRegisters(index, size * 3 * 3));
			case GL.FLOAT_MAT4:
				gl.uniformMatrix4fv(location, size, false, __getUniformRegisters(index, size * 4 * 4));
			case GL.FLOAT_VEC2:
				gl.uniform2fv(location, regCount, __getUniformRegisters(index, regCount * 2));
			case GL.FLOAT_VEC3:
				gl.uniform3fv(location, regCount, __getUniformRegisters(index, regCount * 3));
			case GL.FLOAT_VEC4:
				gl.uniform4fv(location, regCount, __getUniformRegisters(index, regCount * 4));
			default:
				gl.uniform4fv(location, regCount, __getUniformRegisters(index, regCount * 4));
			#end
		}
		#end
	}

	#if (js && html5)
	@:noCompletion private inline function __getUniformRegisters(index:Int, size:Int):Float32Array
	{
		return regData.subarray(index, index + size);
	}
	#elseif lime
	@:noCompletion private inline function __getUniformRegisters(index:Int, size:Int):BytePointer
	{
		regDataPointer.set(regData, index * 4);
		return regDataPointer;
	}
	#else
	@:noCompletion private inline function __getUniformRegisters(index:Int, size:Int):Dynamic
	{
		return regData.subarray(index, index + size);
	}
	#end
}

@SuppressWarnings("checkstyle:FieldDocComment")
@:dox(hide) @:noCompletion class UniformMap
{
	// TODO: it would be better to use a bitmask with a dirty bit per uniform, but not super important now
	@:noCompletion private var __allDirty:Bool;
	@:noCompletion private var __anyDirty:Bool;
	@:noCompletion private var __registerLookup:Array<Uniform>;
	@:noCompletion private var __uniforms:Array<Uniform>;

	public function new(list:Array<Uniform>)
	{
		__uniforms = list;

		__uniforms.sort(function(a, b):Int
		{
			return Reflect.compare(a.regIndex, b.regIndex);
		});

		var total = 0;

		for (uniform in __uniforms)
		{
			if (uniform.regIndex + uniform.regCount > total)
			{
				total = uniform.regIndex + uniform.regCount;
			}
		}

		__registerLookup = [];

		__registerLookup.resize(total);

		for (uniform in __uniforms)
		{
			for (i in 0...uniform.regCount)
			{
				__registerLookup[uniform.regIndex + i] = uniform;
			}
		}

		__anyDirty = __allDirty = true;
	}

	public function flush():Void
	{
		if (__anyDirty)
		{
			for (uniform in __uniforms)
			{
				if (__allDirty || uniform.isDirty)
				{
					uniform.flush();
					uniform.isDirty = false;
				}
			}

			__anyDirty = __allDirty = false;
		}
	}

	public function markAllDirty():Void
	{
		__allDirty = true;
		__anyDirty = true;
	}

	public function markDirty(start:Int, count:Int):Void
	{
		if (__allDirty)
		{
			return;
		}

		var end = start + count;

		if (end > __registerLookup.length)
		{
			end = __registerLookup.length;
		}

		var index = start;

		while (index < end)
		{
			var uniform = __registerLookup[index];

			if (uniform != null)
			{
				uniform.isDirty = true;
				__anyDirty = true;

				index = uniform.regIndex + uniform.regCount;
			}
			else
			{
				index++;
			}
		}
	}
}
