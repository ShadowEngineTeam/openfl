package openfl.display._internal;

import openfl.display.IDisplayObjectLoader;
import openfl.display.LoaderInfo;
import openfl.net.URLRequest;
import openfl.system.LoaderContext;
import openfl.utils.ByteArray;
import openfl.utils.Future;

class ScriptLoader implements IDisplayObjectLoader
{
	public function new() {}

	public function load(request:URLRequest, context:LoaderContext, contentLoaderInfo:LoaderInfo):Future<DisplayObject>
	{
		return null;
	}

	public function loadBytes(buffer:ByteArray, context:LoaderContext, contentLoaderInfo:LoaderInfo):Future<DisplayObject>
	{
		return null;
	}
}
