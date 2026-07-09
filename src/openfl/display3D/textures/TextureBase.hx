package openfl.display3D.textures;

import openfl.display3D._internal.GLFramebuffer;
import openfl.display3D._internal.GLRenderbuffer;
import openfl.display3D._internal.GLTexture;
import openfl.display3D._internal.ATFGPUFormat;
import openfl.display._internal.SamplerState;
import openfl.display.BitmapData;
import openfl.events.EventDispatcher;
import openfl.errors.Error;
import openfl.utils._internal.Log;
#if lime
import lime._internal.graphics.ImageCanvasUtil;
import lime.graphics.Image;
import lime.graphics.RenderContext;
#end
#if (lime && !js)
import lime.graphics.bgfx.BGFX;
import lime.graphics.bgfx.BGFXVertexLayout.BGFXTextureFormat;
#end

/**
	The TextureBase class is the base class for Context3D texture objects.

	**Note:** You cannot create your own texture classes using TextureBase. To add
	functionality to a texture class, extend either Texture or CubeTexture instead.
**/
@:access(openfl.display._internal.SamplerState)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Stage)
class TextureBase extends EventDispatcher
{
	@:noCompletion private static var __compressedFormats:Map<Int, Int>;
	@:noCompletion private static var __compressedFormatsAlpha:Map<Int, Int>;
	@:noCompletion private static var __supportsBGRA:Null<Bool> = null;
	@:noCompletion private static var __textureFormat:Int;
	@:noCompletion private static var __textureInternalFormat:Int;

	@:noCompletion private var __alphaTexture:TextureBase;
	// private var __compressedMemoryUsage:Int;
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __format:Int;
	@:noCompletion private var __glDepthRenderbuffer:GLRenderbuffer;
	@:noCompletion private var __glFramebuffer:GLFramebuffer;
	@:noCompletion private var __glStencilRenderbuffer:GLRenderbuffer;
	@:noCompletion private var __height:Int;
	@:noCompletion private var __internalFormat:Int;
	// private var __memoryUsage:Int;
	@:noCompletion private var __optimizeForRenderToTexture:Bool;
	// private var __outputTextureMemoryUsage:Bool = false;
	@:noCompletion private var __samplerState:SamplerState;
	@:noCompletion private var __streamingLevels:Int;
	@SuppressWarnings("checkstyle:Dynamic") @:noCompletion private var __textureContext:#if lime RenderContext #else Dynamic #end;
	@:noCompletion private var __textureID:GLTexture;
	@:noCompletion private var __textureTarget:Int;
	@:noCompletion private var __width:Int;

	#if (lime && !js)
	// BGFX texture state (native): handle created lazily so render targets
	// can get the RT flag before creation
	@:noCompletion private var __bgfxTexture:Int = -1;
	@:noCompletion private var __bgfxDepthTexture:Int = -1;
	@:noCompletion private var __bgfxFrameBuffer:Int = -1;
	@:noCompletion private var __bgfxFrameBufferDepthStencil:Bool = false;
	// OpenFL native BitmapData image data is BGRA premultiplied
	@:noCompletion private var __bgfxFormat:Int = BGFXTextureFormat.BGRA8;
	@:noCompletion private var __bgfxTextureFlagsHi:Int = 0;
	@:noCompletion private var __bgfxIsRenderTarget:Bool = false;
	@:noCompletion private var __bgfxTexWidth:Int = 0;
	@:noCompletion private var __bgfxTexHeight:Int = 0;
	@:noCompletion private var __bgfxSamplerFlags:Int = BGFX.SAMPLER_UV_CLAMP;
	#end

