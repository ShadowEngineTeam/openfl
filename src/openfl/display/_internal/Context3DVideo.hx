package openfl.display._internal;

import openfl.display.OpenGLRenderer;
import openfl.media.Video;

@:access(openfl.display3D.Context3D)
@:access(openfl.display.Shader)
@:access(openfl.geom.ColorTransform)
@:access(openfl.media.Video)
@:access(openfl.net.NetStream)
@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DVideo
{
	public static function render(video:Video, renderer:OpenGLRenderer):Void {}

	public static function renderDrawable(video:Video, renderer:OpenGLRenderer):Void
	{
		Context3DVideo.render(video, renderer);
		renderer.__renderEvent(video);
	}

	public static function renderDrawableMask(video:Video, renderer:OpenGLRenderer):Void
	{
		Context3DVideo.renderMask(video, renderer);
	}

	public static function renderMask(video:Video, renderer:OpenGLRenderer):Void {}
}
