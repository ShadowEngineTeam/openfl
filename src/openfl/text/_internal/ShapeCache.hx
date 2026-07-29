package openfl.text._internal;

import haxe.ds.IntMap;
import haxe.ds.StringMap;

@:access(openfl.text.TextFormat)
@SuppressWarnings("checkstyle:FieldDocComment")
class ShapeCache
{
	private var __shortWordMap:StringMap<StringMap<Array<GlyphPosition>>>;
	private var __longWordMap:StringMap<IntMap<CacheMeasurement>>;

	public function new()
	{
		__shortWordMap = new StringMap();
		__longWordMap = new StringMap();
	}

	private static function hashFunction(key:String):Int
	{
		var hash = 0, i, chr;
		for (i in 0...key.length)
		{
			chr = key.charCodeAt(i);
			hash = ((hash << 5) - hash) + chr;
			hash |= 0;
		}
		return hash;
	}

	public function cache(formatRange:TextFormatRange,
			getPositions:TextLayout):Array<GlyphPosition>
	{
		var formatKey:String = formatRange.format.__cacheKey;
		if (formatKey == null)
		{
			formatKey = formatRange.format.__toCacheKey();
		}
		var wordKey:String = getPositions.text;
		if (wordKey.length > 15)
		{
			return __cacheLongWord(wordKey, formatKey, getPositions);
		}
		else
		{
			return __cacheShortWord(wordKey, formatKey, getPositions);
		}
	}

	private function __cacheShortWord(wordKey:String, formatKey:String, getPositions:TextLayout):Array<GlyphPosition>
		{
			if
			(__shortWordMap.exists(formatKey))
			{
				var formatMap = __shortWordMap.get(formatKey);
				if
				(formatMap.exists(wordKey))
				{
					return
					formatMap.get
					(wordKey);
				}
			else
				{
					formatMap.set
					(wordKey, getPositions.positions);
				}
			}
		else
			{
				var formatMap = new StringMap();
				formatMap.set
				(wordKey, getPositions.positions);
				__shortWordMap.set
				(formatKey, formatMap);
			}
			return
			cast getPositions.positions
			;
		}
		private function __cacheLongWord(wordKey : String, formatKey : String, getPositions : TextLayout):Array<GlyphPosition>
			{
				var hash = hashFunction(wordKey);
				if (__longWordMap.exists(formatKey))
				{
					var formatMap = __longWordMap.get(formatKey);
					if (formatMap.exists(hash))
					{
						var measurement = formatMap.get(hash);
						if (measurement.exists(wordKey))
						{
							return measurement.get(wordKey);
						}
						else
						{
							measurement.set(wordKey, getPositions.positions);
						}
					}
					else
					{
						var measurement = new CacheMeasurement(wordKey, getPositions.positions);
						formatMap.set(hash, measurement);
					}
				}
				else
				{
					var formatMap = new IntMap();
					var measurement = new CacheMeasurement(wordKey, getPositions.positions);
					measurement.hash = hash;
					formatMap.set(hash, measurement);
					__longWordMap.set(formatKey, formatMap);
				}
				return getPositions.positions;
			}
	}
