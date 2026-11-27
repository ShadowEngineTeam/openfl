package openfl.utils;

/**
	The CompressionAlgorithm class defines string constants for the names of
	compress and uncompress options. These constants are used as values of the
	`algorithm` parameter of the `ByteArray.compress()` and
	`ByteArray.uncompress()` methods.
**/
enum abstract CompressionAlgorithm(Null<Int>)
{
	/**
		Defines the string to use for the deflate compression algorithm.
	**/
	public var DEFLATE = 0;

	// GZIP;

	/**
		Defines the string to use for the zlib compression algorithm.
	**/
	public var ZLIB = 2;

	@:from private static function fromString(value:String):CompressionAlgorithm
	{
		return switch (value)
		{
			case "deflate": DEFLATE;
			case "zlib": ZLIB;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : CompressionAlgorithm)
		{
			case CompressionAlgorithm.DEFLATE: "deflate";
			case CompressionAlgorithm.ZLIB: "zlib";
			default: null;
		}
	}
}
