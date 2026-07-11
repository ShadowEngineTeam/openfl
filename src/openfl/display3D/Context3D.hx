package openfl.display3D;

import openfl.display3D._internal.Context3DState;
import openfl.display3D._internal.GLBuffer;
import openfl.display3D._internal.GLFramebuffer;
import openfl.display3D._internal.GLTexture;
import openfl.display._internal.SamplerState;
import openfl.display3D.textures.ASTCTexture;
import openfl.display3D.textures.BCTexture;
import openfl.display3D.textures.CubeTexture;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.textures.Texture;
import openfl.display3D.textures.VideoTexture;
import openfl.display.BitmapData;
import openfl.display.Stage;
import openfl.display.Stage3D;
import openfl.errors.Error;
import openfl.errors.IllegalOperationError;
import openfl.events.EventDispatcher;
import openfl.geom.Matrix3D;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils._internal.Float32Array;
import openfl.utils._internal.UInt16Array;
import openfl.utils._internal.UInt8Array;
import openfl.utils.AGALMiniAssembler;
import openfl.utils.ByteArray;
import openfl.display.OpenGLRenderer;
#if lime
import lime.graphics.opengl.GL;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.RenderContext;
import lime.graphics.WebGLRenderContext;
import lime.math.Rectangle as LimeRectangle;
import lime.math.Vector2;
#end
#if (lime && !js)
import lime.graphics.bgfx.BGFX;
import lime.graphics.bgfx.BGFXVertexLayout;
#end

