package openfl.display3D.textures;

#if !flash
import haxe.io.Bytes;
import openfl.utils._internal.UInt8Array;
import openfl.utils.ByteArray;
import openfl.Lib;
import openfl.display._internal.SamplerState;
import openfl.display3D.Context3D;

/**
	The BCTexture class represents a 2-dimensional compressed BCn texture uploaded to a rendering context.

	Defines a 2D texture for use during rendering.

	BCTexture cannot be instantiated directly. Create instances by using Context3D
	`createBCTexture()` method.
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display3D.Context3D)
@:final class BCTexture extends TextureBase
{
	@:noCompletion private static var __warned:Bool = false;
	//@:noCompletion private static var __warnedMipmap:Bool = false;
	public static inline final BC_MAGIC_NUMBER:Int = 0x20534444;
	public static final DDS_HEADER_SIZE:Int = 128;
	public static final DX10_HEADER_SIZE:Int = 148;

	public var supported:Bool = true;
	public var imageSize(default, null):Int = 0;

	private var __isSRGB:Bool = false; // sRGB colorspace (BC1/BC2/BC3/BC7)
	private var __isSigned:Bool = false; // SNORM/SF16 signed data (BC4/BC5/BC6H)
	private var __bcFormat:String = "BC7";
	private var __isDX10:Bool = true;

	private function new(context:Context3D, data:ByteArray)
	{
		super(context);

		var gl = __context.gl;

		__detectBCFormat(data);

		var dxt1Extension = __getExtension(gl, ["EXT_texture_compression_dxt1"]);
		var dxt3Extension = __getExtension(gl, ["ANGLE_texture_compression_dxt3", "EXT_texture_compression_s3tc"]);
		var dxt5Extension = __getExtension(gl, ["ANGLE_texture_compression_dxt5", "EXT_texture_compression_s3tc"]);
		var s3tcSRGBExtension = __getExtension(gl, ["EXT_texture_compression_s3tc_srgb"]);
		var rgtcExtensionEXT = __getExtension(gl, ["EXT_texture_compression_rgtc"]);
		var rgtcExtensionARB = __getExtension(gl, ["ARB_texture_compression_rgtc"]);
		var bptcExtensionEXT = __getExtension(gl, ["EXT_texture_compression_bptc"]);
		var bptcExtensionARB = __getExtension(gl, ["ARB_texture_compression_bptc"]);

		var extensionSupported = switch (__bcFormat)
		{
			case "BC1":
				dxt1Extension != null && (!__isSRGB || s3tcSRGBExtension != null);
			case "BC2":
				dxt3Extension != null && (!__isSRGB || s3tcSRGBExtension != null);
			case "BC3":
				dxt5Extension != null && (!__isSRGB || s3tcSRGBExtension != null);
			case "BC4", "BC5":
				rgtcExtensionEXT != null || rgtcExtensionARB != null;
			case "BC6H", "BC7":
				bptcExtensionEXT != null || bptcExtensionARB != null;
			default:
				false;
		}

		if (!extensionSupported)
		{
			if (!__warned)
			{
				#if USING_SHADOW_ENGINE
				backend.CoolUtil.showPopUp('BC compression for $__bcFormat is not available on this device.', "Rendering Error!");
				#else
				lime.app.Application.current.window.alert('BC compression for $__bcFormat is not available on this device.', "Rendering Error!");
				#end
				__warned = true;
			}
			supported = false;
			return;
		}

		__getImageDimensions(data);
		__computeImageSize();

		__format = switch (__bcFormat)
		{
			case "BC1":
				__isSRGB ? 0x8C4D /* COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT */ : 0x83F1 /* COMPRESSED_RGBA_S3TC_DXT1_EXT */;
			case "BC2":
				__isSRGB ? 0x8C4E /* COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT */ : 0x83F2 /* COMPRESSED_RGBA_S3TC_DXT3_EXT/ANGLE */;
			case "BC3":
				__isSRGB ? 0x8C4F /* COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT */ : 0x83F3 /* COMPRESSED_RGBA_S3TC_DXT5_EXT/ANGLE */;
			case "BC4":
				__isSigned ?
					(rgtcExtensionEXT != null ? rgtcExtensionEXT.COMPRESSED_SIGNED_RED_RGTC1_EXT : rgtcExtensionARB.COMPRESSED_SIGNED_RED_RGTC1_ARB) :
					(rgtcExtensionEXT != null ? rgtcExtensionEXT.COMPRESSED_RED_RGTC1_EXT : rgtcExtensionARB.COMPRESSED_RED_RGTC1_ARB);
			case "BC5":
				__isSigned ?
					(rgtcExtensionEXT != null ? rgtcExtensionEXT.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT : rgtcExtensionARB.COMPRESSED_SIGNED_RED_GREEN_RGTC2_ARB) :
					(rgtcExtensionEXT != null ? rgtcExtensionEXT.COMPRESSED_RED_GREEN_RGTC2_EXT : rgtcExtensionARB.COMPRESSED_RED_GREEN_RGTC2_ARB);
			case "BC6H":
				__isSigned ?
					(bptcExtensionEXT != null ? bptcExtensionEXT.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT : bptcExtensionARB.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB) :
					(bptcExtensionEXT != null ? bptcExtensionEXT.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT : bptcExtensionARB.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_ARB);
			case "BC7":
				__isSRGB ?
					(bptcExtensionEXT != null ? bptcExtensionEXT.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT : bptcExtensionARB.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB) :
					(bptcExtensionEXT != null ? bptcExtensionEXT.COMPRESSED_RGBA_BPTC_UNORM_EXT : bptcExtensionARB.COMPRESSED_RGBA_BPTC_UNORM_ARB);
			default:
				bptcExtensionEXT != null ? bptcExtensionEXT.COMPRESSED_RGBA_BPTC_UNORM_EXT : bptcExtensionARB.COMPRESSED_RGBA_BPTC_UNORM_ARB;
		}

		__internalFormat = __format;
		__optimizeForRenderToTexture = false;
		__streamingLevels = 0;

		__uploadBCTextureFromByteArray(data);
	}

	@:noCompletion private static function __getExtension(gl:Dynamic, names:Array<String>):Dynamic
	{
		for (name in names)
		{
			var ext = gl.getExtension(name);
			if (ext != null) return ext;
		}
		return null;
	}

	private function __uploadBCTextureFromByteArray(data:ByteArray):Void
	{
		var gl = __context.gl;

		__textureTarget = gl.TEXTURE_2D;
		__context.__bindGLTexture2D(__textureID);

		var bytes:Bytes = cast data;
		var dataOffset = __isDX10 ? DX10_HEADER_SIZE : DDS_HEADER_SIZE;
		var textureBytes = new UInt8Array(#if js @:privateAccess bytes.b.buffer #else bytes #end, dataOffset, imageSize);
		gl.compressedTexImage2D(__textureTarget, 0, __internalFormat, __width, __height, 0, textureBytes);
		gl.texParameteri(__textureTarget, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(__textureTarget, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

		__context.__bindGLTexture2D(null);
	}

	private function __getImageDimensions(bytes:ByteArray):Void
	{
		bytes.position = 12;
		__height = bytes.readUnsignedInt();

		bytes.position = 16;
		__width = bytes.readUnsignedInt();
	}

	private function __computeImageSize():Void
	{
		var blockWidth = Math.ceil(__width / 4);
		var blockHeight = Math.ceil(__height / 4);
		var blockSize = switch (__bcFormat)
		{
			case "BC1": 8;
			case "BC2", "BC3", "BC6H", "BC7": 16;
			case "BC4": 8;
			case "BC5": 16;
			default: 16;
		}

		imageSize = blockWidth * blockHeight * blockSize;
	}

	private function __detectBCFormat(bytes:ByteArray):Void
	{
		bytes.position = 84;
		var fourCC = bytes.readUTFBytes(4);

		if (fourCC == "DX10")
		{
			__isDX10 = true;
			// DXGI format stored at offset 128 (after DDS header).
			bytes.position = 128;
			var dxgiFormat = bytes.readUnsignedInt();

			switch (dxgiFormat)
			{
				case 70, 71: // BC1_TYPELESS, BC1_UNORM
					__bcFormat = "BC1";
					__isSRGB = false;
				case 72: // BC1_UNORM_SRGB
					__bcFormat = "BC1";
					__isSRGB = true;
				case 73, 74: // BC2_TYPELESS, BC2_UNORM
					__bcFormat = "BC2";
					__isSRGB = false;
				case 75: // BC2_UNORM_SRGB
					__bcFormat = "BC2";
					__isSRGB = true;
				case 76, 77: // BC3_TYPELESS, BC3_UNORM
					__bcFormat = "BC3";
					__isSRGB = false;
				case 78: // BC3_UNORM_SRGB
					__bcFormat = "BC3";
					__isSRGB = true;
				case 79, 80: // BC4_TYPELESS, BC4_UNORM
					__bcFormat = "BC4";
					__isSigned = false;
				case 81: // BC4_SNORM
					__bcFormat = "BC4";
					__isSigned = true;
				case 82, 83: // BC5_TYPELESS, BC5_UNORM
					__bcFormat = "BC5";
					__isSigned = false;
				case 84: // BC5_SNORM
					__bcFormat = "BC5";
					__isSigned = true;
				case 94, 95: // BC6H_TYPELESS, BC6H_UF16 (unsigned float)
					__bcFormat = "BC6H";
					__isSigned = false;
				case 96: // BC6H_SF16 (signed float)
					__bcFormat = "BC6H";
					__isSigned = true;
				case 97, 98: // BC7_TYPELESS, BC7_UNORM
					__bcFormat = "BC7";
					__isSRGB = false;
				case 99: // BC7_UNORM_SRGB
					__bcFormat = "BC7";
					__isSRGB = true;
				default:
					__bcFormat = "BC7";
			}
		}
		else
		{
			__isDX10 = false;
			// legacy DDS fourCC. DXT2/DXT4 are premultiplied-alpha variants that share the
			// exact block layout of DXT3/DXT5 (BC2/BC3); GL has no separate premultiplied
			// format, so they decode through the same internal format.
			switch (fourCC)
			{
				case "DXT1":
					__bcFormat = "BC1";
					__isSRGB = false;
				case "DXT2", "DXT3":
					__bcFormat = "BC2";
					__isSRGB = false;
				case "DXT4", "DXT5":
					__bcFormat = "BC3";
					__isSRGB = false;
				case "BC4U", "ATI1":
					__bcFormat = "BC4";
					__isSigned = false; // UNORM
				case "BC4S":
					__bcFormat = "BC4";
					__isSigned = true; // SNORM (signed)
				case "BC5U", "ATI2":
					__bcFormat = "BC5";
					__isSigned = false; // UNORM
				case "BC5S":
					__bcFormat = "BC5";
					__isSigned = true; // SNORM (signed)
				default:
					__bcFormat = "BC7"; // assuming DX10 if not legacy
			}
		}
	}

	public static function isBytesBC(bytes:ByteArray)
	{
		bytes.position = 0;
		var magic = bytes.readUnsignedInt();

		return magic == BC_MAGIC_NUMBER;
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
				trace("[WARNING] Mip filtering is not supported for BCTexture (no mip chain is uploaded); ignoring mipfilter.");
				__warnedMipmap = true;
			}*/
		}

		if (super.__setSamplerState(effectiveState))
		{
			var gl = __context.gl;

			if (Context3D.__glMaxTextureMaxAnisotropy != 0)
			{
				var aniso = switch (state.filter)
				{
					case ANISOTROPIC2X: 2;
					case ANISOTROPIC4X: 4;
					case ANISOTROPIC8X: 8;
					case ANISOTROPIC16X: 16;
					default: 1;
				}

				if (aniso > Context3D.__glMaxTextureMaxAnisotropy)
				{
					aniso = Context3D.__glMaxTextureMaxAnisotropy;
				}

				gl.texParameterf(gl.TEXTURE_2D, Context3D.__glTextureMaxAnisotropy, aniso);
			}

			return true;
		}

		return false;
	}
}

#end
