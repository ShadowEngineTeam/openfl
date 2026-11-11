package openfl.display3D.textures;

import haxe.Int64;
import haxe.io.Bytes;
import lime.graphics.bgfx.BGFXTextureFormat;
import openfl.utils._internal.UInt8Array;
import openfl.display.BlendMode;
import openfl.utils.ByteArray;
import openfl.Lib;
import openfl.display._internal.SamplerState;
import openfl.display3D.Context3D;

/**
	The ASTCTexture class represents a 2-dimensional compressed ASTC texture uploaded to a rendering context.

	Defines a 2D texture for use during rendering.

	ASTCTexture cannot be instantiated directly. Create instances by using Context3D
	`createASTCTexture()` method.
**/
@:access(openfl.display3D.Context3D)
@:final class ASTCTexture extends TextureBase
{
	@:noCompletion private static var __warned:Bool = false;
	@:noCompletion private static var __astcCompressedTexturesSupported:Null<Bool> = null;
	//@:noCompletion private static var __warnedMipmap:Bool = false;
	public static inline final ASTC_MAGIC_NUMBER:Int = 0x5CA1AB13;
	public static inline final IMAGE_DATA_OFFSET = 16;

	public var supported:Bool = true;
	public var imageSize(default, null):Int = 0;
	public var depth(default, null):Int = 0;
	public var blockDimX:Int = -1;
	public var blockDimY:Int = -1;
	public var blockDimZ:Int = -1;

	private var __isSRGB:Bool = false;
	private var __isHDR:Bool = false;

	@:noCompletion private function new(context:Context3D, data:ByteArray, isSRGB:Bool = false, isHDR:Bool = false)
	{
		super(context);

		__isSRGB = isSRGB;
		__isHDR = isHDR;

		if (__context.isBGFX)
		{
			__parseASTCHeader(data);
			if (!supported) return;

			__getImageSize(data);
			__getImageDimensions(data);

			var bgfx = __context.bgfx;
			var bgfxFormat:Int = __getASTCFormat(blockDimX, blockDimY);
			var required:Int = __isSRGB ? bgfx.CAPS_FORMAT_TEXTURE_2D_SRGB : bgfx.CAPS_FORMAT_TEXTURE_2D;

			if (bgfxFormat == BGFXTextureFormat.Unknown || (bgfx.getCaps().formats[bgfxFormat] & required) == 0)
			{
				__showWarning('ASTC ${blockDimX}x${blockDimY} compression is not available on this device.');
				supported = false;
				return;
			}

			__format = bgfxFormat;
			__internalFormat = bgfxFormat;
			__optimizeForRenderToTexture = false;
			__streamingLevels = 0;

			__uploadASTCTextureFromByteArray(data);
			return;
		}

		var gl = __context.gl;

		var astcLdrExtension = gl.getExtension("KHR_texture_compression_astc_ldr");
		var astcHdrExtension = gl.getExtension("KHR_texture_compression_astc_hdr");

		var tokenExtension = astcLdrExtension != null ? astcLdrExtension : astcHdrExtension;

		if (tokenExtension == null)
		{
			__showWarning("ASTC compression (LDR and HDR) is not available on this device.");
			supported = false;
			return;
		}

		if (__isHDR && astcHdrExtension == null)
		{
			__showWarning("ASTC HDR profile is not available on this device; the texture may render incorrectly.");
		}

		__parseASTCHeader(data);
		if (!supported) return;

		__getImageSize(data);
		__getImageDimensions(data);

		var formatName:String = __isSRGB ? 'COMPRESSED_SRGB8_ALPHA8_ASTC_${blockDimX}x${blockDimY}_KHR' : 'COMPRESSED_RGBA_ASTC_${blockDimX}x${blockDimY}_KHR';

		if (!Reflect.fields(tokenExtension).contains(formatName))
		{
			trace('[ERROR] ASTC format: $formatName is invalid or unsupported on this device!');
			supported = false;
			return;
		}
		__format = Reflect.getProperty(tokenExtension, formatName);

		__internalFormat = __format;
		__optimizeForRenderToTexture = false;
		__streamingLevels = 0;

		__uploadASTCTextureFromByteArray(data);
	}

	@:noCompletion public function __uploadASTCTextureFromByteArray(data:ByteArray):Void
	{
		var bytes:Bytes = cast data;
		var textureBytes = new UInt8Array(bytes, IMAGE_DATA_OFFSET, imageSize);

		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__textureID != null)
			{
				bgfx.destroyTexture(__textureID);
				__textureID = null;
			}

			__textureFlags = __isSRGB ? bgfx.TEXTURE_SRGB : Int64.make(0, 0);
			__textureID = bgfx.createTexture2D(__width, __height, false, 1, __internalFormat, __textureFlags, bgfx.copy(textureBytes));
			return;
		}

		var gl = __context.gl;

		__textureTarget = gl.TEXTURE_2D;
		__context.__bindGLTexture2D(__textureID);

		gl.compressedTexImage2D(__textureTarget, 0, __internalFormat, __width, __height, 0, textureBytes);
		gl.texParameteri(__textureTarget, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(__textureTarget, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

		__context.__bindGLTexture2D(null);
	}

	@:noCompletion private function __getImageDimensions(bytes:ByteArray):Void
	{
		bytes.position = 7;

		__width = bytes.readUnsignedByte() | (bytes.readUnsignedByte() << 8) | (bytes.readUnsignedByte() << 16);
		__height = bytes.readUnsignedByte() | (bytes.readUnsignedByte() << 8) | (bytes.readUnsignedByte() << 16);
		depth = bytes.readUnsignedByte() | (bytes.readUnsignedByte() << 8) | (bytes.readUnsignedByte() << 16);
	}

	@:noCompletion private function __getImageSize(bytes:ByteArray):Void
	{
		bytes.position = 4;

		blockDimX = bytes.readUnsignedByte();
		blockDimY = bytes.readUnsignedByte();
		blockDimZ = bytes.readUnsignedByte();

		bytes.position = 7;

		var dimX = bytes.readUnsignedByte() | (bytes.readUnsignedByte() << 8) | (bytes.readUnsignedByte() << 16);
		var dimY = bytes.readUnsignedByte() | (bytes.readUnsignedByte() << 8) | (bytes.readUnsignedByte() << 16);
		var dimZ = bytes.readUnsignedByte() | (bytes.readUnsignedByte() << 8) | (bytes.readUnsignedByte() << 16);

		var blocksX = Math.ceil(dimX / blockDimX);
		var blocksY = Math.ceil(dimY / blockDimY);
		var blocksZ = Math.ceil(dimZ / blockDimZ);

		var totalBlocks = blocksX * blocksY * blocksZ;
		imageSize = totalBlocks * 16;
	}

	@:noCompletion private function __parseASTCHeader(bytes:ByteArray):Void
	{
		bytes.position = 0;

		var magic = bytes.readUnsignedInt();
		if (magic != ASTC_MAGIC_NUMBER)
		{
			trace('[ERROR] Invalid ASTC file: magic number mismatch!');
			supported = false;
			return;
		}

		bytes.position = 4;
		blockDimX = bytes.readUnsignedByte();
		blockDimY = bytes.readUnsignedByte();
		blockDimZ = bytes.readUnsignedByte();

		if (blockDimX <= 0 || blockDimY <= 0 || blockDimZ <= 0)
		{
			trace('[ERROR] Invalid ASTC file: bad block dimensions ${blockDimX}x${blockDimY}x${blockDimZ}!');
			supported = false;
			return;
		}
	}

	@:noCompletion private override function __setSamplerState(state:SamplerState):Bool
	{
		var effectiveState = state;

		if (state.mipfilter != MIPNONE)
		{
			effectiveState = state.clone();
			effectiveState.mipfilter = MIPNONE;

			/*if (!__warnedMipmap)
			{
				trace("[WARNING] Mip filtering is not supported for ASTCTexture (no mip chain is uploaded); ignoring mipfilter.");
				__warnedMipmap = true;
			}*/
		}

		if (super.__setSamplerState(effectiveState))
		{
			if (__context.isBGFX)
			{
				var bgfx = __context.bgfx;
				// bgfx has no per-texture anisotropic filtering
				// it's defined globally by the reset flags
				switch (state.filter)
				{
					case ANISOTROPIC2X, ANISOTROPIC4X, ANISOTROPIC8X, ANISOTROPIC16X:
						__samplerStateFlags |= bgfx.SAMPLER_MAG_ANISOTROPIC;
						__samplerStateFlags |= bgfx.SAMPLER_MIN_ANISOTROPIC;
					default: // nothing
				}
			}
			else if (__context.__maxTextureMaxAnisotropy != 0)
			{
				var gl = __context.gl;
				var aniso:Float = switch (state.filter)
				{
					case ANISOTROPIC2X: 2;
					case ANISOTROPIC4X: 4;
					case ANISOTROPIC8X: 8;
					case ANISOTROPIC16X: 16;
					default: 1;
				}

				if (aniso > __context.__maxTextureMaxAnisotropy)
				{
					aniso = __context.__maxTextureMaxAnisotropy;
				}

				gl.texParameterf(gl.TEXTURE_2D, __context.__textureMaxAnisotropy, aniso);
			}

			return true;
		}

		return false;
	}

	public static function isBytesASTC(bytes:ByteArray)
	{
		bytes.position = 0;
		var magic = bytes.readUnsignedInt();
		return magic == ASTC_MAGIC_NUMBER;
	}

	@:noCompletion private static function __showWarning(message:String):Void
	{
		if (__warned) return;
		__warned = true;

		#if USING_SHADOW_ENGINE
		backend.CoolUtil.showPopUp(message, "Rendering Error!");
		#else
		lime.app.Application.current.window.alert(message, "Rendering Error!");
		#end
	}

	@:noCompletion private static function __getASTCFormat(blockX:Int, blockY:Int):BGFXTextureFormat
	{
		return switch ([blockX, blockY])
		{
			case [4, 4]: BGFXTextureFormat.ASTC4x4;
			case [5, 4]: BGFXTextureFormat.ASTC5x4;
			case [5, 5]: BGFXTextureFormat.ASTC5x5;
			case [6, 5]: BGFXTextureFormat.ASTC6x5;
			case [6, 6]: BGFXTextureFormat.ASTC6x6;
			case [8, 5]: BGFXTextureFormat.ASTC8x5;
			case [8, 6]: BGFXTextureFormat.ASTC8x6;
			case [8, 8]: BGFXTextureFormat.ASTC8x8;
			case [10, 5]: BGFXTextureFormat.ASTC10x5;
			case [10, 6]: BGFXTextureFormat.ASTC10x6;
			case [10, 8]: BGFXTextureFormat.ASTC10x8;
			case [10, 10]: BGFXTextureFormat.ASTC10x10;
			case [12, 10]: BGFXTextureFormat.ASTC12x10;
			case [12, 12]: BGFXTextureFormat.ASTC12x12;
			default: BGFXTextureFormat.Unknown;
		}
	}

	@:noCompletion private override function __getFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):Dynamic
	{
		return null;
	}

	@:noCompletion private override function __uploadFromImage(image:lime.graphics.Image):Void
	{
		return;
	}
}