/**
	The Context3D class provides a context for rendering geometrically defined graphics.
	A rendering context includes a drawing surface and its associated resources and
	state. When possible, the rendering context uses the hardware graphics processing
	unit (GPU). Otherwise, the rendering context uses software. (If rendering through
	Context3D is not supported on a platform, the stage3Ds property of the Stage object
	contains an empty list.)

	The Context3D rendering context is a programmable pipeline that is very similar to
	OpenGL ES 2, but is abstracted so that it is compatible with a range of hardware and
	GPU interfaces. Although designed for 3D graphics, the rendering pipeline does not
	mandate that the rendering is three dimensional. Thus, you can create a 2D renderer
	by supplying the appropriate vertex and pixel fragment programs. In both the 3D and
	2D cases, the only geometric primitive supported is the triangle.

	Get an instance of the Context3D class by calling the requestContext3D() method of a
	Stage3D object. A limited number of Context3D objects can exist per stage; one for
	each Stage3D in the Stage.stage3Ds list. When the context is created, the Stage3D
	object dispatches a context3DCreate event. A rendering context can be destroyed and
	recreated at any time, such as when another application that uses the GPU gains
	focus. Your code should anticipate receiving multiple context3DCreate events.
	Position the rendering area on the stage using the x and y properties of the
	associated Stage3D instance.

	To render and display a scene (after getting a Context3D object), the following steps
	are typical:

	1. Configure the main display buffer attributes by calling `configureBackBuffer()`.
	2. Create and initialize your rendering resources, including:
	   * Vertex and index buffers defining the scene geometry
	   * Vertex and pixel programs (shaders) for rendering the scene
	   * Textures
	3. Render a frame:
	   * Set the render state as appropriate for an object or collection of objects in
	   the scene.
	   * Call the `drawTriangles()` method to render a set of triangles.
	   * Change the rendering state for the next group of objects.
	   * Call `drawTriangles()` to draw the triangles defining the objects.
	   * Repeat until the scene is entirely rendered.
	   * Call the `present()` method to display the rendered scene on the stage.

	The following limits apply to rendering:

	Resource limits:

	| Resource | Number allowed | Total memory |
	| --- | --- | --- |
	| Vertex buffers | 4096 | 256 MB |
	| Index buffers | 4096 | 128 MB |
	| Programs | 4096 | 16 MB |
	| Textures | 4096 | 128 MB |
	| Cube textures | 4096 | 256 MB |

	AGAL limits: 200 opcodes per program.

	Draw call limits: 32,768 `drawTriangles()` calls for each `present()` call.

	The following limits apply to textures:

	Texture limits for AIR 32 bit:

	| Texture | Maximum size | Total GPU memory |
	| --- | --- | --- |
	| Normal Texture (below Baseline extended) | 2048x2048 | 512 MB |
	| Normal Texture (Baseline extended and above) | 4096x4096 | 512 MB |
	| Rectangular Texture (below Baseline extended) | 2048x2048 | 512 MB |
	| Rectangular Texture (Baseline extended and above) | 4096x4096 | 512 MB |
	| Cube Texture | 1024x1024 | 256 MB |

	Texture limits for AIR 64 bit (Desktop):

	| Texture | Maximum size | Total GPU memory |
	| --- | --- | --- |
	| Normal Texture (below Baseline extended) | 2048x2048 | 512 MB |
	| Normal Texture (Baseline extended to Standard) | 4096x4096 | 512 MB |
	| Normal Texture (Standard extended and above) | 4096x4096 | 2048 MB |
	| Rectangular Texture (below Baseline extended) | 2048x2048 | 512 MB |
	| Rectangular Texture (Baseline extended to Standard) | 4096x4096 | 512 MB |
	| Rectangular Texture (Standard extended and above) | 4096x4096 | 2048 MB |
	| Cube Texture | 1024x1024 | 256 MB |

	512 MB is the absolute limit for textures, including the texture memory required
	for mipmaps. However, for Cube Textures, the memory limit is 256 MB.

	You cannot create Context3D objects with the Context3D constructor. It is
	constructed and available as a property of a Stage3D instance. The Context3D class
	can be used on both desktop and mobile platforms, both when running in Flash Player
	and AIR.
**/
@:access(openfl.display3D._internal.Context3DState)
@:access(openfl.display3D.textures.ASTCTexture)
@:access(openfl.display3D.textures.BCTexture)
@:access(openfl.display3D.textures.CubeTexture)
@:access(openfl.display3D.textures.RectangleTexture)
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.textures.Texture)
@:access(openfl.display3D.textures.VideoTexture)
@:access(openfl.display3D.IndexBuffer3D)
@:access(openfl.display3D.Program3D)
@:access(openfl.display3D.VertexBuffer3D)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Bitmap)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display.Shader)
@:access(openfl.display.Stage)
@:access(openfl.display.Stage3D)
@:access(openfl.geom.Point)
@:access(openfl.geom.Rectangle)
@:final class Context3D extends EventDispatcher
{
	/**
		Indicates if Context3D supports video texture.
	**/
	public static var supportsVideoTexture(default, null):Bool = #if (js && html5) true #else false #end;

	/**
		Specifies the height of the back buffer, which can be changed by a successful
		call to the `configureBackBuffer()` method. The height may be modified when the
		browser zoom factor changes if the `wantsBestResolutionOnBrowserZoom` parameter
		is set to `true` in the last successful call to the `configureBackBuffer()`
		method. The change in height can be detected by registering an event listener
		for the browser zoom change event.
	**/
	public var backBufferHeight(default, null):Int = 0;

	/**
		Specifies the width of the back buffer, which can be changed by a successful
		call to the `configureBackBuffer()` method. The width may be modified when the
		browser zoom factor changes if the `wantsBestResolutionOnBrowserZoom` parameter
		is set to `true` in the last successful call to the `configureBackBuffer()`
		method. The change in width can be detected by registering an event listener
		for the browser zoom change event.
	**/
	public var backBufferWidth(default, null):Int = 0;

	/**
		The type of graphics library driver used by this rendering context. Indicates
		whether the rendering is using software, a DirectX driver, or an OpenGL driver.
		Also indicates whether hardware rendering failed. If hardware rendering fails,
		Flash Player uses software rendering for Stage3D and `driverInfo` contains one
		of the following values:

		* "Software Hw_disabled=userDisabled" - The Enable hardware acceleration
		checkbox in the Adobe Flash Player Settings UI is not selected.
		* "Software Hw_disabled=oldDriver" - There are known problems with the
		hardware graphics driver. Updating the graphics driver may fix this problem.
		* "Software Hw_disabled=unavailable" - Known problems with the hardware
		graphics driver or hardware graphics initialization failure.
		* "Software Hw_disabled=explicit" - The content explicitly requested software
		rendering through requestContext3D.
		* "Software Hw_disabled=domainMemory" - The content uses domainMemory, which
		requires a license when used with Stage3D hardware rendering. Visit
		adobe.com/go/fpl.
	**/
	public var driverInfo(default, null):String = "OpenGL (Direct blitting)";

	/**
		Specifies whether errors encountered by the renderer are reported to the
		application.

		When `enableErrorChecking` is `true`, the `clear()`, and `drawTriangles()`
		methods are synchronous and can throw errors. When `enableErrorChecking`
		is `false`, the default, the `clear()`, and `drawTriangles()` methods are
		asynchronous and errors are not reported. Enabling error checking reduces
		rendering performance. You should only enable error checking when debugging.
	**/
	public var enableErrorChecking(get, set):Bool;

	/**
		Specifies the maximum height of the back buffer. The inital value is the system
		limit in the platform. The property can be set to a value smaller than or equal
		to, but not greater than, the system limit. The property can be set to a value
		greater than or equal to, but not smaller than, the minimum limit. The minimum
		limit is a constant value, 32, when the back buffer is not configured. The
		minimum limit will be the value of the `height` parameter in the last successful
		call to the `configureBackBuffer()` method after the back buffer is configured.
	**/
	public var maxBackBufferHeight(default, null):Int;

	/**
		Specifies the maximum width of the back buffer. The inital value is the system
		limit in the platform. The property can be set to a value smaller than or equal
		to, but not greater than, the system limit. The property can be set to a value
		greater than or equal to, but not smaller than, the minimum limit. The minimum
		limit is a constant value, 32, when the back buffer is not configured. The
		minimum limit will be the value of the width parameter in the last successful
		call to the `configureBackBuffer()` method after the back buffer is configured.
	**/
	public var maxBackBufferWidth(default, null):Int;

	/**
		The feature-support profile in use by this Context3D object.
	**/
	public var profile(default, null):Context3DProfile = STANDARD;

	/**
		Returns the total GPU memory allocated by Stage3D data structures of an
		application.

		Whenever a GPU resource object is created, memory utilized is stored in
		Context3D. This memory includes index buffers, vertex buffers,
		textures (excluding video texture), and programs that were created through this
		Context3D.

		API totalGPUMemory returns the total memory consumed by the above resources to
		the user. Default value returned is 0. The total GPU memory returned is in bytes.
		The information is only provided in Direct mode on mobile, and in Direct and
		GPU modes on desktop. (On desktop, using `<renderMode>gpu</renderMode>` will
		fall back to `<renderMode>direct</renderMode>`)

		This API can be used when the SWF version is 32 or later.
	**/
	public var totalGPUMemory(get, never):Int;

	@:noCompletion private static var __driverInfo:String;
	@:noCompletion private static var __glDepthStencil:Int = -1;
	@:noCompletion private static var __glMaxTextureMaxAnisotropy:Int = -1;
	@:noCompletion private static var __glMaxViewportDims:Int = -1;
	@:noCompletion private static var __glMemoryCurrentAvailable:Int = -1;
	@:noCompletion private static var __glMemoryTotalAvailable:Int = -1;
	@:noCompletion private static var __glTextureMaxAnisotropy:Int = -1;

	@:noCompletion private var gl:#if lime WebGLRenderContext #else Dynamic #end;
	@:noCompletion private var __backBufferAntiAlias:Int;
	@:noCompletion private var __backBufferTexture:RectangleTexture;
	@:noCompletion private var __backBufferWantsBestResolution:Bool;
	@:noCompletion private var __backBufferWantsBestResolutionOnBrowserZoom:Bool;
	@:noCompletion private var __cleared:Bool;
	@:noCompletion private var __context:#if lime RenderContext #else Dynamic #end;
	@:noCompletion private var __contextState:Context3DState;
	@:noCompletion private var __renderStage3DProgram:Program3D;
	@:noCompletion private var __enableErrorChecking:Bool;
	@:noCompletion private var __fragmentConstants:Float32Array;
	@:noCompletion private var __frontBufferTexture:RectangleTexture;
	@:noCompletion private var __positionScale:Float32Array; // TODO: Better approach?
	@:noCompletion private var __present:Bool;
	@:noCompletion private var __programs:Map<String, Program3D>;
	@:noCompletion private var __quadIndexBuffer:IndexBuffer3D;
	@:noCompletion private var __quadIndexBufferCount:Int;
	@:noCompletion private var __quadIndexBufferElements:Int;
	@:noCompletion private var __stage:Stage;
	@:noCompletion private var __stage3D:Stage3D;
	@:noCompletion private var __state:Context3DState;
	@:noCompletion private var __vertexConstants:Float32Array;
	@:noCompletion private var __usingComplexBlend:Bool;

	@:noCompletion private function new(stage:Stage, contextState:Context3DState = null, stage3D:Stage3D = null)
	{
		super();

		__stage = stage;
		__contextState = contextState;
		__stage3D = stage3D;

		__context = stage.window.context;
		#if (js && html5 && dom)
		gl = GL.context;
		#elseif (js && html5)
		gl = __context.webgl;
		#end

		if (__contextState == null) __contextState = new Context3DState();
		__state = new Context3DState();

		#if lime
		__vertexConstants = new Float32Array(4 * 128);
		__fragmentConstants = new Float32Array(4 * 128);
		__positionScale = new Float32Array([1.0, 1.0, 1.0, 1.0]);
		#end
		__programs = new Map<String, Program3D>();

		if (__glMaxViewportDims == -1)
		{
			#if (js && html5)
			__glMaxViewportDims = gl.getParameter(gl.MAX_VIEWPORT_DIMS);
			#else
			__glMaxViewportDims = 16384;
			#end
		}

		maxBackBufferWidth = __glMaxViewportDims;
		maxBackBufferHeight = __glMaxViewportDims;

		#if (lime && !js)
		if (__driverInfo == null)
		{
			__driverInfo = "BGFX (renderer type " + (BGFX.rendererType : Int) + ")";
		}

		driverInfo = __driverInfo;
		#else
		if (__glMaxTextureMaxAnisotropy == -1)
		{
			var extension:Dynamic = gl.getExtension("EXT_texture_filter_anisotropic");

			#if (js && html5)
			if (extension == null
				|| !Reflect.hasField(extension, "MAX_TEXTURE_MAX_ANISOTROPY_EXT")) extension = gl.getExtension("MOZ_EXT_texture_filter_anisotropic");
			if (extension == null
				|| !Reflect.hasField(extension, "MAX_TEXTURE_MAX_ANISOTROPY_EXT")) extension = gl.getExtension("WEBKIT_EXT_texture_filter_anisotropic");
			#end

			if (extension != null)
			{
				__glTextureMaxAnisotropy = extension.TEXTURE_MAX_ANISOTROPY_EXT;
				__glMaxTextureMaxAnisotropy = gl.getParameter(extension.MAX_TEXTURE_MAX_ANISOTROPY_EXT);
			}
			else
			{
				__glTextureMaxAnisotropy = 0;
				__glMaxTextureMaxAnisotropy = 0;
			}
		}

		#if (js && html5)
		if (__glDepthStencil == -1)
		{
			__glDepthStencil = gl.DEPTH_STENCIL;
		}
		#end

		if (__glMemoryTotalAvailable == -1)
		{
			var extension = gl.getExtension("NVX_gpu_memory_info");
			if (extension != null)
			{
				__glMemoryTotalAvailable = extension.GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX;
				__glMemoryCurrentAvailable = extension.GPU_MEMORY_INFO_CURRENT_AVAILABLE_VIDMEM_NVX;
			}
		}

		if (__driverInfo == null)
		{
			var vendor = gl.getParameter(gl.VENDOR);
			var version = gl.getParameter(gl.VERSION);
			var renderer = gl.getParameter(gl.RENDERER);
			var glslVersion = gl.getParameter(gl.SHADING_LANGUAGE_VERSION);

			__driverInfo = "OpenGL Vendor=" + vendor + " Version=" + version + " Renderer=" + renderer + " GLSL=" + glslVersion;
		}

		driverInfo = __driverInfo;
		#end

		__quadIndexBufferElements = Math.floor(0xFFFF / 4);
		__quadIndexBufferCount = __quadIndexBufferElements * 6;

		#if lime
		var data = new UInt16Array(__quadIndexBufferCount);

		var index:UInt = 0;
		var vertex:UInt = 0;

		for (i in 0...__quadIndexBufferElements)
		{
			data[index] = vertex;
			data[index + 1] = vertex + 1;
			data[index + 2] = vertex + 2;
			data[index + 3] = vertex + 2;
			data[index + 4] = vertex + 1;
			data[index + 5] = vertex + 3;

			index += 6;
			vertex += 4;
		}

		__quadIndexBuffer = createIndexBuffer(__quadIndexBufferCount);
		__quadIndexBuffer.uploadFromTypedArray(data);
		#end
	}

	/**
		Clears the color, depth, and stencil buffers associated with this Context3D
		object and fills them with the specified values.

		Set the `mask` parameter to specify which buffers to clear. Use the constants
		defined in the Context3DClearMask class to set the `mask` parameter. Use the
		bitwise OR operator, "|", to add multiple buffers to the mask (or use
		Context3DClearMask.ALL). When rendering to the back buffer, the
		`configureBackBuffer()` method must be called before any `clear()` calls.

		**Note:** If you specify a parameter value outside the allowed range, Numeric
		parameter values are silently clamped to the range zero to one. Likewise, if
		stencil is greater than 0xff it is set to 0xff.

		@param	red	the red component of the color with which to clear the color buffer,
		in the range zero to one.
		@param	green	the green component of the color with which to clear the color
		buffer, in the range zero to one.
		@param	blue	the blue component of the color with which to clear the color
		buffer, in the range zero to one.
		@param	alpha	the alpha component of the color with which to clear the color
		buffer, in the range zero to one. The alpha component is not used for blending.
		It is written to the buffer alpha directly.
		@param	depth	the value with which to clear the depth buffer, in the range
		zero to one.
		@param	stencil	the 8-bit value with which to clear the stencil buffer, in a
		range of 0x00 to 0xff.
		@param	mask	specifies which buffers to clear.
		@throws	Error	Object Disposed: If this Context3D object has been disposed by a calling
		dispose() or because the underlying rendering hardware has been lost.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function clear(red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1, stencil:UInt = 0,
			mask:UInt = Context3DClearMask.ALL):Void
	{
		__clear(false, red, green, blue, alpha, depth, stencil, mask);
	}

	@:noCompletion private function __clear(useScissor:Bool, red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1,
			stencil:UInt = 0, mask:UInt = Context3DClearMask.ALL)
	{
		#if (lime && !js)
		var clearFlags = 0;

		if (mask & Context3DClearMask.COLOR != 0)
		{
			if (__state.renderToTexture == null)
			{
				if (__stage.context3D == this && !__stage.__renderer.__cleared) __stage.__renderer.__cleared = true;
				__cleared = true;
			}

			clearFlags |= BGFX.CLEAR_COLOR;
		}

		if (mask & Context3DClearMask.DEPTH != 0) clearFlags |= BGFX.CLEAR_DEPTH;
		if (mask & Context3DClearMask.STENCIL != 0) clearFlags |= BGFX.CLEAR_STENCIL;

		if (clearFlags == 0) return;

		var clearColor = (Std.int(red * 255) << 24) | (Std.int(green * 255) << 16) | (Std.int(blue * 255) << 8) | Std.int(alpha * 255);

		// clears always allocate a fresh view (view-level operation in bgfx)
		__bgfxViewValid = false;
		__bgfxEnsureView(clearFlags, clearColor, depth, stencil, useScissor);
		return;
		#end

		__flushGLFramebuffer();
		__flushGLViewport();

		var clearMask = 0;

		if (mask & Context3DClearMask.COLOR != 0)
		{
			if (__state.renderToTexture == null)
			{
				if (__stage.context3D == this && !__stage.__renderer.__cleared) __stage.__renderer.__cleared = true;
				__cleared = true;
			}

			clearMask |= gl.COLOR_BUFFER_BIT;

			if (#if openfl_disable_context_cache true #else __contextState.colorMaskRed != true
				|| __contextState.colorMaskGreen != true
				|| __contextState.colorMaskBlue != true
				|| __contextState.colorMaskAlpha != true #end)
			{
				gl.colorMask(true, true, true, true);
				__contextState.colorMaskRed = true;
				__contextState.colorMaskGreen = true;
				__contextState.colorMaskBlue = true;
				__contextState.colorMaskAlpha = true;
			}

			gl.clearColor(red, green, blue, alpha);
		}

		if (mask & Context3DClearMask.DEPTH != 0)
		{
			clearMask |= gl.DEPTH_BUFFER_BIT;

			if (#if openfl_disable_context_cache true #else __contextState.depthMask != true #end)
			{
				gl.depthMask(true);
				__contextState.depthMask = true;
			}

			gl.clearDepth(depth);
		}

		if (mask & Context3DClearMask.STENCIL != 0)
		{
			clearMask |= gl.STENCIL_BUFFER_BIT;

			if (#if openfl_disable_context_cache true #else __contextState.stencilWriteMask != 0xFF #end)
			{
				gl.stencilMask(0xFF);
				__contextState.stencilWriteMask = 0xFF;
			}

			gl.clearStencil(stencil);
			__contextState.stencilWriteMask = 0xFF;
		}

		if (clearMask == 0) return;

		if (useScissor)
		{
			__flushGLScissor();
		}
		else
		{
			__setGLScissorTest(false);
		}

		gl.clear(clearMask);
	}

	/**
		Sets the viewport dimensions and other attributes of the rendering buffer.

		Rendering is double-buffered. The back buffer is swapped with the visible,
		front buffer when the `present()` method is called. The minimum size of the
		buffer is 32x32 pixels. The maximum size of the back buffer is limited by the
		device capabilities and can also be set by the user through the properties
		`maxBackBufferWidth` and `maxBackBufferHeight`. Configuring the buffer is a
		slow operation. Avoid changing the buffer size or attributes during normal
		rendering operations.

		@param	width	width in pixels of the buffer.
		@param	height	height in pixels of the buffer.
		@param	antiAlias	an integer value specifying the requested antialiasing
		quality. The value correlates to the number of subsamples used when
		antialiasing. Using more subsamples requires more calculations to be performed,
		although the relative performance impact depends on the specific rendering
		hardware. The type of antialiasing and whether antialiasing is performed at all is
		dependent on the device and rendering mode. Antialiasing is not supported at all by
		the software rendering context.
		| --- | --- |
		| 0 | No antialiasing |
		| 2 | Minimal antialiasing |
		| 4 | High-quality antialiasing |
		| 16 | Very high-quality antialiasing |
		@param	enableDepthAndStencil	`false` indicates no depth or stencil buffer is
		created, `true` creates a depth and a stencil buffer. For an AIR 3.2 or later
		application compiled with SWF version 15 or higher, if the `renderMode` element in
		the application descriptor file is `direct`, then the `depthAndStencil` element in
		the application descriptor file must have the same value as this argument. By
		default, the value of the `depthAndStencil` element is `false`.
		@param	wantsBestResolution	`true` indicates that if the device supports HiDPI
		screens it will attempt to allocate a larger back buffer than indicated with the
		`width` and `height` parameters. Since this add more pixels and potentially changes
		the result of shader operations this is turned off by default. Use
		`Stage.contentsScaleFactor` to determine by how much the native back buffer was
		scaled up.
		@param	wantsBestResolutionOnBrowserZoom	`true` indicates that the size of the
		back buffer should increase in proportion to the increase in the browser zoom
		factor. The setting of this value is persistent across multiple browser zooms.
		The default value of the parameter is `false`. Set `maxBackBufferWidth` and
		`maxBackBufferHeight` properties to limit the back buffer size increase. Use
		`backBufferWidth` and `backBufferHeight` to determine the current size of the
		back buffer.
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	Bad Input Size: The `width` or `height` parameter is either less
		than the minimum back buffer allowed size or greater than the maximum back buffer
		size allowed.
		@throws	Error	3709: The `depthAndStencil` flag in the application descriptor
		must match the `enableDepthAndStencil` Boolean passed to `configureBackBuffer()`
		on the Context3D object.
	**/
	public function configureBackBuffer(width:Int, height:Int, antiAlias:Int, enableDepthAndStencil:Bool = true, wantsBestResolution:Bool = false,
			wantsBestResolutionOnBrowserZoom:Bool = false):Void
	{
		#if !openfl_dpi_aware
		if (wantsBestResolution)
		{
			width = Std.int(width * __stage.window.scale);
			height = Std.int(height * __stage.window.scale);
		}
		#end

		if (__stage3D == null)
		{
			backBufferWidth = width;
			backBufferHeight = height;

			__backBufferAntiAlias = antiAlias;
			__state.backBufferEnableDepthAndStencil = enableDepthAndStencil;
			__backBufferWantsBestResolution = wantsBestResolution;
			__backBufferWantsBestResolutionOnBrowserZoom = wantsBestResolutionOnBrowserZoom;

			#if (lime && !js)
			var scaledWidth = width;
			var scaledHeight = height;
			#if !openfl_dpi_aware
			if (!wantsBestResolution)
			{
				scaledWidth = Std.int(width * __stage.window.scale);
				scaledHeight = Std.int(height * __stage.window.scale);
			}
			#end
			__bgfxEnsureMainTarget(scaledWidth, scaledHeight);
			#end
		}
		else
		{
			if (__backBufferTexture == null || backBufferWidth != width || backBufferHeight != height)
			{
				if (__backBufferTexture != null) __backBufferTexture.dispose();
				if (__frontBufferTexture != null) __frontBufferTexture.dispose();

				__backBufferTexture = createRectangleTexture(width, height, BGRA, true);
				__frontBufferTexture = createRectangleTexture(width, height, BGRA, true);

				if (__stage3D.__vertexBuffer == null)
				{
					__stage3D.__vertexBuffer = createVertexBuffer(4, 5);
				}

				#if openfl_dpi_aware
				var scaledWidth = width;
				var scaledHeight = height;
				#else
				var scaledWidth = wantsBestResolution ? width : Std.int(width * __stage.window.scale);
				var scaledHeight = wantsBestResolution ? height : Std.int(height * __stage.window.scale);
				#end
				var vertexData:Array<Float> = [
					scaledWidth,
					scaledHeight,
					0.0,
					1.0,
					1.0,
					0.0,
					scaledHeight,
					0.0,
					0.0,
					1.0,
					scaledWidth,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					0.0,
					0.0,
					0.0
				];

				__stage3D.__vertexBuffer.uploadFromArray(vertexData, 0, 20);

				if (__stage3D.__indexBuffer == null)
				{
					__stage3D.__indexBuffer = createIndexBuffer(6);

					var indexData:Array<UInt> = [0, 1, 2, 2, 1, 3];

					__stage3D.__indexBuffer.uploadFromArray(indexData, 0, 6);
				}
			}

			backBufferWidth = width;
			backBufferHeight = height;

			__backBufferAntiAlias = antiAlias;
			__state.backBufferEnableDepthAndStencil = enableDepthAndStencil;
			__backBufferWantsBestResolution = wantsBestResolution;
			__backBufferWantsBestResolutionOnBrowserZoom = wantsBestResolutionOnBrowserZoom;
			#if (lime && !js)
			__state.__bgfxPrimaryFrameBuffer = __backBufferTexture.__getBGFXFrameBuffer(enableDepthAndStencil, antiAlias, 0);
			__frontBufferTexture.__getBGFXFrameBuffer(enableDepthAndStencil, antiAlias, 0);
			#else
			__state.__primaryGLFramebuffer = __backBufferTexture.__getGLFramebuffer(enableDepthAndStencil, antiAlias, 0);
			__frontBufferTexture.__getGLFramebuffer(enableDepthAndStencil, antiAlias, 0);
			#end
		}
	}

	/**
		Creates a CubeTexture object.

		Use a CubeTexture object to upload cube texture bitmaps to the rendering context
		and to reference a cube texture during rendering. A cube texture consists of six
		equal-sized, square textures arranged in a cubic topology and are useful for
		describing environment maps.

		You cannot create CubeTexture objects with a CubeTexture constructor; use this
		method instead. After creating a CubeTexture object, upload the texture bitmap
		data using the CubeTexture `uploadFromBitmapData()`, `uploadFromByteArray()`, or
		`uploadCompressedTextureFromByteArray()` methods.

		@param size	The texture edge length in texels.
		@param format	The texel format, of the Context3DTextureFormat enumerated list.
		Texture compression lets you store texture images in compressed format directly on
		the GPU, which saves GPU memory and memory bandwidth. Typically, compressed
		textures are compressed offline and uploaded to the GPU in compressed form
		using the `Texture.uploadCompressedTextureFromByteArray` method. Flash Player 11.4
		and AIR 3.4 on desktop platforms added support for runtime texture compression,
		which may be useful in certain situations, such as when rendering dynamic
		textures from vector art. Note that this feature is not currently available on
		mobile platforms and an ArgumentError (Texture Format Mismatch) will be thrown
		instead. To use runtime texture compression, perform the following steps:
		1. Create the texture object by calling the `Context3D.createCubeTexture()`
		method, passing either `openfl.display3D.Context3DTextureFormat.COMPRESSED` or
		`openfl.display3D.Context3DTextureFormat.COMPRESSED_ALPHA` as the format
		parameter.
		2. Using the openfl.display3D.textures.Texture instance returned by
		`createCubeTexture()`, call either
		`openfl.display3D.textures.CubeTexture.uploadFromBitmapData()` or
		`openfl.display3D.textures.CubeTexture.uploadFromByteArray()` to upload and
		compress the texture in one step.
		@param optimizeForRenderToTexture	Set to true if the texture is likely to be
		used as a render target.
		@param streamingLevels	The MIP map level that must be loaded before the image
		is rendered. Texture streaming offers the ability to load and display the
		smallest mip levels first, progressively displaying higher quality images as the
		textures are loaded. End users can view lower-quality images in an application
		while the higher quality images load.

		By default, streamingLevels is 0, meaning that the highest quality image in the
		MIP map must be loaded before the image is rendered. This parameter was added in
		Flash Player 11.3 and AIR 3.3. Using the default value maintains the behavior of
		the previous versions of Flash Player and AIR.

		Set streamingLevels to a value between 1 and the number of images in the MIP map
		to enable texture streaming. For example, you have a MIP map that includes at the
		highest quality a main image at 64x64 pixels. Lower quality images in the MIP map
		are 32x32, 16x16, 8x8, 4x4, 2x2, and 1x1 pixels, for 7 images in total, or 7
		levels. Level 0 is the highest quality image. The maximum value of this property
		is log2(min(width,height)). Therefore, for a main image that is 64x64 pixels, the
		maximum value of streamingLevels is 7. Set this property to 3 to render the image
		after the 8x8 pixel image loads.

		**Note:** Setting this property to a value > 0 can impact memory usage and
		performance.

		@return	A new CubeTexture object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	Resource Limit Exceeded: if too many Texture objects are created
		or the amount of memory allocated to textures is exceeded.
		@throws	ArgumentError	Depth Texture Not Implemented: if you attempt to create
		a depth texture.
		@throws	ArgumentError	Texture Size Is Zero: if the size parameter is not greater
		than zero.
		@throws	ArgumentError	Texture Not Power Of Two: if the size parameter is not a
		power of two.
		@throws	ArgumentError	Texture Too Big: if the size parameter is greater than
		1024.
		@throws	Error	Texture Creation Failed: if the CubeTexture object could not be
		created by the rendering context (but information about the reason is not
		available).
		@throws	ArgumentError	Invalid streaming level: if streamingLevels is greater or
		equal to `log2(size)`.
	**/
	public function createCubeTexture(size:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int = 0):CubeTexture
	{
		return new CubeTexture(this, size, format, optimizeForRenderToTexture, streamingLevels);
	}

	/**
		Creates an IndexBuffer3D object.

		Use an IndexBuffer3D object to upload a set of triangle indices to the rendering
		context and to reference that set of indices for rendering. Each index in the
		index buffer references a corresponding vertex in a vertex buffer. Each set of
		three indices identifies a triangle. Pass the IndexBuffer3D object to the
		`drawTriangles()` method to render one or more triangles defined in the index
		buffer.

		You cannot create IndexBuffer3D objects with the IndexBuffer3D class constructor;
		use this method instead. After creating a IndexBuffer3D object, upload the
		indices using the IndexBuffer3D `uploadFromVector()` or `uploadFromByteArray()`
		methods.

		@param	numIndices	the number of vertices to be stored in the buffer.
		@param	bufferUsage	the expected buffer usage. Use one of the constants defined
		in Context3DBufferUsage. The hardware driver can do appropriate optimization
		when you set it correctly. This parameter is only available after Flash 12/AIR 4.
		@return	A new IndexBuffer3D object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	Resource Limit Exceeded: if too many index buffers are created
		or the amount of memory allocated to index buffers is exceeded.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
		@throws	ArgumentError	Buffer Too Big: when `numIndices` is greater than or equal
		to 0xf0000.
	**/
	public function createIndexBuffer(numIndices:Int, bufferUsage:Context3DBufferUsage = STATIC_DRAW):IndexBuffer3D
	{
		return new IndexBuffer3D(this, numIndices, bufferUsage);
	}

	/**
		Creates a Program3D object.

		Use a Program3D object to upload shader programs to the rendering context and
		to reference uploaded programs during rendering. A Program3D object stores
		two programs, a vertex program and a fragment program (also known as a pixel
		program). The programs are written in a binary shader assembly language.

		You cannot create Program3D objects with a Program3D constructor; use this method
		instead. After creating a Program3D object, upload the programs using the
		Program3D `upload()` method.

		@param	format	(Experimental) Set the format of this Program3D instance to AGAL
		(default) or to GLSL for use on GL-based renderers
		@return	A new Program3D object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	The number of programs exceeds 4096 or the total memory size
		exceeds 16MB (use dispose to free Program3D resources).
	**/
	public function createProgram(format:Context3DProgramFormat = AGAL):Program3D
	{
		return new Program3D(this, format);
	}

	/**
		Creates a Rectangle Texture object.

		Use a RectangleTexture object to upload texture bitmaps to the rendering context
		and to reference a texture during rendering.

		You cannot create RectangleTexture objects with a RectangleTexture constructor;
		use this method instead. After creating a RectangleTexture object, upload the
		texture bitmaps using the Texture `uploadFromBitmapData()` or
		`uploadFromByteArray()` methods.

		Note that 32-bit integer textures are stored in a packed BGRA format to match
		the OpenFL BitmapData format. Floating point textures use a conventional RGBA
		format.

		Rectangle textures are different from regular 2D textures in that their width and
		height do not have to be powers of two. Also, they do not contain mip maps.
		They are most useful for use in render to texture cases. If a rectangle texture
		is used with a sampler that uses mip map filtering or repeat wrapping the
		drawTriangles call will fail. Rectangle texture also do not allow streaming. The
		only texture formats supported by Rectangle textures are BGRA, BGR_PACKED,
		BGRA_PACKED. The compressed texture formats are not supported by Rectangle
		Textures.

		@param	width	The texture width in texels.
		@param	height	The texture height in texels.
		@param	format	The texel format, of the Context3DTextureFormat enumerated list.
		@param	optimizeForRenderToTexture	Set to true if the texture is likely to be
		used as a render target.
		@return	A new RectangleTexture object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling dispose() or because the underlying rendering hardware has been lost.
		@throws	Error	Resource Limit Exceeded: if too many Texture objects are created
		or the amount of memory allocated to textures is exceeded.
		@throws	ArgumentError	Texture Size Is Zero: if both the width or height
		parameters are not greater than zero.
		@throws	ArgumentError	Texture Too Big: if either the width or the height
		parameter is greater than 2048.
		@throws	Error	Texture Creation Failed: if the Texture object could not be
		created by the rendering context (but information about the reason is not
		available).
		@throws	Error	Requires Baseline Profile Or Above: if rectangular texture is
		created with baseline constrained profile.
	**/
	public function createRectangleTexture(width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool):RectangleTexture
	{
		return new RectangleTexture(this, width, height, format, optimizeForRenderToTexture);
	}

	/**
		Creates a Texture object.

		Use a Texture object to upload texture bitmaps to the rendering context and to
		reference a texture during rendering.

		You cannot create Texture objects with a Texture constructor; use this method
		instead. After creating a Texture object, upload the texture bitmaps using the
		Texture `uploadFromBitmapData()`, `uploadFromByteArray()`, or
		`uploadCompressedTextureFromByteArray()` methods.

		Note that 32-bit integer textures are stored in a packed BGRA format to match
		the OpenFL BitmapData format. Floating point textures use a conventional RGBA
		format.

		@param	width	The texture width in texels.
		@param	height	The texture height in texels.
		@param	format	The texel format, of the Context3DTextureFormat enumerated list.
		Texture compression lets you store texture images in compressed format directly
		on the GPU, which saves GPU memory and memory bandwidth. Typically, compressed
		textures are compressed offline and uploaded to the GPU in compressed form using
		the Texture.uploadCompressedTextureFromByteArray method. Flash Player 11.4 and
		AIR 3.4 on desktop platforms added support for runtime texture compression, which
		may be useful in certain situations, such as when rendering dynamic textures from
		vector art. Note that this feature is not currently available on mobile platforms
		and an ArgumentError (Texture Format Mismatch) will be thrown instead. To use
		runtime texture compression, perform the following steps:
		1. Create the texture object by calling the `Context3D.createTexture()` method,
		passing either `openfl.display3D.Context3DTextureFormat.COMPRESSED` or
		`openfl.display3D.Context3DTextureFormat.COMPRESSED_ALPHA` as the format
		parameter.
		2. Using the openfl.display3D.textures.Texture instance returned by
		`createTexture()`, call either
		`openfl.display3D.textures.Texture.uploadFromBitmapData()` or
		`openfl.display3D.textures.Texture.uploadFromByteArray()` to upload and compress
		the texture in one step.
		@param	optimizeForRenderToTexture	Set to true if the texture is likely to be
		used as a render target.
		@param	streamingLevels	The MIP map level that must be loaded before the image is
		rendered. Texture streaming offers the ability to load and display the smallest
		mip levels first, progressively displaying higher quality images as the textures
		are loaded. End users can view lower-quality images in an application while the
		higher quality images load.

		By default, streamingLevels is 0, meaning that the highest quality image in the
		MIP map must be loaded before the image is rendered. This parameter was added in
		Flash Player 11.3 and AIR 3.3. Using the default value maintains the behavior of
		the previous versions of Flash Player and AIR.

		Set `streamingLevels` to a value between 1 and the number of images in the MIP map
		to enable texture streaming. For example, you have a MIP map that includes at
		the highest quality a main image at 64x64 pixels. Lower quality images in the
		MIP map are 32x32, 16x16, 8x8, 4x4, 2x2, and 1x1 pixels, for 7 images in total,
		or 7 levels. Level 0 is the highest quality image. The maximum value of this
		property is log2(min(width,height)). Therefore, for a main image that is
		64x64 pixels, the maximum value of streamingLevels is 7. Set this property to
		3 to render the image after the 8x8 pixel image loads.

		**Note:** Setting this property to a value > 0 can impact memory usage and
		performance.

		@return	A new Texture object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a calling dispose() or because the underlying rendering hardware has been lost.
		@throws	Error	Resource Limit Exceeded: if too many Texture objects are created or the amount of memory allocated to textures is exceeded.
		@throws	ArgumentError	Depth Texture Not Implemented: if you attempt to create a depth texture.
		@throws	ArgumentError	Texture Size Is Zero: if both the width or height parameters are not greater than zero.
		@throws	ArgumentError	Texture Not Power Of Two: if both the width and height parameters are not a power of two.
		@throws	ArgumentError	Texture Too Big: if either the width or the height parameter is greater than 2048 for baseline and baseline constrained profile or if either the width or the height parameter is greater than 4096 for profile baseline extended and above.
		@throws	Error	Texture Creation Failed: if the Texture object could not be created by the rendering context (but information about the reason is not available).
		@throws	ArgumentError	Invalid streaming level: if streamingLevels is greater or equal to log2(min(width,height)).
	**/
	public function createTexture(width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int = 0):Texture
	{
		return new Texture(this, width, height, format, optimizeForRenderToTexture, streamingLevels);
	}

	public function createASTCTexture(data:ByteArray, isSRGB:Bool = false, isHDR:Bool = false):ASTCTexture
	{
		return new ASTCTexture(this, data, isSRGB, isHDR);
	}

	public function createBCTexture(data:ByteArray):BCTexture
	{
		return new BCTexture(this, data);
	}

	/**
		Creates a VertexBuffer3D object.

		Use a VertexBuffer3D object to upload a set of vertex data to the rendering
		context. A vertex buffer contains the data needed to render each point in the
		scene geometry. The data attributes associated with each vertex typically
		includes position, color, and texture coordinates and serve as the input to
		the vertex shader program. Identify the data values that correspond to one of
		the inputs of the vertex program using the `setVertexBufferAt()` method. You can
		specify up to sixty-four 32-bit values for each vertex.

		You cannot create VertexBuffer3D objects with a VertexBuffer3D constructor; use
		this method instead. After creating a VertexBuffer3D object, upload the vertex
		data using the VertexBuffer3D `uploadFromVector()` or `uploadFromByteArray()`
		methods.

		@param	numVertices	the number of vertices to be stored in the buffer. The
		maximum number of vertices in a single buffer is 65535.
		@param	data32PerVertex	the number of 32-bit(4-byte) data values associated
		with each vertex. The maximum number of 32-bit data elements per vertex is 64
		(or 256 bytes). Note that only eight attribute registers are accessible by a
		vertex shader program at any given time. Use `setVertextBufferAt()` to select
		attributes from within a vertex buffer.
		@param	bufferUsage	the expected buffer usage. Use one of the constants defined
		in Context3DBufferUsage. The hardware driver can do appropriate optimization when
		you set it correctly. This parameter is only available after Flash 12/AIR 4
		@return	A new VertexBuffer3D object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	Resource Limit Exceeded: if too many vertex buffer objects are
		created or the amount of memory alloted to vertex buffers is exceeded.
		@throws	ArgumentError	Buffer Too Big: when `numVertices` is greater than 0x10000
		or `data32PerVertex` is greater than 64.
		@throws	ArgumentError	Buffer Has Zero Size: when `numVertices` is zero or
		`data32PerVertex` is zero.
		@throws	ArgumentError	Buffer Creation Failed: if the VertexBuffer3D object
		could not be created by the rendering context (but additional information about
		the reason is not available).
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function createVertexBuffer(numVertices:Int, data32PerVertex:Int, bufferUsage:Context3DBufferUsage = STATIC_DRAW):VertexBuffer3D
	{
		return new VertexBuffer3D(this, numVertices, data32PerVertex, bufferUsage);
	}

	/**
		Creates a VideoTexture object.

		Use a VideoTexture object to obtain video frames as texture from NetStream object
		or Camera object and to upload the video frames to the rendering context.

		The VideoTexture object cannot be created with the VideoTexture constructor; use
		this method instead. After creating a VideoTexture object, attach NetStream
		object or Camera Object to get the video frames with the VideoTexture
		`attachNetStream()` or `attachCamera()` methods.

		Note that this method returns null if the system doesn't support this feature.

		VideoTexture does not contain mipmaps. If VideoTexture is used with a sampler
		that uses mip map filtering or repeat wrapping, the drawTriangles call will fail.
		VideoTexture can be treated as BGRA texture by the shaders. The attempt to
		instantiate the VideoTexture Object will fail if the Context3D was requested
		with sotfware rendering mode.

		A maximum of 4 VideoTexture objects are available per Context3D instance. On
		mobile the actual number of supported VideoTexture objects may be less than 4
		due to platform limitations.

		@return	A new VideoTexture object
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	Resource Limit Exceeded: if too many Texture objects are created
		or the amount of memory allocated to textures is exceeded.
		@throws	Error	Texture Creation Failed: if the Texture object could not be
		created by the rendering context (but information about the reason is not
		available).
	**/
	public function createVideoTexture():VideoTexture
	{
		#if (js && html5)
		return new VideoTexture(this);
		#else
		throw new Error("Video textures are not supported on this platform");
		return null;
		#end
	}

	/**
		Frees all resources and internal storage associated with this Context3D.

		All index buffers, vertex buffers, textures, and programs that were created
		through this Context3D are disposed just as if calling `dispose()` on each of
		them individually. In addition, the Context3D itself is disposed freeing all
		temporary buffers and the back buffer. If you call `configureBackBuffer()`,
		`clear()`, `drawTriangles()`, `createCubeTexture()`, `createTexture()`,
		`createProgram()`, `createIndexBuffer()`, `createVertexBuffer()`, or
		`drawToBitmapData()` after calling `dispose()`, the runtime throws an exception.

		Warning: calling `dispose()` on a Context3D while there is still a event
		listener for `Events.CONTEXT3D_CREATE` set on the asociated Stage3D object the
		`dispose()` call will simulate a device loss. It will create a new Context3D on
		the Stage3D and issue the `Events.CONTEXT3D_CREATE` event again. If this is not
		desired remove the event listener from the Stage3D object before calling
		`dispose()` or set the `recreate` parameter to `false`.

		@param	recreate	Whether to allow this Stage3D object to create itself again
	**/
	public function dispose(recreate:Bool = true):Void
	{
		// TODO: Dispose all related buffers

		gl = null;
		__dispose();
	}

	/**
		Draws the current render buffer to a bitmap.

		The current contents of the back render buffer are copied to a BitmapData
		object. This is potentially a very slow operation that can take up to a second.
		Use with care. Note that this function does not copy the front render buffer
		(the one shown on stage), but the buffer being drawn to. To capture the rendered
		image as it appears on the stage, call `drawToBitmapData()` immediately before you
		calling `present()`.

		Beginning with AIR 25, two new parameters have been introduced in the API
		`drawToBitmapData()`. This API now takes three parameters. The first one is the
		existing parameter `destination:BitmapData`. The second parameter is
		`srcRect:Rectangle`, which is target rectangle on Stage3D. The third parameter is
		`destPoint:Point`, which is the coordinate on the destination bitmap. The
		parameters `srcRect` and `destPoint` are optional and default to
		`(0,0,bitmapWidth,bitmapHeight)` and `(0,0)`, respectively.

		When the image is drawn, it is not scaled to fit the bitmap. Instead, the
		contents are clipped to the size of the destination bitmap.

		OpenFL BitmapData objects store colors already multiplied by the alpha component.
		For example, if the "pure" rgb color components of a pixel are (0x0A, 0x12, 0xBB)
		and the alpha component is 0x7F (.5), then the pixel is stored in the
		BitmapData object with the rgba values: (0x05, 0x09, 0x5D, 0x7F). You can set the
		blend factors so that the colors rendered to the buffer are multiplied by alpha
		or perform the operation in the fragment shader. The rendering context does not
		validate that the colors are stored in premultiplied format.

		@param	destination	The target BitmapData for this drawing operation
		@param	srcRect	The source rectangle in the current Stage3D context
		@param	destPoint A destination point to write to in the target BitmapData
		@throws	Error	Object Disposed: if this Context3D object has been disposed by
		a calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
		@throws	Error	3802: If either one of the parameters `destPoint:Point` or
		`srcRect:Rectangle` is outside the bitmap/stage3D coordinate bound, or if
		non-numeric(NaN) values are passed as input.
	**/
	public function drawToBitmapData(destination:BitmapData, srcRect:Rectangle = null, destPoint:Point = null):Void
	{
		#if lime
		if (destination == null) return;

		var sourceRect = srcRect != null ? srcRect.__toLimeRectangle() : new LimeRectangle(0, 0, backBufferWidth, backBufferHeight);
		var destVector = destPoint != null ? destPoint.__toLimeVector2() : new Vector2();

		if (__stage.context3D == this)
		{
			if (__stage.window != null)
			{
				if (__stage3D != null)
				{
					destVector.setTo(Std.int(-__stage3D.x), Std.int(-__stage3D.y));
				}

				var image = __stage.window.readPixels();
				destination.image.copyPixels(image, sourceRect, destVector);
			}
		}
		else if (__backBufferTexture != null)
		{
			var cacheRenderToTexture = __state.renderToTexture;
			setRenderToBackBuffer();

			__flushGLFramebuffer();
			__flushGLViewport();

			// TODO: Read less pixels if srcRect is smaller

			var data = new UInt8Array(backBufferWidth * backBufferHeight * 4);
			gl.readPixels(0, 0, backBufferWidth, backBufferHeight, __backBufferTexture.__format, gl.UNSIGNED_BYTE, data);

			var image = new Image(new ImageBuffer(data, backBufferWidth, backBufferHeight, 32, BGRA32));
			destination.image.copyPixels(image, sourceRect, destVector);

			if (cacheRenderToTexture != null)
			{
				setRenderToTexture(cacheRenderToTexture, __state.renderToTextureDepthStencil, __state.renderToTextureAntiAlias,
					__state.renderToTextureSurfaceSelector);
			}
		}
		#end
	}

	/**
		Render the specified triangles using the current buffers and state of this
		Context3D object.

		For each triangle, the triangle vertices are processed by the vertex shader
		program and the triangle surface is processed by the pixel shader program. The
		output color from the pixel program for each pixel is drawn to the render
		target depending on the stencil operations, depth test, source and destination
		alpha, and the current blend mode. The render destination can be the main render
		buffer or a texture.

		If culling is enabled, (with the `setCulling()` method), then triangles can be
		discarded from the scene before the pixel program is run. If stencil and depth
		testing are enabled, then output pixels from the pixel program can be discarded
		without updating the render destination. In addition, the pixel program can
		decide not to output a color for a pixel.

		The rendered triangles are not displayed in the viewport until you call the
		`present()` method. After each `present()` call, the `clear()` method must be
		called before the first `drawTriangles()` call or rendering fails.

		When `enableErrorChecking` is `false`, this function returns immediately, does
		not wait for results, and throws exceptions only if this Context3D instance has
		been disposed or there are too many draw calls. If the rendering context state
		is invalid rendering fails silently. When the `enableErrorChecking` property is
		`true`, this function returns after the triangles are drawn and throws exceptions
		for any drawing errors or invalid context state.

		@param	indexBuffer:IndexBuffer3D — a set of vertex indices referencing the
		vertices to render.
		@param	firstIndex:int (default = 0) — the index of the first vertex index
		selected to render. Default 0.
		@param	numTriangles:int (default = -1) — the number of triangles to render.
		Each triangle consumes three indices. Pass -1 to draw all triangles in the index
		buffer. Default -1.
		@throws	Error — Object Disposed: if this Context3D object has been disposed by
		a calling `dispose()` or because the underlying rendering hardware has been lost.
		@throws	Error — If this method is called too many times between calls to
		`present()`. The maximum number of calls is 32,768.

		The following errors are only thrown when `enableErrorChecking` property is true:
		@throws	Error	Need To Clear Before Draw: If the buffer has not been cleared
		since the last `present()` call.
		@throws	Error	If a valid Program3D object is not set.
		@throws	Error	No Valid Index Buffer Set: If an IndexBuffer3D object is not set.
		@throws	Error	Sanity Check On Parameters Failed: when the number of triangles
		to be drawn or the `firstIndex` exceed allowed values.
		@throws	RangeError — Not Enough Indices In This Buffer: when there aren't enough
		indices in the buffer to define the number of triangles to be drawn.
		@throws	Error — Sample Binds Texture Also Bound To Render: when the render target
		is a texture and that texture assigned to a texture input of the current fragment
		program.
		@throws	Error — Sample Binds Invalid Texture: an invalid texture is specified as
		the input to the current fragment program.
		@throws	Error — Sampler Format Does Not Match Texture Format: when the texture
		assigned as the input to the current fragment program has a different format than
		that specified for the sampler register. For example, a 2D texture is assigned to
		a cube texture sampler.
		@throws	Error — Sample Binds Undefined Texture: The current fragment program
		accesses a texture register that has not been set (using `setTextureAt()`).
		@throws	Error — Same Texture Needs Same Sampler Params: If a texture is used for
		more than one sampler register, all of the samplers must have the same settings.
		For example, you cannot set one sampler to clamp and another to wrap.
		@throws	Error — Texture Bound But Not Used: A texture is set as a shader input,
		but it is not used.
		@throws	Error — Stream Is Not Used: A vertex buffer is assigned to a vertex
		attribute input, but the vertex program does not reference the corresponding
		register.
		@throws	Error — Stream Is Invalid: a VertexBuffer3D object assigned to a vertex
		program input is not a valid object.
		@throws	RangeError — Stream Does Not Have Enough Vertices: A vertex buffer
		supplying data for drawing the specified triangles does not have enough data.
		@throws	RangeError — Stream Vertex Offset Out Of Bounds: The offset specified in
		a `setVertexBufferAt()` call is negative or past the end of the buffer.
		@throws	Error — Stream Read But Not Set: A vertex attribute used by the current
		vertex program is not set (using `setVertexBufferAt()`).
	**/
	public function drawTriangles(indexBuffer:IndexBuffer3D, firstIndex:Int = 0, numTriangles:Int = -1):Void
	{
		#if (lime && !js)
		__bgfxDraw(indexBuffer, firstIndex, (numTriangles == -1) ? indexBuffer.__numIndices : (numTriangles * 3));
		return;
		#end

		#if !openfl_disable_display_render
		if (__state.renderToTexture == null)
		{
			// TODO: Make sure state is correct for this?
			if (__stage.context3D == this && !__stage.__renderer.__cleared)
			{
				__stage.__renderer.__clear();
			}
			else if (!__cleared)
			{
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}
		}

		__flushGL();
		#end

		if (__state.program != null)
		{
			__state.program.__flush();
		}

		var count = (numTriangles == -1) ? indexBuffer.__numIndices : (numTriangles * 3);

		__bindGLElementArrayBuffer(indexBuffer.__id);

		if (OpenGLRenderer.__coherentBlendsSupported)
		{
			gl.enable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
		else if (__usingComplexBlend)
		{
			gl.blendBarrier();
		}

		gl.drawElements(gl.TRIANGLES, count, gl.UNSIGNED_SHORT, firstIndex * 2);

		if (OpenGLRenderer.__coherentBlendsSupported)
		{
			gl.disable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
	}

	/**
		Displays the back rendering buffer.

		Calling the `present()` method makes the results of all rendering operations
		since the last `present()` call visible and starts a new rendering cycle.
		After calling `present`, you must call `clear()` before making another
		`drawTriangles()` call. Otherwise, this function will alternately clear the
		render buffer to yellow and green or, if `enableErrorChecking` has been set to
		`true`, an exception is thrown.

		Calling `present()` also resets the render target, just like calling
		`setRenderToBackBuffer()`.

		@throws	Error	Need To Clear Before Draw: If the `clear()` has not been called
		since the previous call to `present()`. (Two consecutive `present()` calls are
		not allowed without calling `clear()` in between.)
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function present():Void
	{
		setRenderToBackBuffer();

		if (__stage3D != null && __backBufferTexture != null)
		{
			if (!__cleared)
			{
				// Make sure texture is initialized
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}

			var cacheBuffer = __backBufferTexture;
			__backBufferTexture = __frontBufferTexture;
			__frontBufferTexture = cacheBuffer;

			#if (lime && !js)
			__state.__bgfxPrimaryFrameBuffer = __backBufferTexture.__getBGFXFrameBuffer(__state.backBufferEnableDepthAndStencil, __backBufferAntiAlias, 0);
			#else
			__state.__primaryGLFramebuffer = __backBufferTexture.__getGLFramebuffer(__state.backBufferEnableDepthAndStencil, __backBufferAntiAlias, 0);
			#end
			__cleared = false;
		}

		#if (lime && !js)
		// the stage's primary context owns the frame: composite the offscreen
		// main target to the backbuffer, then one bgfx frame per lime render
		// event, and the view counter starts over
		if (__stage3D == null && __stage.context3D == this)
		{
			__bgfxComposite();
			BGFX.frame();
			__bgfxNextViewId = 0;
			__bgfxDebugObjCounter = 0;

			// bgfx transient slots are frame-scoped
			__bgfxExtraSlot = -1;
			__bgfxExtraSlotKey = null;
		}

		__bgfxViewValid = false;
		__bgfxCurrentFrameBuffer = -2;
		#end

		__present = true;
	}

	/**
		Specifies the factors used to blend the output color of a drawing operation with
		the existing color.

		The output (source) color of the pixel shader program is combined with the
		existing (destination) color at that pixel according to the following formula:

		`result color = (source color * sourceFactor) + (destination color * destinationFactor)`

		The destination color is the current color in the render buffer for that pixel.
		Thus it is the result of the most recent `clear()` call and any intervening
		`drawTriangles()` calls.

		Use `setBlendFactors()` to set the factors used to multiply the source and
		destination colors before they are added together. The default blend factors
		are, `sourceFactor = Context3DBlendFactor.ONE`, and
		`destinationFactor = Context3DBlendFactor.ZERO`, which results in the source
		color overwriting the destination color (in other words, no blending of the
		two colors occurs). For normal alpha blending, use
		`sourceFactor = Context3DBlendFactor.SOURCE_ALPHA` and
		`destinationFactor = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA`.

		Use the constants defined in the Context3DBlendFactor class to set the
		parameters of this function.

		@param	sourceFactor	The factor with which to multiply the source color.
		Defaults to `Context3DBlendFactor.ONE`.
		@param	destinationFactor	The factor with which to multiply the destination
		color. Defaults to `Context3DBlendFactor.ZERO`.
		@throws	Error — Invalid Enum: when `sourceFactor` or `destinationFactor` is
		not one of the recognized values, which are defined in the
		Context3DBlendFactor class.
	**/
	public function setBlendFactors(sourceFactor:Context3DBlendFactor, destinationFactor:Context3DBlendFactor):Void
	{
		setBlendFactorsSeparate(sourceFactor, destinationFactor, sourceFactor, destinationFactor);
	}

	@:dox(hide) @:noCompletion private function setBlendFactorsSeparate(sourceRGBFactor:Context3DBlendFactor, destinationRGBFactor:Context3DBlendFactor,
			sourceAlphaFactor:Context3DBlendFactor, destinationAlphaFactor:Context3DBlendFactor):Void
	{
		__state.blendSourceRGBFactor = sourceRGBFactor;
		__state.blendDestinationRGBFactor = destinationRGBFactor;
		__state.blendSourceAlphaFactor = sourceAlphaFactor;
		__state.blendDestinationAlphaFactor = destinationAlphaFactor;

		#if (lime && !js)
		// setting blend factors resets the equation, matching the GL path
		__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_ADD_HI;
		__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_ADD_LO;
		__bgfxComplexBlend = 0;
		#else
		// TODO: Better way to handle this?
		__setGLBlendEquation(gl.FUNC_ADD);
		#end
	}

	/**
		Sets the mask used when writing colors to the render buffer.

		Only color components for which the corresponding color mask parameter is `true`
		are updated when a color is written to the render buffer. For example, if
		you call: `setColorMask(true, false, false, false)`, only the red component
		of a color is written to the buffer until you change the color mask again. The
		color mask does not affect the behavior of the `clear()` method.

		@param	red	set false to block changes to the red channel.
		@param	green	set false to block changes to the green channel.
		@param	blue	set false to block changes to the blue channel.
		@param	alpha	set false to block changes to the alpha channel.
	**/
	public function setColorMask(red:Bool, green:Bool, blue:Bool, alpha:Bool):Void
	{
		__state.colorMaskRed = red;
		__state.colorMaskGreen = green;
		__state.colorMaskBlue = blue;
		__state.colorMaskAlpha = alpha;
	}

	/**
		Sets triangle culling mode.

		Triangles may be excluded from the scene early in the rendering pipeline based
		on their orientation relative to the view plane. Specify vertex order
		consistently (clockwise or counter-clockwise) as seen from the outside of the
		model to cull correctly.

		@param	triangleFaceToCull	the culling mode. Use one of the constants defined
		in the Context3DTriangleFace class.
		@throws	Error	Invalid Enum Error: when triangleFaceToCull is not one of the
		values defined in the Context3DTriangleFace class.
	**/
	public function setCulling(triangleFaceToCull:Context3DTriangleFace):Void
	{
		__state.culling = triangleFaceToCull;
	}

	/**
		Sets type of comparison used for depth testing.

		The depth of the source pixel output from the pixel shader program is compared
		to the current value in the depth buffer. If the comparison evaluates as `false`,
		then the source pixel is discarded. If `true`, then the source pixel is processed
		by the next step in the rendering pipeline, the stencil test. In addition, the
		depth buffer is updated with the depth of the source pixel, as long as the
		`depthMask` parameter is set to `true`.

		Sets the test used to compare depth values for source and destination pixels.
		The source pixel is composited with the destination pixel when the comparison is
		`true`. The comparison operator is applied as an infix operator between the
		source and destination pixel values, in that order.

		@param	depthMask	the destination depth value will be updated from the source
		pixel when `true`.
		@param	passCompareMode	the depth comparison test operation. One of the values
		of Context3DCompareMode.
	**/
	public function setDepthTest(depthMask:Bool, passCompareMode:Context3DCompareMode):Void
	{
		__state.depthMask = depthMask;
		__state.depthCompareMode = passCompareMode;
	}

	/**
		Sets vertex and fragment shader programs to use for subsequent rendering.

		@param	program	the Program3D object representing the vertex and fragment
		programs to use.
	**/
	public function setProgram(program:Program3D):Void
	{
		__state.program = program;
		__state.shader = null; // TODO: Merge this logic

		if (program != null)
		{
			for (i in 0...program.__samplerStates.length)
			{
				if (__state.samplerStates[i] == null)
				{
					__state.samplerStates[i] = program.__samplerStates[i].clone();
				}
				else
				{
					__state.samplerStates[i].copyFrom(program.__samplerStates[i]);
				}
			}
		}
	}

	/**
		Set constants for use by shader programs using values stored in a ByteArray.

		Sets constants that can be accessed from the vertex or fragment program.

		@param	programType	one of Context3DProgramType.
		@param	firstRegister	the index of the first shader program constant to set.
		@param	numRegisters	the number of registers to set. Every register is read
		as four float values.
		@param	data	the source ByteArray object
		@param	byteArrayOffset	an offset into the ByteArray for reading
		@throws	TypeError	kNullPointerError when data is null.
		@throws	RangeError	kConstantRegisterOutOfBounds when attempting to set more than
		the maximum number of shader constants.
		@throws	RangeError	kBadInputSize if `byteArrayOffset` is greater than or equal to
		the length of data or no. of elements in `data - byteArrayOffset` is less than
		`numRegisters*16`
	**/
	public function setProgramConstantsFromByteArray(programType:Context3DProgramType, firstRegister:Int, numRegisters:Int, data:ByteArray,
			byteArrayOffset:UInt):Void
	{
		#if lime
		if (numRegisters == 0 || __state.program == null) return;

		if (__state.program != null && __state.program.__format == GLSL)
		{
			// TODO
		}
		else
		{
			// TODO: Cleanup?

			if (numRegisters == -1)
			{
				numRegisters = ((data.length >> 2) - byteArrayOffset);
			}

			var isVertex = (programType == VERTEX);
			var dest = isVertex ? __vertexConstants : __fragmentConstants;

			var floatData = Float32Array.fromBytes(data, 0);
			var outOffset = firstRegister * 4;
			var inOffset = Std.int(byteArrayOffset / 4);

			for (i in 0...(numRegisters * 4))
			{
				dest[outOffset + i] = floatData[inOffset + i];
			}

			if (__state.program != null)
			{
				__state.program.__markDirty(isVertex, firstRegister, numRegisters);
			}
		}
		#end
	}

	/**
		Sets constants for use by shader programs using values stored in a Matrix3D.

		Use this function to pass a matrix to a shader program. The function sets 4
		constant registers used by the vertex or fragment program. The matrix is
		assigned to registers row by row. The first constant register is assigned the
		top row of the matrix. You can set 128 registers for a vertex program and 28
		for a fragment program.

		@param	programType	The type of shader program, either
		`Context3DProgramType.VERTEX` or `Context3DProgramType.FRAGMENT`.
		@param	firstRegister	the index of the first constant register to set. Since
		a Matrix3D has 16 values, four registers are set.
		@param	matrix	the matrix containing the constant values.
		@param	transposedMatrix	if `true` the matrix entries are copied to registers
		in transposed order. The default value is `false`.
		@throws	TypeError	Null Pointer Error: when matrix is `null`.
		@throws	RangeError	Constant Register Out Of Bounds: when attempting to set more
		than the maximum number of shader constant registers.
	**/
	public function setProgramConstantsFromMatrix(programType:Context3DProgramType, firstRegister:Int, matrix:Matrix3D, transposedMatrix:Bool = false):Void
	{
		#if lime
		if (__state.program != null && __state.program.__format == GLSL)
		{
			#if (lime && !js)
			// firstRegister is the uniform's index in the program's staging
			// tables (assigned by Shader.__initGL on native)
			__state.program.__bgfxSetUniformMatrix(cast firstRegister, matrix.rawData, transposedMatrix);
			#else
			__flushGLProgram();

			// TODO: Cache value, prevent need to copy
			var data = new Float32Array(16);
			for (i in 0...16)
			{
				data[i] = matrix.rawData[i];
			}

			gl.uniformMatrix4fv(cast firstRegister, transposedMatrix, data);
			#end
		}
		else
		{
			var isVertex = (programType == VERTEX);
			var dest = isVertex ? __vertexConstants : __fragmentConstants;
			var source = matrix.rawData;
			var i = firstRegister * 4;

			if (transposedMatrix)
			{
				dest[i++] = source[0];
				dest[i++] = source[4];
				dest[i++] = source[8];
				dest[i++] = source[12];

				dest[i++] = source[1];
				dest[i++] = source[5];
				dest[i++] = source[9];
				dest[i++] = source[13];

				dest[i++] = source[2];
				dest[i++] = source[6];
				dest[i++] = source[10];
				dest[i++] = source[14];

				dest[i++] = source[3];
				dest[i++] = source[7];
				dest[i++] = source[11];
				dest[i++] = source[15];
			}
			else
			{
				dest[i++] = source[0];
				dest[i++] = source[1];
				dest[i++] = source[2];
				dest[i++] = source[3];

				dest[i++] = source[4];
				dest[i++] = source[5];
				dest[i++] = source[6];
				dest[i++] = source[7];

				dest[i++] = source[8];
				dest[i++] = source[9];
				dest[i++] = source[10];
				dest[i++] = source[11];

				dest[i++] = source[12];
				dest[i++] = source[13];
				dest[i++] = source[14];
				dest[i++] = source[15];
			}

			if (__state.program != null)
			{
				__state.program.__markDirty(isVertex, firstRegister, 4);
			}
		}
		#end
	}

	/**
		Sets the constant inputs for the shader programs.

		Sets an array of constants to be accessed by a vertex or fragment shader
		program. Constants set in Program3D are accessed within the shader programs as
		constant registers. Each constant register is comprised of 4 floating point
		values (x, y, z, w). Therefore every register requires 4 entries in the data
		Vector. The number of registers that you can set for vertex program and
		fragment program depends on the Context3DProfile.

		@param	programType	The type of shader program, either
		`Context3DProgramType.VERTEX` or `Context3DProgramType.FRAGMENT`.
		@param	firstRegister	the index of the first constant register to set.
		@param	data	the floating point constant values. There must be at least
		`numRegisters` 4 elements in data.
		@param	numRegisters	the number of constants to set. Specify -1, the default
		value, to set enough registers to use all of the available data.
		@throws	TypeError	Null Pointer Error: when data is `null`.
		@throws	RangeError	Constant Register Out Of Bounds: when attempting to set more
		than the maximum number of shader constant registers.
		@throws	RangeError	Bad Input Size: When the number of elements in data is less
		than `numRegisters*4`
	**/
	public function setProgramConstantsFromVector(programType:Context3DProgramType, firstRegister:Int, data:Vector<Float>, numRegisters:Int = -1):Void
	{
		if (numRegisters == 0) return;

		if (__state.program != null && __state.program.__format == GLSL) {}
		else
		{
			if (numRegisters == -1)
			{
				numRegisters = (data.length >> 2);
			}

			var isVertex = (programType == VERTEX);
			var dest = isVertex ? __vertexConstants : __fragmentConstants;
			var source = data;

			var sourceIndex = 0;
			var destIndex = firstRegister * 4;

			for (i in 0...numRegisters)
			{
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
			}

			if (__state.program != null)
			{
				__state.program.__markDirty(isVertex, firstRegister, numRegisters);
			}
		}
	}

	/**
		Sets the constant inputs for the shader programs.

		Sets an array of constants to be accessed by a vertex or fragment shader
		program. Constants set in Program3D are accessed within the shader programs as
		constant registers. Each constant register is comprised of 4 floating point
		values (x, y, z, w). Therefore every register requires 4 entries in the data
		Vector. The number of registers that you can set for vertex program and
		fragment program depends on the Context3DProfile.

		@param	programType	The type of shader program, either
		`Context3DProgramType.VERTEX` or `Context3DProgramType.FRAGMENT`.
		@param	firstRegister	the index of the first constant register to set.
		@param	data	the floating point constant values. There must be at least
		`numRegisters` 4 elements in data.
		@param	numRegisters	the number of constants to set. Specify -1, the default
		value, to set enough registers to use all of the available data.
		@throws	TypeError	Null Pointer Error: when data is `null`.
		@throws	RangeError	Constant Register Out Of Bounds: when attempting to set more
		than the maximum number of shader constant registers.
		@throws	RangeError	Bad Input Size: When the number of elements in data is less
		than `numRegisters*4`
	**/
	public function setProgramConstantsFromArray(programType:Context3DProgramType, firstRegister:Int, data:Array<Float>, numRegisters:Int = -1):Void
	{
		if (numRegisters == 0) return;

		if (__state.program != null && __state.program.__format == GLSL) {}
		else
		{
			if (numRegisters == -1)
			{
				numRegisters = (data.length >> 2);
			}

			var isVertex = (programType == VERTEX);
			var dest = isVertex ? __vertexConstants : __fragmentConstants;
			var source = data;

			var sourceIndex = 0;
			var destIndex = firstRegister * 4;

			for (i in 0...numRegisters)
			{
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
			}

			if (__state.program != null)
			{
				__state.program.__markDirty(isVertex, firstRegister, numRegisters);
			}
		}
	}

	/**
		Sets the back rendering buffer as the render target. Subsequent calls to
		`drawTriangles()` and `clear()` methods result in updates to the back buffer.
		Use this method to resume normal rendering after using the
		`setRenderToTexture()` method.
	**/
	public function setRenderToBackBuffer():Void
	{
		__state.renderToTexture = null;
	}

	/**
		Sets the specified texture as the rendering target.

		Subsequent calls to `drawTriangles()` and `clear()` methods update the
		specified texture instead of the back buffer. Mip maps are created
		automatically. Use the `setRenderToBackBuffer()` to resume normal rendering to
		the back buffer.

		No clear is needed before drawing. If there is no clear operation, the render
		content will be retained. depth buffer and stencil buffer will also not be
		cleared. But it is forced to clear when first drawing. Calling `present()`
		resets the target to the back buffer.

		@param	texture	the target texture to render into. Set to `null` to resume
		rendering to the back buffer (`setRenderToBackBuffer()` and `present` also reset
		the target to the back buffer).
		@param	enableDepthAndStencil	if `true`, depth and stencil testing are
		available. If `false`, all depth and stencil state is ignored for subsequent
		drawing operations.
		@param	antiAlias	the antialiasing quality. Use 0 to disable antialiasing;
		higher values improve antialiasing quality, but require more calculations. The
		value is currently ignored by mobile platform and software rendering context.
		@param	surfaceSelector	specifies which element of the texture to update.
		Texture objects have one surface, so you must specify 0, the default value.
		CubeTexture objects have six surfaces, so you can specify an integer from 0
		through 5.
		@param	colorOutputIndex	The output color register. Must be 0 for constrained
		or baseline mode. Otherwise specifies the output color register.
		@throws	ArgumentError	for a mismatched surfaceSelector parameter. The value
		must be 0 for 2D textures and 0..5 for cube maps.
		@throws	ArgumentError	texture is not derived from the TextureBase class
		(either Texture or CubeTexture classes).
		@throws	ArgumentError	colorOutputIndex must be an integer is from 0 through 3.
		@throws	ArgumentError	this call requires a Context3D that is created with the
		standard profile or above.
	**/
	public function setRenderToTexture(texture:TextureBase, enableDepthAndStencil:Bool = false, antiAlias:Int = 0, surfaceSelector:Int = 0):Void
	{
		__state.renderToTexture = texture;
		__state.renderToTextureDepthStencil = enableDepthAndStencil;
		__state.renderToTextureAntiAlias = antiAlias;
		__state.renderToTextureSurfaceSelector = surfaceSelector;
	}

	/**
		Manually override texture sampler state.

		Texture sampling state is typically set at the time setProgram is called.
		However, you can override texture sampler state with this function. If you do not
		want the program to change sampler state, set the `ignoresamnpler` bit in AGAL
		and use this function.

		@param	sampler	sampler The sampler register to use. Maps to the sampler register
		in AGAL.
		@param	wrap	Wrapping mode. Defined in Context3DWrapMode. The default is repeat.
		@param	filter	Texture filtering mode. Defined in Context3DTextureFilter. The
		default is nearest.
		@param	mipfilter	Mip map filter. Defined in Context3DMipFilter. The default
		is none.
		@throws	Error	sampler out of range
		@throws	Error	wrap, filter, mipfilter bad enum
		@throws	Error	Object Disposed: if this Context3D object has been disposed by a
		calling `dispose()` or because the underlying rendering hardware has been lost.
	**/
	public function setSamplerStateAt(sampler:Int, wrap:Context3DWrapMode, filter:Context3DTextureFilter, mipfilter:Context3DMipFilter):Void
	{
		// if (sampler < 0 || sampler > Context3D.MAX_SAMPLERS) {

		// 	throw new Error ("sampler out of range");

		// }

		if (__state.samplerStates[sampler] == null)
		{
			__state.samplerStates[sampler] = new SamplerState();
		}

		var state = __state.samplerStates[sampler];
		state.wrap = wrap;
		state.filter = filter;
		state.mipfilter = mipfilter;
	}

	/**
		Sets a scissor rectangle, which is type of drawing mask. The renderer only draws
		to the area inside the scissor rectangle. Scissoring does not affect clear
		operations.

		Pass `null` to turn off scissoring.

		@param	rectangle	The rectangle in which to draw. Specify the rectangle
		position and dimensions in pixels. The coordinate system origin is the top left
		corner of the viewport, with positive values increasing down and to the right
		(the same as the normal OpenFL display coordinate system).
	**/
	public function setScissorRectangle(rectangle:Rectangle):Void
	{
		if (rectangle != null)
		{
			__state.scissorEnabled = true;
			__state.scissorRectangle.copyFrom(rectangle);
		}
		else
		{
			__state.scissorEnabled = false;
		}
	}

	/**
		Sets stencil mode and operation.

		An 8-bit stencil reference value can be associated with each draw call. During
		rendering, the reference value can be tested against values stored previously
		in the frame buffer. The result of the test can control the draw action and
		whether or how the stored stencil value is updated. In addition, depth testing
		controls whether stencil testing is performed. A failed depth test can also be
		used to control the action taken on the stencil buffer.

		In the pixel processing pipeline, depth testing is performed first. If the depth
		test fails, a stencil buffer update action can be taken, but no further evaluation
		of the stencil buffer value can be made. If the depth test passes, then the
		stencil test is performed. Alternate actions can be taken depending on the outcome
		of the stencil test.

		The stencil reference value is set using `setStencilReferenceValue()`.

		@param	triangleFace	the triangle orientations allowed to contribute to the
		stencil operation. One of Context3DTriangleFace.
		@param	compareMode	the test operator used to compare the current stencil
		reference value and the destination pixel stencil value. Destination pixel color
		and depth update is performed when the comparison is true. The stencil actions
		are performed as requested in the following action parameters. The comparison
		operator is applied as an infix operator between the current and destination
		reference values, in that order (in pseudocode:
		`if stencilReference OPERATOR stencilBuffer then pass`). Use one of the constants
		defined in the Context3DCompareMode class.
		@param	actionOnBothPass	action to be taken when both depth and stencil
		comparisons pass. Use one of the constants defined in the Context3DStencilAction
		class.
		@param	actionOnDepthFail	action to be taken when depth comparison fails. Use
		one of the constants defined in the Context3DStencilAction class.
		@param	actionOnDepthPassStencilFail	action to be taken when depth comparison
		passes and the stencil comparison fails. Use one of the constants defined in the
		Context3DStencilAction class.
		@throws	Error	Invalid Enum Error: when `triangleFace` is not one of the values
		defined in the Context3DTriangleFace class.
		@throws	Error	Invalid Enum Error: when `compareMode` is not one of the values
		defined in the Context3DCompareMode class.
		@throws	Error	Invalid Enum Error: when `actionOnBothPass`, `actionOnDepthFail`,
		or `actionOnDepthPassStencilFail` is not one of the values defined in the
		Context3DStencilAction class.
	**/
	public function setStencilActions(triangleFace:Context3DTriangleFace = FRONT_AND_BACK, compareMode:Context3DCompareMode = ALWAYS,
			actionOnBothPass:Context3DStencilAction = KEEP, actionOnDepthFail:Context3DStencilAction = KEEP,
			actionOnDepthPassStencilFail:Context3DStencilAction = KEEP):Void
	{
		__state.stencilTriangleFace = triangleFace;
		__state.stencilCompareMode = compareMode;
		__state.stencilPass = actionOnBothPass;
		__state.stencilDepthFail = actionOnDepthFail;
		__state.stencilFail = actionOnDepthPassStencilFail;
	}

	/**
		Sets the stencil comparison value used for stencil tests.

		Only the lower 8 bits of the reference value are used. The stencil buffer value
		is also 8 bits in length. Use the `readMask` and `writeMask` to use the stencil
		buffer as a bit field.

		@param	referenceValue	an 8-bit reference value used in reference value
		comparison tests.
		@param	readMask	an 8-bit mask for applied to both the current stencil
		buffer value and the reference value before the comparison.
		@param	writeMask	an 8-bit mask applied to the reference value before updating
		the stencil buffer.
	**/
	public function setStencilReferenceValue(referenceValue:UInt, readMask:UInt = 0xFF, writeMask:UInt = 0xFF):Void
	{
		__state.stencilReferenceValue = referenceValue;
		__state.stencilReadMask = readMask;
		__state.stencilWriteMask = writeMask;
	}

	/**
		Specifies the texture to use for a texture input register of a fragment program.

		A fragment program can read information from up to eight texture objects. Use
		this function to assign a Texture or CubeTexture object to one of the sampler
		registers used by the fragment program.

		**Note:** if you change the active fragment program (with setProgram) to a
		shader that uses fewer textures, set the unused registers to `null`:

		``haxe
		setTextureAt(7, null);
		```

		@param	sampler	the sampler register index, a value from 0 through 7.
		@param	texture	the texture object to make available, either a Texture or a
		CubeTexture instance.
	**/
	public function setTextureAt(sampler:Int, texture:TextureBase):Void
	{
		// if (sampler < 0 || sampler > Context3D.MAX_SAMPLERS) {

		// 	throw new Error ("sampler out of range");

		// }

		__state.textures[sampler] = texture;
	}

	/**
		Specifies which vertex data components correspond to a single vertex shader
		program input.

		Use the setVertexBufferAt method to identify which components of the data
		defined for each vertex in a VertexBuffer3D buffer belong to which inputs to the
		vertex program. The developer of the vertex program determines how much data is
		needed per vertex. That data is mapped from 1 or more VertexBuffer3D stream(s) to
		the attribute registers of the vertex shader program.

		The smallest unit of data consumed by the vertex shader is a 32-bit data.
		Offsets into the vertex stream are specified in multiples of 32-bits.

		As an example, a programmer might define each vertex with the following data:

		```
		position:  x    float32
				   y    float32
				   z    float32
		color:     r    unsigned byte
				   g    unsigned byte
				   b    unsigned byte
				   a    unsigned byte
		```

		Assuming the vertex was defined in a VertexBuffer3D object named buffer, it
		would be assigned to a vertex shader with the following code:

		```haxe
		setVertexBufferAt(0, buffer, 0, Context3DVertexBufferFormat.FLOAT_3);   // attribute #0 will contain the position information
		setVertexBufferAt(1, buffer, 3, Context3DVertexBufferFormat.BYTES_4);    // attribute #1 will contain the color information
		```

		@param	index	the index of the attribute register in the vertex shader (0
		through 7).
		@param	buffer	the buffer that contains the source vertex data to be fed to the
		vertex shader.
		@param	bufferOffset	an offset from the start of the data for a single vertex
		at which to start reading this attribute. In the example above, the position data
		has an offset of 0 because it is the first attribute; color has an offset of 3
		because the color attribute follows the three 32-bit position values. The offset
		is specified in units of 32 bits.
		@param	format	a value from the Context3DVertexBufferFormat class specifying
		the data type of this attribute.
		@throws	Error	Invalid Enum: when format is not one of the values defined in
		the Context3DVertexBufferFormat class.
		@throws	RangeError	Attribute Register Out Of Bounds: when the index parameter
		is outside the range from 0 through 7. (A maximum of eight vertex attribute
		registers can be used by a shader.)
	**/
	public function setVertexBufferAt(index:Int, buffer:VertexBuffer3D, bufferOffset:Int = 0, format:Context3DVertexBufferFormat = FLOAT_4):Void
	{
		if (index < 0) return;

		#if (lime && !js)
		if (buffer == null)
		{
			__bgfxSetVertexBufferAt(index, null, 0, FLOAT_4);
			return;
		}

		__bgfxSetVertexBufferAt(index, buffer, bufferOffset * 4, format);
		return;
		#end

		if (buffer == null)
		{
			gl.disableVertexAttribArray(index);
			__bindGLArrayBuffer(null);
			return;
		}

		__bindGLArrayBuffer(buffer.__id);
		gl.enableVertexAttribArray(index);

		var byteOffset = bufferOffset * 4;

		switch (format)
		{
			case BYTES_4:
				gl.vertexAttribPointer(index, 4, gl.UNSIGNED_BYTE, true, buffer.__stride, byteOffset);

			case FLOAT_4:
				gl.vertexAttribPointer(index, 4, gl.FLOAT, false, buffer.__stride, byteOffset);

			case FLOAT_3:
				gl.vertexAttribPointer(index, 3, gl.FLOAT, false, buffer.__stride, byteOffset);

			case FLOAT_2:
				gl.vertexAttribPointer(index, 2, gl.FLOAT, false, buffer.__stride, byteOffset);

			case FLOAT_1:
				gl.vertexAttribPointer(index, 1, gl.FLOAT, false, buffer.__stride, byteOffset);

			default:
				throw new IllegalOperationError();
		}
	}

	@:noCompletion private function __bindGLArrayBuffer(buffer:GLBuffer):Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.__currentGLArrayBuffer != buffer #end)
		{
			gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
			__contextState.__currentGLArrayBuffer = buffer;
		}
	}

	@:noCompletion private function __bindGLElementArrayBuffer(buffer:GLBuffer):Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.__currentGLElementArrayBuffer != buffer #end)
		{
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer);
			__contextState.__currentGLElementArrayBuffer = buffer;
		}
	}

	@:noCompletion private function __bindGLFramebuffer(framebuffer:GLFramebuffer):Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.__currentGLFramebuffer != framebuffer #end)
		{
			gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
			__contextState.__currentGLFramebuffer = framebuffer;
		}
	}

	@:noCompletion private function __bindGLTexture2D(texture:GLTexture):Void
	{
		// TODO: Need to consider activeTexture ID

		// if (#if openfl_disable_context_cache true #else __contextState.__currentGLTexture2D != texture #end) {

		gl.bindTexture(gl.TEXTURE_2D, texture);
		__contextState.__currentGLTexture2D = texture;

		// }
	}

	@:noCompletion private function __bindGLTextureCubeMap(texture:GLTexture):Void
	{
		// TODO: Need to consider activeTexture ID

		// if (#if openfl_disable_context_cache true #else __contextState.__currentGLTextureCubeMap != texture #end) {

		gl.bindTexture(gl.TEXTURE_CUBE_MAP, texture);
		__contextState.__currentGLTextureCubeMap = texture;

		// }
	}

	@:noCompletion private function __dispose():Void
	{
		driverInfo += " (Disposed)";

		if (__stage3D != null)
		{
			__stage3D.__indexBuffer = null;
			__stage3D.__vertexBuffer = null;
			__stage3D.context3D = null;
			__stage3D = null;
		}

		__backBufferTexture = null;
		__context = null;
		__renderStage3DProgram = null;
		__fragmentConstants = null;
		__frontBufferTexture = null;
		__positionScale = null;
		__present = false;
		__quadIndexBuffer = null;
		__stage = null;
		__vertexConstants = null;
	}

	@:noCompletion private function __drawTriangles(firstIndex:Int = 0, count:Int):Void
	{
		#if (lime && !js)
		__bgfxDraw(null, firstIndex, count);
		return;
		#end

		#if !openfl_disable_display_render
		if (__state.renderToTexture == null)
		{
			// TODO: Make sure state is correct for this?
			if (__stage.context3D == this && !__stage.__renderer.__cleared)
			{
				__stage.__renderer.__clear();
			}
			else if (!__cleared)
			{
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}
		}

		__flushGL();
		#end

		if (__state.program != null)
		{
			__state.program.__flush();
		}

		if (OpenGLRenderer.__coherentBlendsSupported)
		{
			gl.enable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
		else if (__usingComplexBlend)
		{
			gl.blendBarrier();
		}

		gl.drawArrays(gl.TRIANGLES, firstIndex, count);

		if (OpenGLRenderer.__coherentBlendsSupported)
		{
			gl.disable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
	}

	@:noCompletion private function __flushGL():Void
	{
		#if (lime && !js)
		// bgfx state is set at submit time; nothing to flush here
		return;
		#end

		__flushGLProgram();
		__flushGLFramebuffer();
		__flushGLViewport();

		__flushGLBlend();
		__flushGLColor();
		__flushGLCulling();
		__flushGLDepth();
		__flushGLScissor();
		__flushGLStencil();
		__flushGLTextures();
	}

	@:noCompletion private function __flushGLBlend():Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.blendDestinationRGBFactor != __state.blendDestinationRGBFactor
			|| __contextState.blendSourceRGBFactor != __state.blendSourceRGBFactor
			|| __contextState.blendDestinationAlphaFactor != __state.blendDestinationAlphaFactor
			|| __contextState.blendSourceAlphaFactor != __state.blendSourceAlphaFactor #end)
		{
			__setGLBlend(true);

			if (__state.blendDestinationRGBFactor == __state.blendDestinationAlphaFactor
				&& __state.blendSourceRGBFactor == __state.blendSourceAlphaFactor)
			{
				gl.blendFunc(__getGLBlend(__state.blendSourceRGBFactor), __getGLBlend(__state.blendDestinationRGBFactor));
			}
			else
			{
				gl.blendFuncSeparate(__getGLBlend(__state.blendSourceRGBFactor), __getGLBlend(__state.blendDestinationRGBFactor),
					__getGLBlend(__state.blendSourceAlphaFactor), __getGLBlend(__state.blendDestinationAlphaFactor));
			}

			__contextState.blendDestinationRGBFactor = __state.blendDestinationRGBFactor;
			__contextState.blendSourceRGBFactor = __state.blendSourceRGBFactor;
			__contextState.blendDestinationAlphaFactor = __state.blendDestinationAlphaFactor;
			__contextState.blendSourceAlphaFactor = __state.blendSourceAlphaFactor;
		}
	}

	@:noCompletion private inline function __flushGLColor():Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.colorMaskRed != __state.colorMaskRed
			|| __contextState.colorMaskGreen != __state.colorMaskGreen
			|| __contextState.colorMaskBlue != __state.colorMaskBlue
			|| __contextState.colorMaskAlpha != __state.colorMaskAlpha #end)
		{
			gl.colorMask(__state.colorMaskRed, __state.colorMaskGreen, __state.colorMaskBlue, __state.colorMaskAlpha);
			__contextState.colorMaskRed = __state.colorMaskRed;
			__contextState.colorMaskGreen = __state.colorMaskGreen;
			__contextState.colorMaskBlue = __state.colorMaskBlue;
			__contextState.colorMaskAlpha = __state.colorMaskAlpha;
		}
	}

	@:noCompletion private function __flushGLCulling():Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.culling != __state.culling #end)
		{
			if (__state.culling == NONE)
			{
				__setGLCullFace(false);
			}
			else
			{
				__setGLCullFace(true);

				switch (__state.culling)
				{
					case NONE: // skip
					case BACK:
						gl.cullFace(gl.BACK);
					case FRONT:
						gl.cullFace(gl.FRONT);
					case FRONT_AND_BACK:
						gl.cullFace(gl.FRONT_AND_BACK);
					default:
						throw new IllegalOperationError();
				}
			}

			__contextState.culling = __state.culling;
		}
	}

	@:noCompletion private function __flushGLDepth():Void
	{
		var depthMask = (__state.depthMask
			&& (__state.renderToTexture != null ? __state.renderToTextureDepthStencil : __state.backBufferEnableDepthAndStencil));

		if (#if openfl_disable_context_cache true #else __contextState.depthMask != depthMask #end)
		{
			gl.depthMask(depthMask);
			__contextState.depthMask = depthMask;
		}

		if (#if openfl_disable_context_cache true #else __contextState.depthCompareMode != __state.depthCompareMode #end)
		{
			switch (__state.depthCompareMode)
			{
				case ALWAYS:
					gl.depthFunc(gl.ALWAYS);
				case EQUAL:
					gl.depthFunc(gl.EQUAL);
				case GREATER:
					gl.depthFunc(gl.GREATER);
				case GREATER_EQUAL:
					gl.depthFunc(gl.GEQUAL);
				case LESS:
					gl.depthFunc(gl.LESS);
				case LESS_EQUAL:
					gl.depthFunc(gl.LEQUAL);
				case NEVER:
					gl.depthFunc(gl.NEVER);
				case NOT_EQUAL:
					gl.depthFunc(gl.NOTEQUAL);
				default:
					throw new IllegalOperationError();
			}

			__contextState.depthCompareMode = __state.depthCompareMode;
		}
	}

	@:noCompletion private function __flushGLFramebuffer():Void
	{
		if (__state.renderToTexture != null)
		{
			if (#if openfl_disable_context_cache true #else __contextState.renderToTexture != __state.renderToTexture
				|| __contextState.renderToTextureSurfaceSelector != __state.renderToTextureSurfaceSelector #end)
			{
				var framebuffer = __state.renderToTexture.__getGLFramebuffer(__state.renderToTextureDepthStencil, __state.renderToTextureAntiAlias,
					__state.renderToTextureSurfaceSelector);
				__bindGLFramebuffer(framebuffer);

				__contextState.renderToTexture = __state.renderToTexture;
				__contextState.renderToTextureAntiAlias = __state.renderToTextureAntiAlias;
				__contextState.renderToTextureDepthStencil = __state.renderToTextureDepthStencil;
				__contextState.renderToTextureSurfaceSelector = __state.renderToTextureSurfaceSelector;
			}

			__setGLDepthTest(__state.renderToTextureDepthStencil);
			__setGLStencilTest(__state.renderToTextureDepthStencil);

			__setGLFrontFace(true);
		}
		else
		{
			if (__stage == null && backBufferWidth == 0 && backBufferHeight == 0)
			{
				throw new Error("Context3D backbuffer has not been configured");
			}

			if (#if openfl_disable_context_cache true #else __contextState.renderToTexture != null
				|| __contextState.__currentGLFramebuffer != __state.__primaryGLFramebuffer
				|| __contextState.backBufferEnableDepthAndStencil != __state.backBufferEnableDepthAndStencil #end
			)
			{
				__bindGLFramebuffer(__state.__primaryGLFramebuffer);

				__contextState.renderToTexture = null;
				__contextState.backBufferEnableDepthAndStencil = __state.backBufferEnableDepthAndStencil;
			}

			__setGLDepthTest(__state.backBufferEnableDepthAndStencil);
			__setGLStencilTest(__state.backBufferEnableDepthAndStencil);

			__setGLFrontFace(__stage.context3D != this);
		}
	}

	@:noCompletion private function __flushGLProgram():Void
	{
		#if (lime && !js)
		// bgfx binds the program at submit time; nothing to flush here
		return;
		#end

		var shader = __state.shader;
		var program = __state.program;

		if (#if openfl_disable_context_cache true #else __contextState.shader != shader #end)
		{
			// TODO: Merge this logic

			if (__contextState.shader != null)
			{
				__contextState.shader.__disable();
			}

			if (shader != null)
			{
				shader.__enable();
			}

			__contextState.shader = shader;
		}

		if (#if openfl_disable_context_cache true #else __contextState.program != program #end)
		{
			if (__contextState.program != null)
			{
				__contextState.program.__disable();
			}

			if (program != null)
			{
				program.__enable();
			}

			__contextState.program = program;
		}

		if (program != null && program.__format == AGAL)
		{
			__positionScale[1] = (__stage.context3D == this && __state.renderToTexture == null) ? 1.0 : -1.0;
			program.__setPositionScale(__positionScale);
		}
	}

	@:noCompletion private function __flushGLScissor():Void
	{
		if (!__state.scissorEnabled)
		{
			if (#if openfl_disable_context_cache true #else __contextState.scissorEnabled != __state.scissorEnabled #end)
			{
				__setGLScissorTest(false);
				__contextState.scissorEnabled = false;
			}
		}
		else
		{
			__setGLScissorTest(true);
			__contextState.scissorEnabled = true;

			var scissorX = Std.int(__state.scissorRectangle.x);
			var scissorY = Std.int(__state.scissorRectangle.y);
			var scissorWidth = Std.int(__state.scissorRectangle.width);
			var scissorHeight = Std.int(__state.scissorRectangle.height);
			#if !openfl_dpi_aware
			if (__backBufferWantsBestResolution)
			{
				scissorX = Std.int(__state.scissorRectangle.x * __stage.window.scale);
				scissorY = Std.int(__state.scissorRectangle.y * __stage.window.scale);
				scissorWidth = Std.int(__state.scissorRectangle.width * __stage.window.scale);
				scissorHeight = Std.int(__state.scissorRectangle.height * __stage.window.scale);
			}
			#end

			if (__state.renderToTexture == null && __stage3D == null)
			{
				var contextHeight = Std.int(__stage.window.height * __stage.window.scale);
				scissorY = contextHeight - scissorHeight - scissorY;
			}

			if (#if openfl_disable_context_cache true #else __contextState.scissorRectangle.x != scissorX
				|| __contextState.scissorRectangle.y != scissorY
				|| __contextState.scissorRectangle.width != scissorWidth
				|| __contextState.scissorRectangle.height != scissorHeight #end)
			{
				gl.scissor(scissorX, scissorY, scissorWidth, scissorHeight);
				__contextState.scissorRectangle.setTo(scissorX, scissorY, scissorWidth, scissorHeight);
			}
		}
	}

	@:noCompletion private function __flushGLStencil():Void
	{
		if (#if openfl_disable_context_cache true #else __contextState.stencilTriangleFace != __state.stencilTriangleFace
			|| __contextState.stencilPass != __state.stencilPass
			|| __contextState.stencilDepthFail != __state.stencilDepthFail
			|| __contextState.stencilFail != __state.stencilFail #end)
		{
			gl.stencilOpSeparate(__getGLTriangleFace(__state.stencilTriangleFace), __getGLStencilAction(__state.stencilFail),
				__getGLStencilAction(__state.stencilDepthFail), __getGLStencilAction(__state.stencilPass));
			__contextState.stencilTriangleFace = __state.stencilTriangleFace;
			__contextState.stencilPass = __state.stencilPass;
			__contextState.stencilDepthFail = __state.stencilDepthFail;
			__contextState.stencilFail = __state.stencilFail;
		}

		if (#if openfl_disable_context_cache true #else __contextState.stencilWriteMask != __state.stencilWriteMask #end)
		{
			gl.stencilMask(__state.stencilWriteMask);
			__contextState.stencilWriteMask = __state.stencilWriteMask;
		}

		if (#if openfl_disable_context_cache true #else __contextState.stencilCompareMode != __state.stencilCompareMode
			|| __contextState.stencilReferenceValue != __state.stencilReferenceValue
			|| __contextState.stencilReadMask != __state.stencilReadMask #end
		)
		{
			gl.stencilFunc(__getGLCompareMode(__state.stencilCompareMode), __state.stencilReferenceValue, __state.stencilReadMask);
			__contextState.stencilCompareMode = __state.stencilCompareMode;
			__contextState.stencilReferenceValue = __state.stencilReferenceValue;
			__contextState.stencilReadMask = __state.stencilReadMask;
		}
	}

	@:noCompletion private function __flushGLTextures():Void
	{
		#if (lime && !js)
		// bgfx binds textures at submit time; nothing to flush here
		return;
		#end

		var sampler = 0;
		var texture:TextureBase;
		var samplerState:SamplerState;

		for (i in 0...__state.textures.length)
		{
			texture = __state.textures[i];
			samplerState = __state.samplerStates[i];
			if (samplerState == null)
			{
				__state.samplerStates[i] = new SamplerState();
				samplerState = __state.samplerStates[i];
			}

			gl.activeTexture(gl.TEXTURE0 + sampler);

			if (texture != null)
			{
				// if (#if openfl_disable_context_cache true #else texture != __contextState.textures[i] #end) {

				// TODO: Cleaner approach?
				if (texture.__textureTarget == gl.TEXTURE_2D)
				{
					__bindGLTexture2D(texture.__getTexture());
				}
				else
				{
					__bindGLTextureCubeMap(texture.__getTexture());
				}

				__contextState.textures[i] = texture;

				// }

				texture.__setSamplerState(samplerState);
			}
			else
			{
				__bindGLTexture2D(null);
			}

			if (__state.program != null && __state.program.__format == AGAL && samplerState.textureAlpha)
			{
				gl.activeTexture(gl.TEXTURE0 + sampler + 4);

				if (texture != null && texture.__alphaTexture != null)
				{
					if (texture.__alphaTexture.__textureTarget == gl.TEXTURE_2D)
					{
						__bindGLTexture2D(texture.__alphaTexture.__getTexture());
					}
					else
					{
						__bindGLTextureCubeMap(texture.__alphaTexture.__getTexture());
					}

					texture.__alphaTexture.__setSamplerState(samplerState);
					gl.uniform1i(__state.program.__agalAlphaSamplerEnabled[sampler].location, 1);
				}
				else
				{
					__bindGLTexture2D(null);
					if (__state.program.__agalAlphaSamplerEnabled[sampler] != null)
					{
						gl.uniform1i(__state.program.__agalAlphaSamplerEnabled[sampler].location, 0);
					}
				}
			}

			sampler++;
		}
	}

	@:noCompletion private function __flushGLViewport():Void
	{
		// TODO: Cache

		if (__state.renderToTexture == null)
		{
			if (__stage.context3D == this)
			{
				var scaledBackBufferWidth = backBufferWidth;
				var scaledBackBufferHeight = backBufferHeight;
				#if !openfl_dpi_aware
				if (__stage3D == null && !__backBufferWantsBestResolution)
				{
					scaledBackBufferWidth = Std.int(backBufferWidth * __stage.window.scale);
					scaledBackBufferHeight = Std.int(backBufferHeight * __stage.window.scale);
				}
				#end
				var x = __stage3D == null ? 0 : Std.int(__stage3D.x);
				var y = Std.int((__stage.window.height * __stage.window.scale) - scaledBackBufferHeight - (__stage3D == null ? 0 : __stage3D.y));
				gl.viewport(x, y, scaledBackBufferWidth, scaledBackBufferHeight);
			}
			else
			{
				gl.viewport(0, 0, backBufferWidth, backBufferHeight);
			}
		}
		else
		{
			var width = 0, height = 0;

			// TODO: Avoid use of Std.is
			if ((__state.renderToTexture is Texture))
			{
				var texture2D:Texture = cast __state.renderToTexture;
				width = texture2D.__width;
				height = texture2D.__height;
			}
			else if ((__state.renderToTexture is RectangleTexture))
			{
				var rectTexture:RectangleTexture = cast __state.renderToTexture;
				width = rectTexture.__width;
				height = rectTexture.__height;
			}
			else if ((__state.renderToTexture is CubeTexture))
			{
				var cubeTexture:CubeTexture = cast __state.renderToTexture;
				width = cubeTexture.__size;
				height = cubeTexture.__size;
			}

			gl.viewport(0, 0, width, height);
		}
	}

	@:noCompletion private function __getGLBlend(blendFactor:Context3DBlendFactor):Int
	{
		switch (blendFactor)
		{
			case DESTINATION_ALPHA:
				return gl.DST_ALPHA;
			case DESTINATION_COLOR:
				return gl.DST_COLOR;
			case ONE:
				return gl.ONE;
			case ONE_MINUS_DESTINATION_ALPHA:
				return gl.ONE_MINUS_DST_ALPHA;
			case ONE_MINUS_DESTINATION_COLOR:
				return gl.ONE_MINUS_DST_COLOR;
			case ONE_MINUS_SOURCE_ALPHA:
				return gl.ONE_MINUS_SRC_ALPHA;
			case ONE_MINUS_SOURCE_COLOR:
				return gl.ONE_MINUS_SRC_COLOR;
			case SOURCE_ALPHA:
				return gl.SRC_ALPHA;
			case SOURCE_COLOR:
				return gl.SRC_COLOR;
			case ZERO:
				return gl.ZERO;
			default:
				throw new IllegalOperationError();
		}

		return 0;
	}

	@:noCompletion private function __getGLCompareMode(mode:Context3DCompareMode):Int
	{
		return switch (mode)
		{
			case ALWAYS: gl.ALWAYS;
			case EQUAL: gl.EQUAL;
			case GREATER: gl.GREATER;
			case GREATER_EQUAL: gl.GEQUAL;
			case LESS: gl.LESS;
			case LESS_EQUAL: gl.LEQUAL; // TODO : wrong value
			case NEVER: gl.NEVER;
			case NOT_EQUAL: gl.NOTEQUAL;
			default: gl.EQUAL;
		}
	}

	@:noCompletion private function __getGLStencilAction(action:Context3DStencilAction):Int
	{
		return switch (action)
		{
			case DECREMENT_SATURATE: gl.DECR;
			case DECREMENT_WRAP: gl.DECR_WRAP;
			case INCREMENT_SATURATE: gl.INCR;
			case INCREMENT_WRAP: gl.INCR_WRAP;
			case INVERT: gl.INVERT;
			case KEEP: gl.KEEP;
			case SET: gl.REPLACE;
			case ZERO: gl.ZERO;
			default: gl.KEEP;
		}
	}

	@:noCompletion private function __getGLTriangleFace(face:Context3DTriangleFace):Int
	{
		return switch (face)
		{
			case FRONT: gl.FRONT;
			case BACK: gl.BACK;
			case FRONT_AND_BACK: gl.FRONT_AND_BACK;
			case NONE: gl.NONE;
			default: gl.FRONT_AND_BACK;
		}
	}

	@:noCompletion private function __renderStage3D(stage3D:Stage3D):Void
	{
		// Assume this is the primary Context3D

		var context = stage3D.context3D;

		if (context != null
			&& context != this
			&& context.__frontBufferTexture != null
			&& stage3D.visible
			&& backBufferHeight > 0
			&& backBufferWidth > 0)
		{
			// if (!__stage.__renderer.__cleared) __stage.__renderer.__clear ();

			if (__renderStage3DProgram == null)
			{
				var vertexAssembler = new AGALMiniAssembler();
				vertexAssembler.assemble(Context3DProgramType.VERTEX, "m44 op, va0, vc0\n" + "mov v0, va1");

				var fragmentAssembler = new AGALMiniAssembler();
				fragmentAssembler.assemble(Context3DProgramType.FRAGMENT, "tex ft1, v0, fs0 <2d,nearest,nomip>\n" + "mov oc, ft1");

				__renderStage3DProgram = createProgram();
				__renderStage3DProgram.upload(vertexAssembler.agalcode, fragmentAssembler.agalcode);
			}

			setProgram(__renderStage3DProgram);

			setBlendFactors(ONE, ZERO);
			setColorMask(true, true, true, true);
			setCulling(NONE);
			setDepthTest(false, ALWAYS);
			setStencilActions();
			setStencilReferenceValue(0, 0, 0);
			setScissorRectangle(null);

			setTextureAt(0, context.__frontBufferTexture);
			setVertexBufferAt(0, stage3D.__vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			setVertexBufferAt(1, stage3D.__vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, stage3D.__renderTransform, true);
			drawTriangles(stage3D.__indexBuffer);

			__present = true;
		}
	}

	@:noCompletion private function __setGLBlend(enable:Bool):Void
	{
		#if (lime && !js) return; #end
		if (#if openfl_disable_context_cache true #else __contextState.__enableGLBlend != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.BLEND);
			}
			else
			{
				gl.disable(gl.BLEND);
			}
			__contextState.__enableGLBlend = enable;
		}
	}

	@:noCompletion private function __setGLBlendEquation(value:Int):Void
	{
		#if (lime && !js)
		// map the GL blend equation enums OpenGLRenderer passes as literals.
		// KHR advanced equations (0x92xx) select a shader-blend variant that
		// samples a blitted snapshot of the render target
		if (value >= 0x9294 && value <= 0x92B0)
		{
			__bgfxComplexBlend = value;
			__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_ADD_HI;
			__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_ADD_LO;
			return;
		}

		__bgfxComplexBlend = 0;

		switch (value)
		{
			case 0x8007: // GL_MIN
				__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_MIN_HI;
				__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_MIN_LO;
			case 0x8008: // GL_MAX
				__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_MAX_HI;
				__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_MAX_LO;
			case 0x800A: // GL_FUNC_SUBTRACT
				__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_SUB_HI;
				__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_SUB_LO;
			case 0x800B: // GL_FUNC_REVERSE_SUBTRACT
				__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_REVSUB_HI;
				__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_REVSUB_LO;
			default: // GL_FUNC_ADD / unsupported
				__bgfxBlendEquationHi = BGFX.STATE_BLEND_EQUATION_ADD_HI;
				__bgfxBlendEquationLo = BGFX.STATE_BLEND_EQUATION_ADD_LO;
		}
		return;
		#end

		if (#if openfl_disable_context_cache true #else __contextState.__glBlendEquation != value #end)
		{
			gl.blendEquation(value);
			__contextState.__glBlendEquation = value;
		}
	}

	@:noCompletion private function __setGLCullFace(enable:Bool):Void
	{
		#if (lime && !js) return; #end
		if (#if openfl_disable_context_cache true #else __contextState.__enableGLCullFace != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.CULL_FACE);
			}
			else
			{
				gl.disable(gl.CULL_FACE);
			}
			__contextState.__enableGLCullFace = enable;
		}
	}

	@:noCompletion private function __setGLDepthTest(enable:Bool):Void
	{
		#if (lime && !js) return; #end
		if (#if openfl_disable_context_cache true #else __contextState.__enableGLDepthTest != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.DEPTH_TEST);
			}
			else
			{
				gl.disable(gl.DEPTH_TEST);
			}
			__contextState.__enableGLDepthTest = enable;
		}
	}

	@:noCompletion private function __setGLFrontFace(counterClockWise:Bool):Void
	{
		#if (lime && !js) return; #end
		if (#if openfl_disable_context_cache true #else __contextState.__frontFaceGLCCW != counterClockWise #end)
		{
			gl.frontFace(counterClockWise ? gl.CCW : gl.CW);
			__contextState.__frontFaceGLCCW = counterClockWise;
		}
	}

	@:noCompletion private function __setGLScissorTest(enable:Bool):Void
	{
		#if (lime && !js) return; #end
		if (#if openfl_disable_context_cache true #else __contextState.__enableGLScissorTest != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.SCISSOR_TEST);
			}
			else
			{
				gl.disable(gl.SCISSOR_TEST);
			}
			__contextState.__enableGLScissorTest = enable;
		}
	}

	@:noCompletion private function __setGLStencilTest(enable:Bool):Void
	{
		#if (lime && !js) return; #end
		if (#if openfl_disable_context_cache true #else __contextState.__enableGLStencilTest != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.STENCIL_TEST);
			}
			else
			{
				gl.disable(gl.STENCIL_TEST);
			}
			__contextState.__enableGLStencilTest = enable;
		}
	}

	@:noCompletion private inline function __glBlendBarrier():Void
	{
		#if !(lime && !js)
		gl.blendBarrier();
		#end
	}

	#if (lime && !js)
	// ---- BGFX backend ----
	// bgfx sorts draws by view id; 2D correctness needs submission order, so
	// every view runs in SEQUENTIAL mode and a fresh view id is allocated
	// whenever the render target changes or a clear is requested. The counter
	// is frame-global (shared across Stage3D contexts) and resets at frame().

	@:noCompletion private static var __bgfxNextViewId:Int = 0;
	@:noCompletion private var __bgfxViewId:Int = -1;
	@:noCompletion private var __bgfxViewValid:Bool = false;
	@:noCompletion private var __bgfxCurrentFrameBuffer:Int = -2;
	@:noCompletion private var __bgfxAttribBuffers:Array<VertexBuffer3D> = [];
	@:noCompletion private var __bgfxAttribOffsets:Array<Int> = []; // bytes
	@:noCompletion private var __bgfxAttribFormats:Array<Context3DVertexBufferFormat> = [];
	@:noCompletion private var __bgfxAttribConstants:Array<Array<Float>> = [];
	@:noCompletion private var __bgfxAttribParamPositions:Array<Int> = [];
	@:noCompletion private var __bgfxAttribParamLengths:Array<Int> = [];
	@:noCompletion private var __bgfxParamData:Float32Array;
	@:noCompletion private var __bgfxLayoutHandles:Map<String, Int> = new Map();
	@:noCompletion private var __bgfxLayoutObjects:Map<String, BGFXVertexLayout> = new Map();
	@:noCompletion private var __bgfxScratch:Float32Array;
	@:noCompletion private var __bgfxBlendEquationHi:Int = 0;
	@:noCompletion private var __bgfxBlendEquationLo:Int = 0;

	// complex (KHR-advanced) blends: the primary display renders into an
	// offscreen target so each complex draw can blit a snapshot and blend
	// against it in the fragment shader
	@:noCompletion private var __bgfxComplexBlend:Int = 0;
	@:noCompletion private var __bgfxMainFrameBuffer:Int = -1;
	@:noCompletion private var __bgfxMainColor:Int = -1;
	// debug: when != -1, __bgfxComposite shows this texture instead of the main
	// target (set via OPENFL_FILTER_DEBUG, see DisplayObjectRenderer)
	@:noCompletion private static var __bgfxDebugTex:Int = -1;
	@:noCompletion private static var __bgfxDebugObjCounter:Int = 0;
	@:noCompletion private var __bgfxMainDepth:Int = -1;
	@:noCompletion private var __bgfxMainWidth:Int = 0;
	@:noCompletion private var __bgfxMainHeight:Int = 0;
	@:noCompletion private var __bgfxGrabTexture:Int = -1;
	@:noCompletion private var __bgfxCopyProgram:Int = -1;
	@:noCompletion private var __bgfxCopySampler:Int = -1;
	@:noCompletion private var __bgfxCopyLayout:BGFXVertexLayout;
	@:noCompletion private var __bgfxCopyVerts:Float32Array;

	// frame-scoped transient slot shared across draws with identical
	// constant attribute values (static: bgfx slots are global per frame)
	@:noCompletion private static var __bgfxExtraSlot:Int = -1;
	@:noCompletion private static var __bgfxExtraSlotKey:String;

	@:noCompletion private function __bgfxTargetFrameBuffer():Int
	{
		if (__state.renderToTexture != null)
		{
			return __state.renderToTexture.__getBGFXFrameBuffer(__state.renderToTextureDepthStencil, __state.renderToTextureAntiAlias,
				__state.renderToTextureSurfaceSelector);
		}

		// the primary display renders offscreen (composited at present) so
		// complex blends can snapshot the target — the backbuffer cannot be
		// blitted from
		if (__stage3D == null && __bgfxMainFrameBuffer != -1) return __bgfxMainFrameBuffer;

		return __state.__bgfxPrimaryFrameBuffer;
	}

	/** (re)creates the offscreen main target + blend snapshot texture **/
	@:noCompletion private function __bgfxEnsureMainTarget(width:Int, height:Int):Void
	{
		if (width <= 0 || height <= 0) return;
		if (__bgfxMainFrameBuffer != -1 && width == __bgfxMainWidth && height == __bgfxMainHeight) return;

		if (__bgfxMainFrameBuffer != -1) BGFX.destroyFrameBuffer(__bgfxMainFrameBuffer);
		if (__bgfxMainColor != -1) BGFX.destroyTexture(__bgfxMainColor);
		if (__bgfxMainDepth != -1) BGFX.destroyTexture(__bgfxMainDepth);
		if (__bgfxGrabTexture != -1) BGFX.destroyTexture(__bgfxGrabTexture);

		__bgfxMainWidth = width;
		__bgfxMainHeight = height;
		__bgfxMainColor = BGFX.createTexture2D(width, height, false, 1, BGRA8, BGFX.TEXTURE_RT_HI, BGFX.SAMPLER_UV_CLAMP);
		__bgfxMainDepth = BGFX.createTexture2D(width, height, false, 1, D24S8, BGFX.TEXTURE_RT_HI, 0);
		__bgfxMainFrameBuffer = BGFX.createFrameBufferFromTextures(__bgfxMainColor, __bgfxMainDepth);
		__bgfxGrabTexture = BGFX.createTexture2D(width, height, false, 1, BGRA8, BGFX.TEXTURE_BLIT_DST_HI, BGFX.SAMPLER_UV_CLAMP);
	}

	/** draws the offscreen main target to the real backbuffer **/
	@:noCompletion private function __bgfxComposite():Void
	{
		if (__bgfxMainFrameBuffer == -1 || __bgfxMainColor == -1) return;

		if (__bgfxCopyProgram == -1)
		{
			var varyingDef = "vec2 v_texcoord0 : TEXCOORD0;\n" + "vec2 a_position : POSITION;\n" + "vec2 a_texcoord0 : TEXCOORD0;\n";
			var vsSource = "$input a_position, a_texcoord0\n" + "$output v_texcoord0\n" + "#include <bgfx_shader.sh>\n" + "void main() {\n"
				+ "\tgl_Position = vec4(a_position, 0.0, 1.0);\n" + "\tv_texcoord0 = a_texcoord0;\n" + "}\n";
			var fsSource = "$input v_texcoord0\n" + "#include <bgfx_shader.sh>\n" + "SAMPLER2D(s_openflMain, 0);\n" + "void main() {\n"
				+ "\tgl_FragColor = texture2D(s_openflMain, v_texcoord0);\n" + "}\n";

			var vs = BGFX.compileShader(vsSource, "v", null, null, varyingDef);
			var fs = vs != null ? BGFX.compileShader(fsSource, "f", null, null, varyingDef) : null;
			if (fs == null) return;

			__bgfxCopyProgram = BGFX.createProgram(BGFX.createShader(vs), BGFX.createShader(fs), true);
			__bgfxCopySampler = BGFX.createUniform("s_openflMain", SAMPLER, 1);

			__bgfxCopyLayout = new BGFXVertexLayout();
			__bgfxCopyLayout.begin().add(POSITION, 2, FLOAT).add(TEXCOORD0, 2, FLOAT).end();

			// fullscreen triangle; GL render-to-texture is stored bottom-up,
			// so flip V there
			var top = BGFX.getCapsOriginBottomLeft() ? 1.0 : 0.0;
			var bottomOver = BGFX.getCapsOriginBottomLeft() ? -1.0 : 2.0;

			__bgfxCopyVerts = new Float32Array(12);
			__bgfxCopyVerts[0] = -1.0; __bgfxCopyVerts[1] = 1.0;  __bgfxCopyVerts[2] = 0.0; __bgfxCopyVerts[3] = top;
			__bgfxCopyVerts[4] = -1.0; __bgfxCopyVerts[5] = -3.0; __bgfxCopyVerts[6] = 0.0; __bgfxCopyVerts[7] = bottomOver;
			__bgfxCopyVerts[8] = 3.0;  __bgfxCopyVerts[9] = 1.0;  __bgfxCopyVerts[10] = 2.0; __bgfxCopyVerts[11] = top;
		}

		var view = __bgfxNextViewId < 255 ? __bgfxNextViewId++ : 255;
		BGFX.setViewMode(view, SEQUENTIAL);
		BGFX.setViewFrameBuffer(view, BGFX.INVALID_HANDLE);
		BGFX.setViewRect(view, 0, 0, Std.int(__stage.window.width * __stage.window.scale), Std.int(__stage.window.height * __stage.window.scale));
		BGFX.setViewScissor(view, 0, 0, 0, 0);
		BGFX.setViewClear(view, BGFX.CLEAR_NONE, 0);

		BGFX.setState(0, BGFX.STATE_WRITE_RGB_LO | BGFX.STATE_WRITE_A_LO);
		BGFX.setTexture(0, __bgfxCopySampler, #if openfl_bgfx_show_grab __bgfxGrabTexture #else (__bgfxDebugTex != -1 ? __bgfxDebugTex : __bgfxMainColor) #end,
			BGFX.SAMPLER_UV_CLAMP);

		if (BGFX.setTransientVertexBuffer(0, __bgfxCopyVerts, 3, __bgfxCopyLayout) == 3)
		{
			BGFX.submit(view, __bgfxCopyProgram);
		}
		else
		{
			BGFX.discard();
		}
	}

	@:noCompletion private function __bgfxEnsureView(clearFlags:Int = 0, clearColor:Int = 0, clearDepth:Float = 1, clearStencil:Int = 0,
			useScissor:Bool = false):Void
	{
		var frameBuffer = __bgfxTargetFrameBuffer();

		if (__bgfxViewValid && frameBuffer == __bgfxCurrentFrameBuffer && clearFlags == 0) return;

		__bgfxViewId = __bgfxNextViewId < 255 ? __bgfxNextViewId++ : 255;
		__bgfxCurrentFrameBuffer = frameBuffer;
		__bgfxViewValid = true;

		BGFX.setViewMode(__bgfxViewId, SEQUENTIAL);
		BGFX.setViewFrameBuffer(__bgfxViewId, frameBuffer == -1 ? BGFX.INVALID_HANDLE : frameBuffer);

		var x = 0, y = 0, width = 0, height = 0;

		if (__state.renderToTexture != null)
		{
			if ((__state.renderToTexture is Texture))
			{
				var texture2D:Texture = cast __state.renderToTexture;
				width = texture2D.__width;
				height = texture2D.__height;
			}
			else if ((__state.renderToTexture is RectangleTexture))
			{
				var rectTexture:RectangleTexture = cast __state.renderToTexture;
				width = rectTexture.__width;
				height = rectTexture.__height;
			}
			else if ((__state.renderToTexture is CubeTexture))
			{
				var cubeTexture:CubeTexture = cast __state.renderToTexture;
				width = cubeTexture.__size;
				height = cubeTexture.__size;
			}
		}
		else if (__stage.context3D == this)
		{
			width = backBufferWidth;
			height = backBufferHeight;
			#if !openfl_dpi_aware
			if (__stage3D == null && !__backBufferWantsBestResolution)
			{
				width = Std.int(backBufferWidth * __stage.window.scale);
				height = Std.int(backBufferHeight * __stage.window.scale);
			}
			#end
			x = __stage3D == null ? 0 : Std.int(__stage3D.x);
			y = __stage3D == null ? 0 : Std.int(__stage3D.y);
		}
		else
		{
			width = backBufferWidth;
			height = backBufferHeight;
		}

		if (width <= 0 || height <= 0)
		{
			width = Std.int(__stage.window.width * __stage.window.scale);
			height = Std.int(__stage.window.height * __stage.window.scale);
		}

		BGFX.setViewRect(__bgfxViewId, x, y, width, height);

		if (useScissor && __state.scissorEnabled)
		{
			BGFX.setViewScissor(__bgfxViewId, Std.int(__state.scissorRectangle.x), Std.int(__state.scissorRectangle.y),
				Std.int(__state.scissorRectangle.width), Std.int(__state.scissorRectangle.height));
		}
		else
		{
			BGFX.setViewScissor(__bgfxViewId, 0, 0, 0, 0);
		}

		// view state is consumed once per view at frame time: the clear runs
		// before this view's draws, and later views (fresh ids) don't clear
		BGFX.setViewClear(__bgfxViewId, clearFlags, clearColor, clearDepth, clearStencil);

		if (clearFlags != 0)
		{
			BGFX.touch(__bgfxViewId);
		}
	}

	@:noCompletion private static function __bgfxBlendFactor(factor:Context3DBlendFactor):Int
	{
		return switch (factor)
		{
			case DESTINATION_ALPHA: BGFX.STATE_BLEND_DST_ALPHA_LO;
			case DESTINATION_COLOR: BGFX.STATE_BLEND_DST_COLOR_LO;
			case ONE: BGFX.STATE_BLEND_ONE_LO;
			case ONE_MINUS_DESTINATION_ALPHA: BGFX.STATE_BLEND_INV_DST_ALPHA_LO;
			case ONE_MINUS_DESTINATION_COLOR: BGFX.STATE_BLEND_INV_DST_COLOR_LO;
			case ONE_MINUS_SOURCE_ALPHA: BGFX.STATE_BLEND_INV_SRC_ALPHA_LO;
			case ONE_MINUS_SOURCE_COLOR: BGFX.STATE_BLEND_INV_SRC_COLOR_LO;
			case SOURCE_ALPHA: BGFX.STATE_BLEND_SRC_ALPHA_LO;
			case SOURCE_COLOR: BGFX.STATE_BLEND_SRC_COLOR_LO;
			case ZERO: BGFX.STATE_BLEND_ZERO_LO;
			default: BGFX.STATE_BLEND_ONE_LO;
		}
	}

	@:noCompletion private static function __bgfxDepthTest(mode:Context3DCompareMode):Int
	{
		return switch (mode)
		{
			case ALWAYS: BGFX.STATE_DEPTH_TEST_ALWAYS_LO;
			case EQUAL: BGFX.STATE_DEPTH_TEST_EQUAL_LO;
			case GREATER: BGFX.STATE_DEPTH_TEST_GREATER_LO;
			case GREATER_EQUAL: BGFX.STATE_DEPTH_TEST_GEQUAL_LO;
			case LESS: BGFX.STATE_DEPTH_TEST_LESS_LO;
			case LESS_EQUAL: BGFX.STATE_DEPTH_TEST_LEQUAL_LO;
			case NEVER: BGFX.STATE_DEPTH_TEST_NEVER_LO;
			case NOT_EQUAL: BGFX.STATE_DEPTH_TEST_NOTEQUAL_LO;
			default: BGFX.STATE_DEPTH_TEST_ALWAYS_LO;
		}
	}

	@:noCompletion private static function __bgfxStencilTest(mode:Context3DCompareMode):Int
	{
		return switch (mode)
		{
			case ALWAYS: BGFX.STENCIL_TEST_ALWAYS;
			case EQUAL: BGFX.STENCIL_TEST_EQUAL;
			case GREATER: BGFX.STENCIL_TEST_GREATER;
			case GREATER_EQUAL: BGFX.STENCIL_TEST_GEQUAL;
			case LESS: BGFX.STENCIL_TEST_LESS;
			case LESS_EQUAL: BGFX.STENCIL_TEST_LEQUAL;
			case NEVER: BGFX.STENCIL_TEST_NEVER;
			case NOT_EQUAL: BGFX.STENCIL_TEST_NOTEQUAL;
			default: BGFX.STENCIL_TEST_ALWAYS;
		}
	}

	@:noCompletion private static function __bgfxStencilOp(action:Context3DStencilAction):Int
	{
		return switch (action)
		{
			case DECREMENT_SATURATE: BGFX.STENCIL_OP_DECRSAT;
			case DECREMENT_WRAP: BGFX.STENCIL_OP_DECR;
			case INCREMENT_SATURATE: BGFX.STENCIL_OP_INCRSAT;
			case INCREMENT_WRAP: BGFX.STENCIL_OP_INCR;
			case INVERT: BGFX.STENCIL_OP_INVERT;
			case KEEP: BGFX.STENCIL_OP_KEEP;
			case SET: BGFX.STENCIL_OP_REPLACE;
			case ZERO: BGFX.STENCIL_OP_ZERO;
			default: BGFX.STENCIL_OP_KEEP;
		}
	}

	// registration entry points used by ShaderParameter/Shader

	@:noCompletion private function __bgfxSetVertexBufferAt(index:Int, buffer:VertexBuffer3D, byteOffset:Int, format:Context3DVertexBufferFormat):Void
	{
		if (index < 0 || index > 15) return;

		__bgfxAttribBuffers[index] = buffer;
		__bgfxAttribOffsets[index] = byteOffset;
		__bgfxAttribFormats[index] = format;
		__bgfxAttribConstants[index] = null;
		__bgfxAttribParamLengths[index] = 0;
	}

	@:noCompletion private function __bgfxSetConstantAttrib(index:Int, values:Array<Float>):Void
	{
		if (index < 0 || index > 15) return;

		__bgfxAttribBuffers[index] = null;
		__bgfxAttribConstants[index] = values;
		__bgfxAttribParamLengths[index] = 0;
	}

	@:noCompletion private function __bgfxSetParamAttrib(index:Int, position:Int, length:Int):Void
	{
		if (index < 0 || index > 15) return;

		__bgfxAttribBuffers[index] = null;
		__bgfxAttribConstants[index] = null;
		__bgfxAttribParamPositions[index] = position;
		__bgfxAttribParamLengths[index] = length;
	}

	@:noCompletion private function __bgfxSetParamData(data:Float32Array):Void
	{
		__bgfxParamData = data;
	}

	@:noCompletion private function __bgfxFormatComponents(format:Context3DVertexBufferFormat):Int
	{
		return switch (format)
		{
			case BYTES_4, FLOAT_4: 4;
			case FLOAT_3: 3;
			case FLOAT_2: 2;
			case FLOAT_1: 1;
			default: 4;
		}
	}

	@:noCompletion private function __bgfxDraw(indexBuffer:IndexBuffer3D, firstIndex:Int, count:Int):Void
	{
		#if !openfl_disable_display_render
		if (__state.renderToTexture == null)
		{
			if (__stage.context3D == this && !__stage.__renderer.__cleared)
			{
				__stage.__renderer.__clear();
			}
			else if (!__cleared)
			{
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}
		}
		#end

		var program = __state.program;
		if (program == null || program.__bgfxProgram == -1) return;
		if (__state.culling == FRONT_AND_BACK) return; // bgfx cannot cull both faces

		// complex (KHR-advanced) blend: snapshot the target and blend in the
		// fragment shader via a program variant
		var complexProgram = -1;

		if (__usingComplexBlend && __bgfxComplexBlend != 0 && __state.renderToTexture == null && __stage3D == null && __bgfxMainColor != -1
			&& __bgfxNextViewId < 250)
		{
			complexProgram = program.__bgfxGetComplexProgram(__bgfxComplexBlend);
		}

		if (complexProgram != -1)
		{
			// snapshot the target into the grab texture. The blit is keyed to
			// this draw's own (fresh) view: bgfx executes view-keyed blits
			// right before that view's render pass, i.e. after all earlier
			// views' draws — exactly the ordering we need.
			__bgfxViewValid = false;
			__bgfxEnsureView();
			BGFX.blit(__bgfxViewId, __bgfxGrabTexture, 0, 0, __bgfxMainColor, 0, 0, __bgfxMainWidth, __bgfxMainHeight);
		}

		__bgfxEnsureView();

		// ---- render state ----

		var lo = 0, hi = 0;

		if (__state.colorMaskRed) lo |= BGFX.STATE_WRITE_R_LO;
		if (__state.colorMaskGreen) lo |= BGFX.STATE_WRITE_G_LO;
		if (__state.colorMaskBlue) lo |= BGFX.STATE_WRITE_B_LO;
		if (__state.colorMaskAlpha) lo |= BGFX.STATE_WRITE_A_LO;

		if (complexProgram == -1)
		{
			lo |= BGFX.blendFunctionSeparate(__bgfxBlendFactor(__state.blendSourceRGBFactor), __bgfxBlendFactor(__state.blendDestinationRGBFactor),
				__bgfxBlendFactor(__state.blendSourceAlphaFactor), __bgfxBlendFactor(__state.blendDestinationAlphaFactor));

			// blend equation set through __setGLBlendEquation (MIN/MAX/SUB/REVSUB)
			hi |= __bgfxBlendEquationHi;
			lo |= __bgfxBlendEquationLo;
		}
		// else: blending off — the shader variant writes the blended result

		var depthStencilEnabled = (__state.renderToTexture != null) ? __state.renderToTextureDepthStencil : __state.backBufferEnableDepthAndStencil;

		if (depthStencilEnabled)
		{
			if (__state.depthMask) hi |= BGFX.STATE_WRITE_Z_HI;
			lo |= __bgfxDepthTest(__state.depthCompareMode);
		}

		// GL path used frontFace(CW) for the primary back buffer and CCW for
		// render-to-texture; mirror by swapping the bgfx winding
		var frontIsCW = (__state.renderToTexture == null && __stage.context3D == this);

		switch (__state.culling)
		{
			case BACK:
				hi |= frontIsCW ? BGFX.STATE_CULL_CCW_HI : BGFX.STATE_CULL_CW_HI;
			case FRONT:
				hi |= frontIsCW ? BGFX.STATE_CULL_CW_HI : BGFX.STATE_CULL_CCW_HI;
			default:
		}

		BGFX.setState(hi, lo);

		// ---- stencil ----

		if (depthStencilEnabled
			&& (__state.stencilCompareMode != ALWAYS || __state.stencilPass != KEEP || __state.stencilFail != KEEP || __state.stencilDepthFail != KEEP))
		{
			var stencil = __bgfxStencilTest(__state.stencilCompareMode)
				| ((__state.stencilReferenceValue & 0xFF) << BGFX.STENCIL_FUNC_REF_SHIFT)
				| ((__state.stencilReadMask & 0xFF) << BGFX.STENCIL_FUNC_RMASK_SHIFT)
				| (__bgfxStencilOp(__state.stencilFail) << BGFX.STENCIL_OP_FAIL_S_SHIFT)
				| (__bgfxStencilOp(__state.stencilDepthFail) << BGFX.STENCIL_OP_FAIL_Z_SHIFT)
				| (__bgfxStencilOp(__state.stencilPass) << BGFX.STENCIL_OP_PASS_Z_SHIFT);

			BGFX.setStencil(stencil, stencil);
		}

		// ---- scissor ----

		if (__state.scissorEnabled)
		{
			var scissorX = Std.int(__state.scissorRectangle.x);
			var scissorY = Std.int(__state.scissorRectangle.y);
			var scissorWidth = Std.int(__state.scissorRectangle.width);
			var scissorHeight = Std.int(__state.scissorRectangle.height);
			#if !openfl_dpi_aware
			if (__backBufferWantsBestResolution)
			{
				scissorX = Std.int(__state.scissorRectangle.x * __stage.window.scale);
				scissorY = Std.int(__state.scissorRectangle.y * __stage.window.scale);
				scissorWidth = Std.int(__state.scissorRectangle.width * __stage.window.scale);
				scissorHeight = Std.int(__state.scissorRectangle.height * __stage.window.scale);
			}
			#end

			// bgfx scissor origin is top-left (no y flip, unlike GL)
			if (scissorWidth > 0 && scissorHeight > 0)
			{
				BGFX.setScissor(scissorX, scissorY, scissorWidth, scissorHeight);
			}
		}

		// ---- textures ----

		if (complexProgram != -1)
		{
			// bind the target snapshot for the shader-side blend (before the
			// user stages: some backends resolve bind state in stage order)
			BGFX.setTexture(program.__bgfxDstSamplerStage, program.__bgfxDstSampler, __bgfxGrabTexture,
				BGFX.SAMPLER_UV_CLAMP | BGFX.SAMPLER_POINT);
		}

		if (program.__bgfxSamplerHandles != null)
		{
			for (i in 0...program.__bgfxSamplerHandles.length)
			{
				var texture = __state.textures[i];

				if (texture != null)
				{
					texture.__ensureBGFXTexture();

					var samplerState = __state.samplerStates[i];
					if (samplerState != null) texture.__setSamplerState(samplerState);

					if (texture.__bgfxTexture != -1)
					{
						BGFX.setTexture(i, program.__bgfxSamplerHandles[i], texture.__bgfxTexture, texture.__bgfxSamplerFlags);
					}
				}
			}
		}

		// ---- uniforms ----

		program.__bgfxFlushUniforms();

		// ---- vertex streams ----

		// non-indexed draws (GL drawArrays semantics) read vertices
		// [firstIndex, firstIndex + count); indexed draws use the whole pool
		var firstVertex = indexBuffer == null ? firstIndex : 0;
		var vertexLimit = indexBuffer == null ? count : -1;

		if (!__bgfxBindVertexStreams(program, firstVertex, vertexLimit))
		{
			// abandon the draw cleanly so half-set encoder state (streams,
			// textures, render state) cannot leak into the next submit
			BGFX.discard();
			return;
		}

		// ---- indices + submit ----

		if (indexBuffer != null && indexBuffer.__bgfxData != null)
		{
			if (firstIndex + count > indexBuffer.__bgfxDataLength) count = indexBuffer.__bgfxDataLength - firstIndex;

			if (count <= 0)
			{
				BGFX.discard();
				return;
			}

			// transient copy of the used range (immediate upload semantics)
			var indexView = new openfl.utils._internal.UInt16Array(indexBuffer.__bgfxData.buffer, firstIndex * 2, count);

			if (BGFX.setTransientIndexBuffer(indexView, count) < count)
			{
				BGFX.discard();
				return;
			}
		}

		BGFX.submit(__bgfxViewId, complexProgram != -1 ? complexProgram : program.__bgfxProgram);
	}

	/**
		Binds stream 0 from the VertexBuffer3D attribute bindings (all bound
		buffers must share one VertexBuffer3D), and stream 1 as a transient
		buffer interleaving constant attributes and ShaderBuffer param data.
	**/
	@:noCompletion private function __bgfxBindVertexStreams(program:Program3D, firstVertex:Int = 0, vertexLimit:Int = -1):Bool
	{
		var translated = program.__bgfxTranslated;
		if (translated == null) return false;

		var attribCount = translated.attribNames.length;
		var mainBuffer:VertexBuffer3D = null;
		var extraFloats = 0;
		var numVertices = 0;

		for (i in 0...attribCount)
		{
			if (__bgfxAttribBuffers[i] != null)
			{
				if (mainBuffer == null) mainBuffer = __bgfxAttribBuffers[i];
				else if (mainBuffer != __bgfxAttribBuffers[i]) return false; // multi-buffer draws unsupported

				var available = Std.int(mainBuffer.__bgfxDataLength / mainBuffer.__vertexSize);
				if (available > numVertices) numVertices = available;
			}
			else if (__bgfxAttribParamLengths[i] > 0)
			{
				extraFloats += __bgfxAttribParamLengths[i];
			}
			else
			{
				// constant (or unbound → zero constant)
				extraFloats += translated.attribComponents[i];
			}
		}

		if (numVertices == 0 && __bgfxParamData != null)
		{
			// pure ShaderBuffer draw: derive the vertex count from the
			// tightest param attribute
			for (i in 0...attribCount)
			{
				if (__bgfxAttribParamLengths[i] > 0)
				{
					var available = Std.int((__bgfxParamData.length - __bgfxAttribParamPositions[i]) / __bgfxAttribParamLengths[i]);
					if (numVertices == 0 || available < numVertices) numVertices = available;
				}
			}
		}

		if (vertexLimit > 0 && firstVertex + vertexLimit <= numVertices) numVertices = vertexLimit;
		else firstVertex = 0;

		if (numVertices == 0) return false;

		var stream = 0;

		// stream 0: the main vertex buffer with a layout matching the
		// current attribute bindings. Stage3D bufferOffset can address any
		// vertex (chunked draws pass start-of-chunk offsets), while bgfx
		// layout offsets are within-vertex uint16s: split the smallest
		// stride-aligned offset off as a base vertex.
		if (mainBuffer != null)
		{
			if (mainBuffer.__bgfxData == null) return false;

			var strideBytes = mainBuffer.__stride;
			var order:Array<Int> = [];
			var minOffset = 0x7FFFFFFF;

			for (i in 0...attribCount)
			{
				if (__bgfxAttribBuffers[i] == mainBuffer)
				{
					order.push(i);
					if (__bgfxAttribOffsets[i] < minOffset) minOffset = __bgfxAttribOffsets[i];
				}
			}

			var baseVertex = Std.int(minOffset / strideBytes);

			var key = new StringBuf();
			key.add(strideBytes);

			for (i in order)
			{
				var relative = __bgfxAttribOffsets[i] - baseVertex * strideBytes;
				if (relative < 0 || relative >= strideBytes) return false; // attributes span chunks

				key.add(";");
				key.add(i);
				key.add(",");
				key.add(translated.attribSemantics[i]);
				key.add(",");
				key.add(relative);
				key.add(",");
				key.add(__bgfxAttribFormats[i] == BYTES_4 ? "b" : "f");
				key.add(__bgfxFormatComponents(__bgfxAttribFormats[i]));
			}

			var keyString = key.toString();
			var layout = __bgfxLayoutObjects.get(keyString);

			if (layout == null)
			{
				order.sort(function(a, b) return __bgfxAttribOffsets[a] - __bgfxAttribOffsets[b]);

				layout = new BGFXVertexLayout();
				layout.begin();

				var position = 0;

				for (i in order)
				{
					var offset = __bgfxAttribOffsets[i] - baseVertex * strideBytes;
					if (offset < position) return false; // overlapping attributes
					if (offset > position) layout.skip(offset - position);

					var components = __bgfxFormatComponents(__bgfxAttribFormats[i]);

					if (__bgfxAttribFormats[i] == BYTES_4)
					{
						layout.add(translated.attribSemantics[i], 4, UINT8, true);
						position = offset + 4;
					}
					else
					{
						layout.add(translated.attribSemantics[i], components, FLOAT);
						position = offset + components * 4;
					}
				}

				if (position < strideBytes) layout.skip(strideBytes - position);
				layout.end();

				__bgfxLayoutObjects.set(keyString, layout);
			}

			// vertices available past the base; indices are chunk-relative.
			// Indexed draws use 16-bit indices, so nothing past 65536 vertices
			// is addressable — clamping keeps transient pool usage bounded
			var startVertex = baseVertex + firstVertex;
			var available = Std.int(mainBuffer.__bgfxDataLength / mainBuffer.__vertexSize) - startVertex;
			if (available <= 0) return false;
			if (available > 65536) available = 65536;

			numVertices = (vertexLimit > 0 && vertexLimit <= available) ? vertexLimit : available;

			// transient copy of the CPU-side data (immediate upload semantics)
			var vertexData:Float32Array = startVertex > 0 ? new Float32Array(mainBuffer.__bgfxData.buffer, startVertex * strideBytes,
				numVertices * mainBuffer.__vertexSize) : mainBuffer.__bgfxData;

			if (BGFX.setTransientVertexBuffer(stream, vertexData, numVertices, layout) < numVertices) return false;
			stream++;
		}

		// stream 1: interleaved transient data for constant attributes and
		// ShaderBuffer params
		if (extraFloats > 0)
		{
			var extraKey = new StringBuf();
			extraKey.add("x");

			var extras:Array<Int> = [];
			var allConstants = true;

			for (i in 0...attribCount)
			{
				if (__bgfxAttribBuffers[i] == null)
				{
					extras.push(i);
					var length = __bgfxAttribParamLengths[i] > 0 ? __bgfxAttribParamLengths[i] : translated.attribComponents[i];
					if (__bgfxAttribParamLengths[i] > 0) allConstants = false;
					extraKey.add(";");
					extraKey.add(translated.attribSemantics[i]);
					extraKey.add(",");
					extraKey.add(length);
				}
			}

			var extraKeyString = extraKey.toString();
			var extraLayout = __bgfxLayoutObjects.get(extraKeyString);

			if (extraLayout == null)
			{
				extraLayout = new BGFXVertexLayout();
				extraLayout.begin();

				for (i in extras)
				{
					var length = __bgfxAttribParamLengths[i] > 0 ? __bgfxAttribParamLengths[i] : translated.attribComponents[i];
					extraLayout.add(translated.attribSemantics[i], length, FLOAT);
				}

				extraLayout.end();
				__bgfxLayoutObjects.set(extraKeyString, extraLayout);
			}

			// all-constants extra streams are identical for every chunk of a
			// batched draw (and usually across draws): allocate once per
			// frame per (values, count) and rebind the slot
			var slotKey:String = null;

			if (allConstants)
			{
				var valueKey = new StringBuf();
				valueKey.add(extraKeyString);
				valueKey.add("|");
				valueKey.add(numVertices);

				for (i in extras)
				{
					var constant = __bgfxAttribConstants[i];
					valueKey.add("|");
					if (constant != null) for (value in constant)
					{
						valueKey.add(value);
						valueKey.add(",");
					}
				}

				slotKey = valueKey.toString();

				if (slotKey == __bgfxExtraSlotKey && __bgfxExtraSlot != -1)
				{
					BGFX.setTransientVertexBufferSlot(stream, __bgfxExtraSlot);
					return true;
				}
			}

			var strideFloats = 0;
			for (i in extras)
			{
				strideFloats += __bgfxAttribParamLengths[i] > 0 ? __bgfxAttribParamLengths[i] : translated.attribComponents[i];
			}

			var totalFloats = strideFloats * numVertices;

			if (__bgfxScratch == null || __bgfxScratch.length < totalFloats)
			{
				__bgfxScratch = new Float32Array(totalFloats);
			}

			var write = 0;

			for (v in 0...numVertices)
			{
				for (i in extras)
				{
					if (__bgfxAttribParamLengths[i] > 0)
					{
						var length = __bgfxAttribParamLengths[i];
						var read = __bgfxAttribParamPositions[i] + (firstVertex + v) * length;

						// the staged param buffer can hold fewer vertices than the
						// main vertex buffer being drawn (e.g. param data left over
						// from a previous, smaller draw): read past its end as zero
						// instead of dereferencing out of bounds and crashing
						var avail = __bgfxParamData != null ? __bgfxParamData.length : 0;
						for (c in 0...length)
						{
							__bgfxScratch[write++] = (read + c < avail) ? __bgfxParamData[read + c] : 0;
						}
					}
					else
					{
						var constant = __bgfxAttribConstants[i];
						var length = translated.attribComponents[i];

						for (c in 0...length)
						{
							__bgfxScratch[write++] = (constant != null && c < constant.length) ? constant[c] : 0;
						}
					}
				}
			}

			if (allConstants)
			{
				var slot = BGFX.allocTransientVertexBufferSlot(__bgfxScratch, numVertices, extraLayout);
				if (slot == -1) return false;

				__bgfxExtraSlot = slot;
				__bgfxExtraSlotKey = slotKey;
				BGFX.setTransientVertexBufferSlot(stream, slot);
			}
			else
			{
				if (BGFX.setTransientVertexBuffer(stream, __bgfxScratch, numVertices, extraLayout) < numVertices) return false;
			}
		}

		return true;
	}
	#end

	// Get & Set Methods
	@:noCompletion private function get_enableErrorChecking():Bool
	{
		return __enableErrorChecking;
	}

	@:noCompletion private function set_enableErrorChecking(value:Bool):Bool
	{
		return __enableErrorChecking = value;
	}

	@:noCompletion private function get_totalGPUMemory():Int
	{
		if (__glMemoryCurrentAvailable != -1)
		{
			// TODO: Return amount used by this application only
			var current = gl.getParameter(__glMemoryCurrentAvailable);
			var total = gl.getParameter(__glMemoryTotalAvailable);

			if (total > 0)
			{
				return (total - current) * 1024;
			}
		}
		return 0;
	}
}
