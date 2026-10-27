package openfl.media._internal;

import haxe.io.Bytes;
import openfl.media.ID3Info;

/**
	Reads the song tags of an audio file into an `ID3Info`:
	ID3v2 / ID3v1 (MP3), Vorbis comments (Ogg Vorbis, Ogg Opus, FLAC) and RIFF INFO (WAV).
**/
@:noCompletion class AudioMetadata
{
	public static function read(bytes:Bytes):ID3Info
	{
		var info = new ID3Info();

		if (bytes == null || bytes.length < 4)
		{
			return info;
		}

		if (startsWith(bytes, 0, "ID3"))
		{
			readID3v2(bytes, info);
		}
		else if (startsWith(bytes, 0, "OggS"))
		{
			readOgg(bytes, info);
		}
		else if (startsWith(bytes, 0, "fLaC"))
		{
			readFlac(bytes, info);
		}
		else if (startsWith(bytes, 0, "RIFF") && bytes.length >= 12 && startsWith(bytes, 8, "WAVE"))
		{
			readWav(bytes, info);
		}

		// ID3v1 sits in the last 128 bytes and only fills what ID3v2 left empty
		if (bytes.length >= 128 && startsWith(bytes, bytes.length - 128, "TAG"))
		{
			readID3v1(bytes, bytes.length - 128, info);
		}

		return info;
	}

	private static function readID3v2(bytes:Bytes, info:ID3Info):Void
	{
		if (bytes.length < 10)
		{
			return;
		}

		var version = bytes.get(3);
		var flags = bytes.get(5);
		var end = 10 + syncsafe(bytes, 6);

		if (end > bytes.length)
		{
			end = bytes.length;
		}

		var pos = 10;

		if (version >= 3 && (flags & 0x40) != 0)
		{
			// extended header: v2.4 counts its own size, v2.3 doesn't
			pos += (version == 4) ? syncsafe(bytes, 10) : bigEndian32(bytes, 10) + 4;
		}

		var idLength = version == 2 ? 3 : 4;
		var headerLength = version == 2 ? 6 : 10;

		while (pos + headerLength <= end)
		{
			var id = bytes.getString(pos, idLength);

			if (bytes.get(pos) == 0)
			{
				break; // padding
			}

			var size = switch (version)
			{
				case 2: (bytes.get(pos + 3) << 16) | (bytes.get(pos + 4) << 8) | bytes.get(pos + 5);
				case 4: syncsafe(bytes, pos + 4);
				default: bigEndian32(bytes, pos + 4);
			}

			var dataStart = pos + headerLength;

			if (size <= 0 || dataStart + size > end)
			{
				break;
			}

			switch (id)
			{
				case "TIT2", "TT2":
					info.songName = first(info.songName, readID3Text(bytes, dataStart, size));
				case "TPE1", "TP1":
					info.artist = first(info.artist, readID3Text(bytes, dataStart, size));
				case "TALB", "TAL":
					info.album = first(info.album, readID3Text(bytes, dataStart, size));
				case "TCON", "TCO":
					info.genre = first(info.genre, readID3Text(bytes, dataStart, size));
				case "TYER", "TDRC", "TYE":
					info.year = first(info.year, readID3Text(bytes, dataStart, size));
				case "TRCK", "TRK":
					info.track = first(info.track, readID3Text(bytes, dataStart, size));
				case "COMM", "COM":
					info.comment = first(info.comment, readID3Comment(bytes, dataStart, size));
				default:
			}

			pos = dataStart + size;
		}
	}

	private static function readID3Text(bytes:Bytes, start:Int, size:Int):String
	{
		if (size < 1)
		{
			return null;
		}

		return decodeID3String(bytes, bytes.get(start), start + 1, start + size);
	}

	private static function readID3Comment(bytes:Bytes, start:Int, size:Int):String
	{
		// encoding, 3-byte language, null-terminated description, then the comment
		if (size < 5)
		{
			return null;
		}

		var encoding = bytes.get(start);
		var end = start + size;
		var pos = start + 4;
		var wide = encoding == 1 || encoding == 2;

		while (pos < end)
		{
			if (wide)
			{
				if (pos + 1 < end && bytes.get(pos) == 0 && bytes.get(pos + 1) == 0)
				{
					pos += 2;
					break;
				}

				pos += 2;
			}
			else
			{
				if (bytes.get(pos) == 0)
				{
					pos++;
					break;
				}

				pos++;
			}
		}

		return decodeID3String(bytes, encoding, pos, end);
	}

	private static function decodeID3String(bytes:Bytes, encoding:Int, start:Int, end:Int):String
	{
		if (start >= end)
		{
			return null;
		}

		var buf = new StringBuf();

		switch (encoding)
		{
			case 1, 2:
				var bigEndian = encoding == 2;
				var pos = start;

				if (encoding == 1 && pos + 1 < end)
				{
					if (bytes.get(pos) == 0xFE && bytes.get(pos + 1) == 0xFF)
					{
						bigEndian = true;
						pos += 2;
					}
					else if (bytes.get(pos) == 0xFF && bytes.get(pos + 1) == 0xFE)
					{
						pos += 2;
					}
				}

				while (pos + 1 < end)
				{
					var unit = bigEndian ? (bytes.get(pos) << 8) | bytes.get(pos + 1) : bytes.get(pos) | (bytes.get(pos + 1) << 8);
					pos += 2;

					if (unit == 0)
					{
						break;
					}

					if (unit >= 0xD800 && unit <= 0xDBFF && pos + 1 < end)
					{
						var low = bigEndian ? (bytes.get(pos) << 8) | bytes.get(pos + 1) : bytes.get(pos) | (bytes.get(pos + 1) << 8);
						pos += 2;
						unit = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
					}

					buf.addChar(unit);
				}

				return clean(buf.toString());

			case 3:
				var stop = start;

				while (stop < end && bytes.get(stop) != 0)
				{
					stop++;
				}

				return clean(bytes.getString(start, stop - start));

			default:
				return clean(latin1(bytes, start, end));
		}
	}

	private static function readID3v1(bytes:Bytes, start:Int, info:ID3Info):Void
	{
		info.songName = first(info.songName, clean(latin1(bytes, start + 3, start + 33)));
		info.artist = first(info.artist, clean(latin1(bytes, start + 33, start + 63)));
		info.album = first(info.album, clean(latin1(bytes, start + 63, start + 93)));
		info.year = first(info.year, clean(latin1(bytes, start + 93, start + 97)));

		// ID3v1.1 keeps the track number in the last two comment bytes
		if (bytes.get(start + 125) == 0 && bytes.get(start + 126) != 0)
		{
			info.comment = first(info.comment, clean(latin1(bytes, start + 97, start + 125)));
			info.track = first(info.track, Std.string(bytes.get(start + 126)));
		}
		else
		{
			info.comment = first(info.comment, clean(latin1(bytes, start + 97, start + 127)));
		}
	}

	private static function readOgg(bytes:Bytes, info:ID3Info):Void
	{
		// rebuild the first packets from the pages; the comment packet is the second one
		var packets:Array<Bytes> = [];
		var current = new haxe.io.BytesBuffer();
		var pos = 0;

		while (pos + 27 <= bytes.length && packets.length < 2 && startsWith(bytes, pos, "OggS"))
		{
			var segments = bytes.get(pos + 26);
			var dataPos = pos + 27 + segments;

			if (dataPos > bytes.length)
			{
				break;
			}

			for (i in 0...segments)
			{
				var length = bytes.get(pos + 27 + i);

				if (dataPos + length > bytes.length)
				{
					return;
				}

				current.addBytes(bytes, dataPos, length);
				dataPos += length;

				if (length < 255)
				{
					packets.push(current.getBytes());
					current = new haxe.io.BytesBuffer();

					if (packets.length == 2)
					{
						break;
					}
				}
			}

			pos = dataPos;
		}

		if (packets.length < 2)
		{
			return;
		}

		var comments = packets[1];

		if (comments.length > 7 && comments.get(0) == 3 && startsWith(comments, 1, "vorbis"))
		{
			readVorbisComment(comments, 7, comments.length, info);
		}
		else if (comments.length > 8 && startsWith(comments, 0, "OpusTags"))
		{
			readVorbisComment(comments, 8, comments.length, info);
		}
	}

	private static function readFlac(bytes:Bytes, info:ID3Info):Void
	{
		var pos = 4;

		while (pos + 4 <= bytes.length)
		{
			var header = bytes.get(pos);
			var type = header & 0x7F;
			var length = (bytes.get(pos + 1) << 16) | (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);
			var start = pos + 4;

			if (start + length > bytes.length)
			{
				return;
			}

			if (type == 4)
			{
				readVorbisComment(bytes, start, start + length, info);
				return;
			}

			if ((header & 0x80) != 0)
			{
				return; // last metadata block
			}

			pos = start + length;
		}
	}

	private static function readVorbisComment(bytes:Bytes, start:Int, end:Int, info:ID3Info):Void
	{
		if (start + 4 > end)
		{
			return;
		}

		var pos = start + 4 + littleEndian32(bytes, start); // skip the vendor string

		if (pos + 4 > end)
		{
			return;
		}

		var count = littleEndian32(bytes, pos);
		pos += 4;

		for (_ in 0...count)
		{
			if (pos + 4 > end)
			{
				return;
			}

			var length = littleEndian32(bytes, pos);
			pos += 4;

			if (length < 0 || pos + length > end)
			{
				return;
			}

			var entry = bytes.getString(pos, length);
			pos += length;

			var split = entry.indexOf("=");

			if (split <= 0)
			{
				continue;
			}

			var value = clean(entry.substr(split + 1));

			switch (entry.substr(0, split).toUpperCase())
			{
				case "TITLE":
					info.songName = first(info.songName, value);
				case "ARTIST":
					info.artist = first(info.artist, value);
				case "ALBUM":
					info.album = first(info.album, value);
				case "GENRE":
					info.genre = first(info.genre, value);
				case "DATE", "YEAR":
					info.year = first(info.year, value);
				case "TRACKNUMBER":
					info.track = first(info.track, value);
				case "COMMENT", "DESCRIPTION":
					info.comment = first(info.comment, value);
				default:
			}
		}
	}

	private static function readWav(bytes:Bytes, info:ID3Info):Void
	{
		var pos = 12;

		while (pos + 8 <= bytes.length)
		{
			var id = bytes.getString(pos, 4);
			var size = littleEndian32(bytes, pos + 4);
			var start = pos + 8;

			if (size < 0 || start + size > bytes.length)
			{
				return;
			}

			if (id == "LIST" && size >= 4 && startsWith(bytes, start, "INFO"))
			{
				var sub = start + 4;
				var end = start + size;

				while (sub + 8 <= end)
				{
					var subId = bytes.getString(sub, 4);
					var subSize = littleEndian32(bytes, sub + 4);
					var subStart = sub + 8;

					if (subSize < 0 || subStart + subSize > end)
					{
						break;
					}

					var value = clean(latin1(bytes, subStart, subStart + subSize));

					switch (subId)
					{
						case "INAM":
							info.songName = first(info.songName, value);
						case "IART":
							info.artist = first(info.artist, value);
						case "IPRD":
							info.album = first(info.album, value);
						case "IGNR":
							info.genre = first(info.genre, value);
						case "ICRD":
							info.year = first(info.year, value);
						case "ITRK", "IPRT":
							info.track = first(info.track, value);
						case "ICMT":
							info.comment = first(info.comment, value);
						default:
					}

					sub = subStart + subSize + (subSize & 1);
				}
			}

			pos = start + size + (size & 1);
		}
	}

	private static inline function first(current:String, value:String):String
	{
		return (current != null && current.length > 0) ? current : value;
	}

	private static function clean(value:String):String
	{
		if (value == null)
		{
			return null;
		}

		var end = value.indexOf("\x00");

		if (end >= 0)
		{
			value = value.substr(0, end);
		}

		value = StringTools.trim(value);

		return value.length > 0 ? value : null;
	}

	private static function latin1(bytes:Bytes, start:Int, end:Int):String
	{
		var buf = new StringBuf();

		for (i in start...end)
		{
			var c = bytes.get(i);

			if (c == 0)
			{
				break;
			}

			buf.addChar(c);
		}

		return buf.toString();
	}

	private static function startsWith(bytes:Bytes, pos:Int, text:String):Bool
	{
		if (pos < 0 || pos + text.length > bytes.length)
		{
			return false;
		}

		for (i in 0...text.length)
		{
			if (bytes.get(pos + i) != text.charCodeAt(i))
			{
				return false;
			}
		}

		return true;
	}

	private static inline function syncsafe(bytes:Bytes, pos:Int):Int
	{
		return ((bytes.get(pos) & 0x7F) << 21) | ((bytes.get(pos + 1) & 0x7F) << 14) | ((bytes.get(pos + 2) & 0x7F) << 7) | (bytes.get(pos + 3) & 0x7F);
	}

	private static inline function bigEndian32(bytes:Bytes, pos:Int):Int
	{
		return (bytes.get(pos) << 24) | (bytes.get(pos + 1) << 16) | (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);
	}

	private static inline function littleEndian32(bytes:Bytes, pos:Int):Int
	{
		return bytes.get(pos) | (bytes.get(pos + 1) << 8) | (bytes.get(pos + 2) << 16) | (bytes.get(pos + 3) << 24);
	}
}