	@:noCompletion private function new(context:Context3D)
	{
		super();

		__context = context;

		#if (lime && !js)
		__textureContext = __context.__context;
		__bgfxIsRenderTarget = false;
		#else
		var gl = __context.gl;
		// __textureTarget = target;

		__textureID = gl.createTexture();
		__textureContext = __context.__context;

		if (__supportsBGRA == null)
		{
			__textureInternalFormat = gl.RGBA;

			var bgraExtension:Dynamic = null;
			#if (!js || !html5)
			bgraExtension = gl.getExtension("EXT_bgra");
			if (bgraExtension == null) bgraExtension = gl.getExtension("EXT_texture_format_BGRA8888");
			if (bgraExtension == null) bgraExtension = gl.getExtension("APPLE_texture_format_BGRA8888");
			#end

			if (bgraExtension != null)
			{
				__supportsBGRA = true;
				__textureFormat = bgraExtension.BGRA_EXT;
				__textureInternalFormat = bgraExtension.BGRA_EXT;
			}
			else
			{
				__supportsBGRA = false;
				__textureFormat = gl.RGBA;
			}

			__compressedFormats = new Map();
			__compressedFormatsAlpha = new Map();

			#if (js && html5)
			var dxtExtension = gl.getExtension("WEBGL_compressed_texture_s3tc");
			var etc1Extension = gl.getExtension("WEBGL_compressed_texture_etc1");
			var etc2Extension = gl.getExtension("WEBGL_compressed_texture_etc");
			// WEBGL_compressed_texture_pvrtc is not available on iOS Safari
			var pvrtcExtension = gl.getExtension("WEBKIT_WEBGL_compressed_texture_pvrtc");
			#else
			var dxtExtension = gl.getExtension("EXT_texture_compression_s3tc");
			var etc1Extension = gl.getExtension("OES_compressed_ETC1_RGB8_texture");
			var pvrtcExtension = gl.getExtension("IMG_texture_compression_pvrtc");
			#end

			if (dxtExtension != null)
			{
				__compressedFormats[ATFGPUFormat.DXT] = dxtExtension.COMPRESSED_RGBA_S3TC_DXT1_EXT;
				__compressedFormatsAlpha[ATFGPUFormat.DXT] = dxtExtension.COMPRESSED_RGBA_S3TC_DXT5_EXT;
			}

			if (etc1Extension != null)
			{
				#if (js && html5)
				__compressedFormats[ATFGPUFormat.ETC1] = etc1Extension.COMPRESSED_RGB_ETC1_WEBGL;
				__compressedFormatsAlpha[ATFGPUFormat.ETC1] = etc1Extension.COMPRESSED_RGB_ETC1_WEBGL;
				#else
				__compressedFormats[ATFGPUFormat.ETC1] = etc1Extension.ETC1_RGB8_OES;
				__compressedFormatsAlpha[ATFGPUFormat.ETC1] = etc1Extension.ETC1_RGB8_OES;
				#end
			}

			#if (js && html5)
			if (etc2Extension != null)
			{
				if ((etc2Extension : Dynamic).COMPRESSED_RGB8_ETC2 != null) __compressedFormats[ATFGPUFormat.ETC2] = (etc2Extension : Dynamic)
					.COMPRESSED_RGB8_ETC2;
				else if ((gl : Dynamic).COMPRESSED_RGB8_ETC2 != null) __compressedFormats[ATFGPUFormat.ETC2] = (gl : Dynamic).COMPRESSED_RGB8_ETC2;

				if ((etc2Extension : Dynamic).COMPRESSED_RGBA8_ETC2_EAC != null) __compressedFormatsAlpha[ATFGPUFormat.ETC2] = (etc2Extension : Dynamic)
					.COMPRESSED_RGBA8_ETC2_EAC;
				else if ((gl : Dynamic).COMPRESSED_RGBA8_ETC2_EAC != null) __compressedFormatsAlpha[ATFGPUFormat.ETC2] = (gl : Dynamic)
					.COMPRESSED_RGBA8_ETC2_EAC;
			}
			else
			{
				// Fallback: WebGL2 ETC2 may not use an extension object
				if ((gl : Dynamic).COMPRESSED_RGB8_ETC2 != null) __compressedFormats[ATFGPUFormat.ETC2] = (gl : Dynamic).COMPRESSED_RGB8_ETC2;
				if ((gl : Dynamic).COMPRESSED_RGBA8_ETC2_EAC != null) __compressedFormatsAlpha[ATFGPUFormat.ETC2] = (gl : Dynamic).COMPRESSED_RGBA8_ETC2_EAC;
			}
			#end

			if (pvrtcExtension != null)
			{
				__compressedFormats[ATFGPUFormat.PVRTC] = pvrtcExtension.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
				__compressedFormatsAlpha[ATFGPUFormat.PVRTC] = pvrtcExtension.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
			}
		}

		__internalFormat = __textureInternalFormat;
		__format = __textureFormat;
		#end

		// __memoryUsage = 0;
		// __compressedMemoryUsage = 0;
	}

	#if (lime && !js)
	/**
		Creates the bgfx texture handle if it does not exist yet, optionally
		promoting it to a render target. Promoting an existing non-RT texture
		recreates the handle blank (callers render into it right afterwards).
	**/
	@:noCompletion private function __ensureBGFXTexture(renderTarget:Bool = false, width:Int = -1, height:Int = -1):Int
	{
		
		if (width < 0) width = __width;
		if (height < 0) height = __height;

		var wantRT = renderTarget || __optimizeForRenderToTexture;
		var needsRecreate = __bgfxTexture != -1 && ((wantRT && !__bgfxIsRenderTarget) || width != __bgfxTexWidth || height != __bgfxTexHeight);

		if (needsRecreate)
		{
			if (__bgfxFrameBuffer != -1)
			{
				BGFX.destroyFrameBuffer(__bgfxFrameBuffer);
				__bgfxFrameBuffer = -1;
			}

			BGFX.destroyTexture(__bgfxTexture);
			__bgfxTexture = -1;
		}

		if (__bgfxTexture == -1 && width > 0 && height > 0)
		{
			__bgfxIsRenderTarget = wantRT;
			__bgfxTexWidth = width;
			__bgfxTexHeight = height;

			var flagsHi = __bgfxTextureFlagsHi | (wantRT ? BGFX.TEXTURE_RT_HI : 0);
			__bgfxTexture = BGFX.createTexture2D(width, height, false, 1, __bgfxFormat, flagsHi, __bgfxSamplerFlags);
		}

		return __bgfxTexture;
	}

	@:noCompletion private function __getBGFXFrameBuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):Int
	{
		

		if (__bgfxFrameBuffer != -1 && enableDepthAndStencil && !__bgfxFrameBufferDepthStencil)
		{
			// depth+stencil requested after the framebuffer was created flat
			BGFX.destroyFrameBuffer(__bgfxFrameBuffer);
			__bgfxFrameBuffer = -1;
		}

		if (__bgfxFrameBuffer == -1)
		{
			__ensureBGFXTexture(true);
			if (__bgfxTexture == -1) return -1;

			if (enableDepthAndStencil && __bgfxDepthTexture == -1)
			{
				__bgfxDepthTexture = BGFX.createTexture2D(__bgfxTexWidth, __bgfxTexHeight, false, 1,
					BGFXTextureFormat.D24S8, BGFX.TEXTURE_RT_HI, 0);
			}

			__bgfxFrameBuffer = BGFX.createFrameBufferFromTextures(__bgfxTexture, enableDepthAndStencil ? __bgfxDepthTexture : -1);
			__bgfxFrameBufferDepthStencil = enableDepthAndStencil;
		}

		return __bgfxFrameBuffer;
	}
	#end

	/**
		Frees all GPU resources associated with this texture. After disposal, calling
		`upload()` or rendering with this object fails.
	**/
	public function dispose():Void
	{
		if (__alphaTexture != null)
		{
			__alphaTexture.dispose();
			__alphaTexture = null;
		}

		#if (lime && !js)
		if (__bgfxFrameBuffer != -1)
		{
			BGFX.destroyFrameBuffer(__bgfxFrameBuffer);
			__bgfxFrameBuffer = -1;
		}

		if (__bgfxDepthTexture != -1)
		{
			BGFX.destroyTexture(__bgfxDepthTexture);
			__bgfxDepthTexture = -1;
		}

		if (__bgfxTexture != -1)
		{
			BGFX.destroyTexture(__bgfxTexture);
			__bgfxTexture = -1;
		}
		#else
		var gl = __context.gl;

		if (__textureID != null)
		{
			gl.deleteTexture(__textureID);
			__textureID = null;
		}

		if (__glFramebuffer != null)
		{
			gl.deleteFramebuffer(__glFramebuffer);
			__glFramebuffer = null;
		}

		if (__glDepthRenderbuffer != null)
		{
			gl.deleteRenderbuffer(__glDepthRenderbuffer);
			__glDepthRenderbuffer = null;
		}

		if (__glStencilRenderbuffer != null)
		{
			gl.deleteRenderbuffer(__glStencilRenderbuffer);
			__glStencilRenderbuffer = null;
		}
		#end
	}

	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private function __getGLFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):GLFramebuffer
	{
		var gl = __context.gl;

		if (__glFramebuffer == null)
		{
			__glFramebuffer = gl.createFramebuffer();
			__context.__bindGLFramebuffer(__glFramebuffer);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, __textureID, 0);

			if (__context.__enableErrorChecking)
			{
				var code = gl.checkFramebufferStatus(gl.FRAMEBUFFER);

				if (code != gl.FRAMEBUFFER_COMPLETE)
				{
					Log.warn('Error: Context3D.setRenderToTexture status:${code} width:${__width} height:${__height}');
				}
			}
		}

		if (enableDepthAndStencil && __glDepthRenderbuffer == null)
		{
			__context.__bindGLFramebuffer(__glFramebuffer);

			if (Context3D.__glDepthStencil != 0)
			{
				__glDepthRenderbuffer = gl.createRenderbuffer();
				__glStencilRenderbuffer = __glDepthRenderbuffer;

				gl.bindRenderbuffer(gl.RENDERBUFFER, __glDepthRenderbuffer);
				gl.renderbufferStorage(gl.RENDERBUFFER, Context3D.__glDepthStencil, __width, __height);
				gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, __glDepthRenderbuffer);
			}
			else
			{
				__glDepthRenderbuffer = gl.createRenderbuffer();
				__glStencilRenderbuffer = gl.createRenderbuffer();

				gl.bindRenderbuffer(gl.RENDERBUFFER, __glDepthRenderbuffer);
				gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, __width, __height);
				gl.bindRenderbuffer(gl.RENDERBUFFER, __glStencilRenderbuffer);
				gl.renderbufferStorage(gl.RENDERBUFFER, gl.STENCIL_INDEX8, __width, __height);

				gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, __glDepthRenderbuffer);
				gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.RENDERBUFFER, __glStencilRenderbuffer);
			}

			if (__context.__enableErrorChecking)
			{
				var code = gl.checkFramebufferStatus(gl.FRAMEBUFFER);

				if (code != gl.FRAMEBUFFER_COMPLETE)
				{
					Log.warn('Error: Context3D.setRenderToTexture status:${code} width:${__width} height:${__height}');
				}
			}

			gl.bindRenderbuffer(gl.RENDERBUFFER, null);
		}

		return __glFramebuffer;
	}

	#if lime
	@:noCompletion private function __getImage(bitmapData:BitmapData):Image
	{
		var image = bitmapData.image;

		if (!bitmapData.__isValid || image == null)
		{
			return null;
		}

		#if (js && html5)
		ImageCanvasUtil.sync(image, false);
		#end

		#if (js && html5)
		var gl = __context.gl;

		if (image.type != DATA && !image.premultiplied)
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
		}
		else if (!image.premultiplied && image.transparent)
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0);
			image = image.clone();
			image.premultiplied = true;
		}

		// TODO: Some way to support BGRA on WebGL?

		if (image.format != RGBA32)
		{
			image = image.clone();
			image.format = RGBA32;
			image.buffer.premultiplied = true;
			#if openfl_power_of_two
			image.powerOfTwo = true;
			#end
		}
		#else
		if (#if openfl_power_of_two !image.powerOfTwo || #end (!image.premultiplied && image.transparent))
		{
			image = image.clone();
			image.premultiplied = true;
			#if openfl_power_of_two
			image.powerOfTwo = true;
			#end
		}
		#end

		return image;
	}
	#end

	@:noCompletion private function __getTexture():GLTexture
	{
		return __textureID;
	}

	@:noCompletion private function __setSamplerState(state:SamplerState):Bool
	{
		#if (lime && !js)
		if (!state.equals(__samplerState))
		{
			// translate to bgfx sampler flags, applied at setTexture time.
			// bgfx cannot generate mipmaps for uploaded textures, so mip
			// filtering degrades to sampling the top level (flags omitted).
			var flags = 0;

			switch (state.wrap)
			{
				case CLAMP:
					flags |= BGFX.SAMPLER_UV_CLAMP;
				case CLAMP_U_REPEAT_V:
					flags |= BGFX.SAMPLER_U_CLAMP;
				case REPEAT_U_CLAMP_V:
					flags |= BGFX.SAMPLER_V_CLAMP;
				case REPEAT:
				default:
			}

			if (state.filter == NEAREST)
			{
				flags |= BGFX.SAMPLER_MIN_POINT | BGFX.SAMPLER_MAG_POINT;
			}

			__bgfxSamplerFlags = flags;

			if (__samplerState == null) __samplerState = state.clone();
			__samplerState.copyFrom(state);

			return true;
		}

		return false;
		#else
		if (!state.equals(__samplerState))
		{
			var gl = __context.gl;

			if (__textureTarget == __context.gl.TEXTURE_CUBE_MAP) __context.__bindGLTextureCubeMap(__textureID);
			else
			{
				__context.__bindGLTexture2D(__textureID);
				if (state.mipfilter != MIPNONE)
				{
					gl.generateMipmap(__textureTarget);
					state.mipmapGenerated = true;
				}
			}

			var wrapModeS = 0, wrapModeT = 0;

			switch (state.wrap)
			{
				case CLAMP:
					wrapModeS = gl.CLAMP_TO_EDGE;
					wrapModeT = gl.CLAMP_TO_EDGE;
				case CLAMP_U_REPEAT_V:
					wrapModeS = gl.CLAMP_TO_EDGE;
					wrapModeT = gl.REPEAT;
				case REPEAT:
					wrapModeS = gl.REPEAT;
					wrapModeT = gl.REPEAT;
				case REPEAT_U_CLAMP_V:
					wrapModeS = gl.REPEAT;
					wrapModeT = gl.CLAMP_TO_EDGE;
				default:
					throw new Error("wrap bad enum");
			}

			var magFilter = 0, minFilter = 0;

			switch (state.filter)
			{
				case NEAREST:
					magFilter = gl.NEAREST;
				default:
					magFilter = gl.LINEAR;
			}

			switch (state.mipfilter)
			{
				case MIPLINEAR:
					minFilter = state.filter == NEAREST ? gl.NEAREST_MIPMAP_LINEAR : gl.LINEAR_MIPMAP_LINEAR;
				case MIPNEAREST:
					minFilter = state.filter == NEAREST ? gl.NEAREST_MIPMAP_NEAREST : gl.LINEAR_MIPMAP_NEAREST;
				case Context3DMipFilter.MIPNONE:
					minFilter = state.filter == NEAREST ? gl.NEAREST : gl.LINEAR;
				default:
					throw new Error("mipfiter bad enum");
			}

			gl.texParameteri(__textureTarget, gl.TEXTURE_MIN_FILTER, minFilter);
			gl.texParameteri(__textureTarget, gl.TEXTURE_MAG_FILTER, magFilter);
			gl.texParameteri(__textureTarget, gl.TEXTURE_WRAP_S, wrapModeS);
			gl.texParameteri(__textureTarget, gl.TEXTURE_WRAP_T, wrapModeT);

			#if lime
			if (__context.__context.type == OPENGL)
			{
				gl.texParameterf(__textureTarget, 0x8501, state.lodBias); // GL_TEXTURE_LOD_BIAS
			}
			#end

			if (__samplerState == null) __samplerState = state.clone();
			__samplerState.copyFrom(state);

			return true;
		}

		return false;
		#end
	}

	#if (lime && !js)
	@:noCompletion private function __uploadFromImage(image:Image):Void
	{
		if (image == null || image.data == null) return;

		__ensureBGFXTexture(false, image.buffer.width, image.buffer.height);
		if (__bgfxTexture == -1) return;

		BGFX.updateTexture2D(__bgfxTexture, 0, 0, 0, 0, image.buffer.width, image.buffer.height, image.data);
	}
	#elseif lime
	@:noCompletion private function __uploadFromImage(image:Image):Void
	{
		var gl = __context.gl;
		var internalFormat:Int;
		var format:Int;

		if (__textureTarget != gl.TEXTURE_2D) return;

		if (image.buffer.bitsPerPixel == 1)
		{
			internalFormat = gl.ALPHA;
			format = gl.ALPHA;
		}
		else
		{
			internalFormat = TextureBase.__textureInternalFormat;
			format = TextureBase.__textureFormat;
		}

		__context.__bindGLTexture2D(__textureID);

		#if (js && html5)
		if (image.type != DATA && !image.premultiplied)
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
		}
		else if (!image.premultiplied && image.transparent)
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
			// gl.pixelStorei (gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0);
			// textureImage = textureImage.clone ();
			// textureImage.premultiplied = true;
		}

		if (image.type == DATA)
		{
			gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, image.buffer.width, image.buffer.height, 0, format, gl.UNSIGNED_BYTE, image.data);
		}
		else
		{
			gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, format, gl.UNSIGNED_BYTE, image.src);
		}
		#else
		gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, image.buffer.width, image.buffer.height, 0, format, gl.UNSIGNED_BYTE, image.data);
		#end

		__context.__bindGLTexture2D(null);
	}
	#end
}
