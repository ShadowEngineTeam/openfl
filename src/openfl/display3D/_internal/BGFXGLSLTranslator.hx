package openfl.display3D._internal;

/**
	Translates a GLSL ES 1.00 vertex/fragment shader pair (the dialect produced
	by openfl.display.Shader, ShaderMacro, AGALConverter and FlxRuntimeShader)
	into bgfx .sc sources plus a varying.def, ready for lime's runtime shaderc.

	The translation is textual:
	- `attribute`/`varying` declarations become `$input`/`$output` lists over
	  bgfx canonical names (a_position, a_texcoord0.., a_color0..), with
	  `#define` aliases so the original identifiers keep working in the body
	- uniforms are packed to the types bgfx supports (vec4/mat3/mat4/sampler):
	  float/vec2/vec3/int/bool become a vec4 with a swizzle alias
	- `sampler2D` declarations become `SAMPLER2D(name, stage)` in declaration
	  order (the stage index doubles as the texture unit)
	- the entry point is normalized to the literal `void main()` (shaderc
	  requires it, no space before the parentheses)

	Matrix math is left as-is (`m * v`): the spirv, essl, glsl and metal
	shaderc profiles all accept GLSL operators. (The s_5_0 profile would not,
	but Direct3D is only a last-resort fallback renderer.)
**/
@SuppressWarnings("checkstyle:FieldDocComment")
class BGFXGLSLTranslator
{
	// bgfx Attrib enum values (mirror lime.graphics.bgfx.BGFXAttrib / vendored bgfx.h)
	public static inline var ATTRIB_POSITION = 0;
	public static inline var ATTRIB_COLOR0 = 4;
	public static inline var ATTRIB_COLOR1 = 5;
	public static inline var ATTRIB_COLOR2 = 6;
	public static inline var ATTRIB_COLOR3 = 7;
	public static inline var ATTRIB_TEXCOORD0 = 10; // ..TEXCOORD7 = 17

	/**
		`complexBlendMode` takes a KHR_blend_equation_advanced enum value
		(0x9294..0x92B0). When non-zero, the fragment shader is wrapped so the
		original program writes to a temporary, the current render target is
		sampled from `openfl_DstSampler` (bound at the stage after the user
		samplers), and the KHR blend equation is evaluated in the shader —
		programmable blending, since no bgfx backend has the fixed-function
		extension.
	**/
	public static function translate(vertexSource:String, fragmentSource:String, complexBlendMode:Int = 0):BGFXTranslatedProgram
	{
		var result = new BGFXTranslatedProgram();

		vertexSource = __stripDirectives(vertexSource);
		fragmentSource = __stripDirectives(fragmentSource);

		// ---- attributes (vertex only) ----

		var attribRegex = ~/^\s*attribute\s+(?:lowp\s+|mediump\s+|highp\s+)?(\w+)\s+(\w+)\s*;/gm;
		var texcoord = 0;
		var color = 0;
		var usedPosition = false;

		var vertexBody = attribRegex.map(vertexSource, function(r)
		{
			var type = r.matched(1);
			var name = r.matched(2);

			var semantic:Int;
			var canonical:String;

			if (!usedPosition && name.indexOf("Position") > -1)
			{
				semantic = ATTRIB_POSITION;
				canonical = "a_position";
				usedPosition = true;
			}
			else if (name.indexOf("Color") > -1 && color < 2)
			{
				semantic = ATTRIB_COLOR0 + color;
				canonical = "a_color" + color;
				color++;
			}
			else
			{
				if (texcoord > 7) texcoord = 7; // out of semantics; last one wins (unlikely in practice)
				semantic = ATTRIB_TEXCOORD0 + texcoord;
				canonical = "a_texcoord" + texcoord;
				texcoord++;
			}

			result.attribNames.push(name);
			result.attribCanonicalNames.push(canonical);
			result.attribSemantics.push(semantic);
			result.attribComponents.push(__componentCount(type));
			result.attribDefTypes.push(type);

			return ""; // remove declaration
		});

		// ---- varyings (union across both stages, keyed by name) ----

		var varyingRegex = ~/^\s*varying\s+(?:lowp\s+|mediump\s+|highp\s+)?(\w+)\s+(\w+)\s*;/gm;
		var varyingNames = new Array<String>();
		var varyingTypes = new Array<String>();

		var collect = function(r:EReg)
		{
			var type = r.matched(1);
			var name = r.matched(2);
			if (varyingNames.indexOf(name) == -1)
			{
				varyingNames.push(name);
				varyingTypes.push(type);
			}
			return "";
		}

		vertexBody = varyingRegex.map(vertexBody, collect);
		var fragmentBody = varyingRegex.map(fragmentSource, collect);

		var varyingCanonical = new Array<String>();
		var vTexcoord = 0;
		var vColor = 0;

		for (i in 0...varyingNames.length)
		{
			var canonical;
			if (varyingNames[i].indexOf("Color") > -1 && vColor < 2)
			{
				canonical = "v_color" + vColor;
				vColor++;
			}
			else
			{
				if (vTexcoord > 7) vTexcoord = 7;
				canonical = "v_texcoord" + vTexcoord;
				vTexcoord++;
			}
			varyingCanonical.push(canonical);
		}

		// ---- varying.def.sc ----

		var def = new StringBuf();

		// initializers matter: shaderc's HLSL wrapper only pre-writes output
		// struct members that carry an init value; without one, a varying
		// assigned inside a runtime branch (openfl's HasColorTransform
		// pattern) is dropped by FXC as never-written, which D3D12 rejects
		// at PSO creation and D3D11 punishes by silently discarding draws
		for (i in 0...varyingNames.length)
		{
			def.add(varyingTypes[i] + " " + varyingCanonical[i] + " : " + __varyingSemantic(varyingCanonical[i]) + " = " + __zeroInit(varyingTypes[i])
				+ ";\n");
		}

		for (i in 0...result.attribNames.length)
		{
			def.add(result.attribDefTypes[i] + " " + result.attribCanonicalNames[i] + " : " + __attribSemanticName(result.attribSemantics[i]) + ";\n");
		}

		result.varyingDef = def.toString();

		// ---- uniforms ----

		vertexBody = __processUniforms(vertexBody, result, true);
		fragmentBody = __processUniforms(fragmentBody, result, false);

		// ---- entry point + aliases ----

		// HLSL (the s_5_0 profile used by the Direct3D fallback renderer) has
		// no matrix `*` operator and no scalar matrix constructors: rewrite
		// `matN(scalar)` to identity-times-scalar and matrix multiplies (both
		// `m * x` and `x * m`, for uniforms and locals) to mul() —
		// bgfx_shader.sh defines mul() for GLSL too, so this is profile-safe
		vertexBody = __rewriteMatrixCtors(vertexBody);
		fragmentBody = __rewriteMatrixCtors(fragmentBody);

		var vertexMatrices = __collectLocalMatrices(vertexBody);
		var fragmentMatrices = __collectLocalMatrices(fragmentBody);

		for (i in 0...result.uniformNames.length)
		{
			if (StringTools.startsWith(result.uniformGLSLTypes[i], "mat"))
			{
				vertexMatrices.push(result.uniformNames[i]);
				fragmentMatrices.push(result.uniformNames[i]);
			}
		}

		for (name in vertexMatrices)
		{
			vertexBody = __rewriteMatrixMul(vertexBody, name);
			vertexBody = __rewriteMatrixMulRight(vertexBody, name);
		}

		for (name in fragmentMatrices)
		{
			fragmentBody = __rewriteMatrixMul(fragmentBody, name);
			fragmentBody = __rewriteMatrixMulRight(fragmentBody, name);
		}

		vertexBody = __normalizeMain(vertexBody);
		fragmentBody = __normalizeMain(fragmentBody);

		var attribDefines = new StringBuf();
		for (i in 0...result.attribNames.length)
		{
			if (result.attribNames[i] != result.attribCanonicalNames[i])
			{
				attribDefines.add("#define " + result.attribNames[i] + " " + result.attribCanonicalNames[i] + "\n");
			}
		}

		var varyingDefines = new StringBuf();
		for (i in 0...varyingNames.length)
		{
			if (varyingNames[i] != varyingCanonical[i])
			{
				varyingDefines.add("#define " + varyingNames[i] + " " + varyingCanonical[i] + "\n");
			}
		}

		var vs = new StringBuf();
		if (result.attribCanonicalNames.length > 0) vs.add("$input " + result.attribCanonicalNames.join(", ") + "\n");
		if (varyingCanonical.length > 0) vs.add("$output " + varyingCanonical.join(", ") + "\n");
		vs.add("#include <bgfx_shader.sh>\n");
		vs.add(attribDefines.toString());
		vs.add(varyingDefines.toString());
		vs.add(result.vertexUniformCode);
		vs.add(vertexBody);
		result.vertexSC = vs.toString();

		var fs = new StringBuf();
		if (varyingCanonical.length > 0) fs.add("$input " + varyingCanonical.join(", ") + "\n");
		fs.add("#include <bgfx_shader.sh>\n");

		if (complexBlendMode != 0)
		{
			// the original program writes into openfl_SrcColor; the wrapper
			// main computes the advanced blend against the sampled target.
			// HLSL constraints shape the structure: unqualified globals turn
			// into uniforms (need `static`), and varyings only exist as
			// main() parameters, so the impl function reads static copies
			// that main fills in before calling it
			result.dstSamplerStage = result.samplerNames.length;

			fs.add(result.fragmentUniformCode);
			fs.add("SAMPLER2D(openfl_DstSampler, " + result.dstSamplerStage + ");\n");
			// every backend except plain GLSL/ESSL parses the source with an
			// HLSL-style frontend where an unqualified global is a uniform;
			// `static` makes it a mutable global (invalid syntax in GLSL)
			fs.add("#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_ESSL\n#define OPENFL_GLOBAL\n#else\n#define OPENFL_GLOBAL static\n#endif\n");
			fs.add("OPENFL_GLOBAL vec4 openfl_SrcColor;\n");

			var copyUndefs = new StringBuf();
			var copyAssigns = new StringBuf();
			for (i in 0...varyingNames.length)
			{
				var copyName = "openfl_in_" + varyingCanonical[i].substr(2);
				fs.add("OPENFL_GLOBAL " + varyingTypes[i] + " " + copyName + ";\n");
				fs.add("#define " + varyingNames[i] + " " + copyName + "\n");
				copyUndefs.add("#undef " + varyingNames[i] + "\n");
				copyAssigns.add("\t" + copyName + " = " + varyingCanonical[i] + ";\n");
			}

			fs.add("#define gl_FragColor openfl_SrcColor\n");
			fs.add(~/void\s+main\s*\(\s*\)/.replace(fragmentBody, "void openfl_blend_impl()"));
			fs.add("\n#undef gl_FragColor\n");
			fs.add(copyUndefs.toString());
			fs.add(__blendLibrary(complexBlendMode));
			fs.add("void main() {\n"
				+ copyAssigns.toString()
				+ "\topenfl_blend_impl();\n"
				+ "\tvec2 openfl_dstUV = gl_FragCoord.xy * u_viewTexel.xy;\n"
				+ "\tvec4 openfl_Dst = texture2D(openfl_DstSampler, openfl_dstUV);\n"
				+ #if openfl_bgfx_show_dst "\tgl_FragColor = openfl_Dst;\n" #else "\tgl_FragColor = openfl_khr_blend(openfl_SrcColor, openfl_Dst);\n" #end
				+ "}\n");
		}
		else
		{
			fs.add(varyingDefines.toString());
			fs.add(result.fragmentUniformCode);
			fs.add(fragmentBody);
		}

		result.fragmentSC = fs.toString();

		return result;
	}

	/**
		KHR_blend_equation_advanced math over premultiplied src/dst: colors
		are un-premultiplied, blended with f(Cs, Cd), and recombined with the
		spec weighting (X = Y = Z = 1 for every supported equation).
	**/
	@:noCompletion private static function __blendLibrary(mode:Int):String
	{
		var f = switch (mode)
		{
			case 0x9294: // MULTIPLY_KHR
				"cs * cd";
			case 0x9295: // SCREEN_KHR
				"cs + cd - cs * cd";
			case 0x9296: // OVERLAY_KHR
				"mix(2.0 * cs * cd, 1.0 - 2.0 * (1.0 - cs) * (1.0 - cd), step(0.5, cd))";
			case 0x9297: // DARKEN_KHR
				"min(cs, cd)";
			case 0x9298: // LIGHTEN_KHR
				"max(cs, cd)";
			case 0x9299: // COLORBURN_KHR
				"openfl_colorburn(cs, cd)";
			case 0x929A: // COLORDODGE_KHR
				"openfl_colordodge(cs, cd)";
			case 0x929B: // HARDLIGHT_KHR
				"mix(2.0 * cs * cd, 1.0 - 2.0 * (1.0 - cs) * (1.0 - cd), step(0.5, cs))";
			case 0x929C: // SOFTLIGHT_KHR
				"openfl_softlight(cs, cd)";
			case 0x929E: // DIFFERENCE_KHR
				"abs(cd - cs)";
			case 0x92A0: // EXCLUSION_KHR
				"cs + cd - 2.0 * cs * cd";
			case 0x92AD: // HSL_HUE_KHR
				"openfl_setlum(openfl_setsat(cs, openfl_sat(cd)), openfl_lum(cd))";
			case 0x92AE: // HSL_SATURATION_KHR
				"openfl_setlum(openfl_setsat(cd, openfl_sat(cs)), openfl_lum(cd))";
			case 0x92AF: // HSL_COLOR_KHR
				"openfl_setlum(cs, openfl_lum(cd))";
			case 0x92B0: // HSL_LUMINOSITY_KHR
				"openfl_setlum(cd, openfl_lum(cs))";
			default:
				"cs";
		}

		return "vec3 openfl_colordodge(vec3 cs, vec3 cd) {\n"
			+ "\tvec3 dodge = min(vec3_splat(1.0), cd / max(1.0 - cs, vec3_splat(0.0001)));\n"
			+ "\treturn mix(dodge, vec3_splat(1.0), step(vec3_splat(1.0), cs)) * step(vec3_splat(0.0001), cd);\n"
			+ "}\n"
			+ "vec3 openfl_colorburn(vec3 cs, vec3 cd) {\n"
			+ "\tvec3 burn = 1.0 - min(vec3_splat(1.0), (1.0 - cd) / max(cs, vec3_splat(0.0001)));\n"
			+ "\tvec3 result = mix(burn, vec3_splat(0.0), step(cs, vec3_splat(0.0001)));\n"
			+ "\treturn mix(result, vec3_splat(1.0), step(vec3_splat(1.0), cd));\n"
			+ "}\n"
			+ "vec3 openfl_softlight(vec3 cs, vec3 cd) {\n"
			+ "\tvec3 d = mix(sqrt(cd), ((16.0 * cd - 12.0) * cd + 4.0) * cd, step(cd, vec3_splat(0.25)));\n"
			+ "\tvec3 low = cd - (1.0 - 2.0 * cs) * cd * (1.0 - cd);\n"
			+ "\tvec3 high = cd + (2.0 * cs - 1.0) * (d - cd);\n"
			+ "\treturn mix(low, high, step(0.5, cs));\n"
			+ "}\n"
			+ "float openfl_lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }\n"
			+ "float openfl_sat(vec3 c) { return max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b); }\n"
			+ "vec3 openfl_clipcolor(vec3 c) {\n"
			+ "\tfloat lum = openfl_lum(c);\n"
			+ "\tfloat mincomp = min(min(c.r, c.g), c.b);\n"
			+ "\tfloat maxcomp = max(max(c.r, c.g), c.b);\n"
			+ "\tif (mincomp < 0.0) c = lum + ((c - lum) * lum) / max(lum - mincomp, 0.0001);\n"
			+ "\tif (maxcomp > 1.0) c = lum + ((c - lum) * (1.0 - lum)) / max(maxcomp - lum, 0.0001);\n"
			+ "\treturn c;\n"
			+ "}\n"
			+ "vec3 openfl_setlum(vec3 c, float lum) { return openfl_clipcolor(c + (lum - openfl_lum(c))); }\n"
			+ "vec3 openfl_setsat(vec3 c, float s) {\n"
			+ "\tfloat mincomp = min(min(c.r, c.g), c.b);\n"
			+ "\tfloat maxcomp = max(max(c.r, c.g), c.b);\n"
			+ "\tvec3 result = (c - mincomp) * s / max(maxcomp - mincomp, 0.0001);\n"
			+ "\treturn (maxcomp > mincomp) ? result : vec3_splat(0.0);\n"
			+ "}\n"
			+ "vec4 openfl_khr_blend(vec4 srcP, vec4 dstP) {\n"
			+ "\tfloat sa = srcP.a;\n"
			+ "\tfloat da = dstP.a;\n"
			+ "\tvec3 cs = srcP.rgb / max(sa, 0.0001);\n"
			+ "\tvec3 cd = dstP.rgb / max(da, 0.0001);\n"
			+ "\tvec3 blended = " + f + ";\n"
			+ "\tvec3 rgb = blended * sa * da + cs * sa * (1.0 - da) + cd * da * (1.0 - sa);\n"
			+ "\tfloat alpha = sa + da - sa * da;\n"
			+ "\treturn vec4(rgb, alpha);\n"
			+ "}\n";
	}

	@:noCompletion private static function __processUniforms(body:String, result:BGFXTranslatedProgram, isVertex:Bool):String
	{
		var uniformRegex = ~/^\s*uniform\s+(?:lowp\s+|mediump\s+|highp\s+)?(\w+)\s+(\w+)\s*(\[\s*(\d+)\s*\])?\s*;/gm;
		var declarations = new StringBuf();

		var stripped = uniformRegex.map(body, function(r)
		{
			var type = r.matched(1);
			var name = r.matched(2);
			var arrayLength = r.matched(3) != null ? Std.parseInt(r.matched(4)) : 0;

			if (StringTools.startsWith(type, "sampler"))
			{
				// stage index = declaration order across the fragment shader
				var stage = result.samplerNames.indexOf(name);

				if (stage == -1)
				{
					stage = result.samplerNames.length;
					result.samplerNames.push(name);
				}

				declarations.add("SAMPLER2D(" + name + ", " + stage + ");\n");
				return "";
			}

			// already registered by the other stage? emit the declaration again
			// (bgfx uniforms are global; both stages may reference the same one)
			var existing = result.uniformNames.indexOf(name);

			if (existing == -1)
			{
				result.uniformNames.push(name);
				result.uniformGLSLTypes.push(type);
				result.uniformArrayLengths.push(arrayLength);
			}

			switch (type)
			{
				case "mat4":
					declarations.add("uniform mat4 " + name + (arrayLength > 0 ? "[" + arrayLength + "]" : "") + ";\n");
				case "mat3":
					declarations.add("uniform mat3 " + name + (arrayLength > 0 ? "[" + arrayLength + "]" : "") + ";\n");
				case "vec4":
					declarations.add("uniform vec4 " + name + (arrayLength > 0 ? "[" + arrayLength + "]" : "") + ";\n");
				default:
					if (arrayLength > 0)
					{
						// packed arrays of non-vec4 types cannot be aliased
						// textually; declare as vec4 array and hope the source
						// indexes .x style (rare — log-worthy if it breaks)
						declarations.add("uniform vec4 " + name + "[" + arrayLength + "];\n");
					}
					else
					{
						// pack scalars/small vectors into a vec4 with an alias
						declarations.add("uniform vec4 " + name + "_ofl4;\n");
						declarations.add("#define " + name + " " + __unpackAlias(type, name + "_ofl4") + "\n");
					}
			}

			return "";
		});

		if (isVertex) result.vertexUniformCode = declarations.toString();
		else result.fragmentUniformCode = declarations.toString();

		return stripped;
	}

	@:noCompletion private static function __unpackAlias(type:String, packed:String):String
	{
		return switch (type)
		{
			case "float", "double": packed + ".x";
			case "vec2", "dvec2": packed + ".xy";
			case "vec3", "dvec3": packed + ".xyz";
			case "int", "uint": "int(" + packed + ".x)";
			case "ivec2", "uvec2": "ivec2(" + packed + ".xy)";
			case "ivec3", "uvec3": "ivec3(" + packed + ".xyz)";
			case "ivec4", "uvec4": "ivec4(" + packed + ")";
			case "bool": "(" + packed + ".x > 0.5)";
			case "bvec2": "bvec2(" + packed + ".x > 0.5, " + packed + ".y > 0.5)";
			case "bvec3": "bvec3(" + packed + ".x > 0.5, " + packed + ".y > 0.5, " + packed + ".z > 0.5)";
			case "bvec4": "bvec4(" + packed + ".x > 0.5, " + packed + ".y > 0.5, " + packed + ".z > 0.5, " + packed + ".w > 0.5)";
			default: packed;
		}
	}

	@:noCompletion private static function __componentCount(type:String):Int
	{
		return switch (type)
		{
			case "float": 1;
			case "vec2": 2;
			case "vec3": 3;
			default: 4;
		}
	}

	@:noCompletion private static function __attribSemanticName(semantic:Int):String
	{
		if (semantic == ATTRIB_POSITION) return "POSITION";
		if (semantic >= ATTRIB_COLOR0 && semantic <= ATTRIB_COLOR3) return "COLOR" + (semantic - ATTRIB_COLOR0);
		return "TEXCOORD" + (semantic - ATTRIB_TEXCOORD0);
	}

	@:noCompletion private static function __varyingSemantic(canonical:String):String
	{
		if (StringTools.startsWith(canonical, "v_color")) return "COLOR" + canonical.substr(7);
		return "TEXCOORD" + canonical.substr(10);
	}

	@:noCompletion private static function __zeroInit(type:String):String
	{
		return switch (type)
		{
			case "float": "0.0";
			case "vec2": "vec2(0.0, 0.0)";
			case "vec3": "vec3(0.0, 0.0, 0.0)";
			default: "vec4(0.0, 0.0, 0.0, 0.0)";
		}
	}

	/**
		Rewrites `name * operand` into `mul(name, operand)`. The operand is an
		identifier chain (with swizzles) or a call/parenthesized expression,
		matched with paren counting.
	**/
	@:noCompletion private static function __rewriteMatrixMul(body:String, name:String):String
	{
		var search = 0;

		while (true)
		{
			var index = body.indexOf(name, search);
			if (index == -1) break;

			// whole-word match
			var before = index > 0 ? body.charCodeAt(index - 1) : 32;
			var afterIndex = index + name.length;
			var after = afterIndex < body.length ? body.charCodeAt(afterIndex) : 32;
			var isWord = function(c:Int) return (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;

			if (isWord(before) || isWord(after))
			{
				search = index + 1;
				continue;
			}

			// require ` * ` next (skipping whitespace)
			var cursor = afterIndex;
			while (cursor < body.length && (body.charCodeAt(cursor) == 32 || body.charCodeAt(cursor) == 9)) cursor++;

			if (cursor >= body.length || body.charAt(cursor) != "*" || (cursor + 1 < body.length && body.charAt(cursor + 1) == "="))
			{
				search = afterIndex;
				continue;
			}

			cursor++;
			while (cursor < body.length && (body.charCodeAt(cursor) == 32 || body.charCodeAt(cursor) == 9)) cursor++;

			// scan the right operand: identifier chain and/or parenthesized group(s)
			var operandStart = cursor;
			var parens = 0;

			while (cursor < body.length)
			{
				var c = body.charCodeAt(cursor);

				if (c == 40 /* ( */) parens++;
				else if (c == 41 /* ) */)
				{
					if (parens == 0) break;
					parens--;
				}
				else if (parens == 0 && !isWord(c) && c != 46 /* . */ && c != 40)
				{
					break;
				}

				cursor++;
			}

			if (cursor == operandStart)
			{
				search = afterIndex;
				continue;
			}

			var operand = body.substring(operandStart, cursor);
			var replacement = "mul(" + name + ", " + operand + ")";
			body = body.substring(0, index) + replacement + body.substring(cursor);
			search = index + replacement.length;
		}

		return body;
	}

	/** local `matN name` declarations (for the mul() rewrite) **/
	@:noCompletion private static function __collectLocalMatrices(body:String):Array<String>
	{
		var names = new Array<String>();
		var regex = ~/\bmat[234]\s+([A-Za-z_]\w*)/g;
		var search = 0;

		while (regex.matchSub(body, search))
		{
			var name = regex.matched(1);
			if (names.indexOf(name) == -1) names.push(name);
			var position = regex.matchedPos();
			search = position.pos + position.len;
		}

		return names;
	}

	/**
		Rewrites single-argument (scalar/diagonal) matrix constructors —
		`matN(x)` becomes `(matN(<identity>) * (x))`, valid in GLSL and HLSL.
	**/
	@:noCompletion private static function __rewriteMatrixCtors(body:String):String
	{
		var regex = ~/\bmat([234])\s*\(/;
		var search = 0;

		while (true)
		{
			if (!regex.matchSub(body, search)) break;

			var position = regex.matchedPos();
			var size = Std.parseInt(regex.matched(1));
			var argsStart = position.pos + position.len;

			// scan the argument list; a top-level comma means a full ctor
			var cursor = argsStart;
			var parens = 1;
			var topLevelComma = false;

			while (cursor < body.length && parens > 0)
			{
				var c = body.charCodeAt(cursor);
				if (c == 40) parens++;
				else if (c == 41) parens--;
				else if (c == 44 && parens == 1) topLevelComma = true;
				cursor++;
			}

			if (topLevelComma || parens != 0)
			{
				search = argsStart;
				continue;
			}

			var arg = body.substring(argsStart, cursor - 1);
			var identity = new StringBuf();

			for (row in 0...size)
			{
				for (column in 0...size)
				{
					if (row != 0 || column != 0) identity.add(", ");
					identity.add(row == column ? "1.0" : "0.0");
				}
			}

			var replacement = "(mat" + size + "(" + identity.toString() + ") * (" + arg + "))";
			body = body.substring(0, position.pos) + replacement + body.substring(cursor);
			search = position.pos + replacement.length;
		}

		return body;
	}

	/**
		Rewrites `operand * name` (vector-times-matrix) into
		`mul(operand, name)`; the left operand is an identifier chain or a
		call/parenthesized group, scanned backwards.
	**/
	@:noCompletion private static function __rewriteMatrixMulRight(body:String, name:String):String
	{
		var search = 0;
		var isWord = function(c:Int) return (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;

		while (true)
		{
			var index = body.indexOf(name, search);
			if (index == -1) break;

			var afterIndex = index + name.length;
			var beforeChar = index > 0 ? body.charCodeAt(index - 1) : 32;
			var afterChar = afterIndex < body.length ? body.charCodeAt(afterIndex) : 32;

			if (isWord(beforeChar) || isWord(afterChar))
			{
				search = index + 1;
				continue;
			}

			// require `* ` immediately before (skipping whitespace)
			var starIndex = index - 1;
			while (starIndex >= 0 && (body.charCodeAt(starIndex) == 32 || body.charCodeAt(starIndex) == 9)) starIndex--;

			if (starIndex < 0 || body.charAt(starIndex) != "*")
			{
				search = afterIndex;
				continue;
			}

			// scan the left operand backwards
			var cursor = starIndex - 1;
			while (cursor >= 0 && (body.charCodeAt(cursor) == 32 || body.charCodeAt(cursor) == 9)) cursor--;

			var operandEnd = cursor + 1;

			if (cursor >= 0 && body.charCodeAt(cursor) == 41 /* ) */)
			{
				var parens = 1;
				cursor--;
				while (cursor >= 0 && parens > 0)
				{
					var c = body.charCodeAt(cursor);
					if (c == 41) parens++;
					else if (c == 40) parens--;
					cursor--;
				}
			}

			while (cursor >= 0 && (isWord(body.charCodeAt(cursor)) || body.charCodeAt(cursor) == 46 /* . */)) cursor--;

			var operandStart = cursor + 1;

			if (operandStart >= operandEnd)
			{
				search = afterIndex;
				continue;
			}

			var operand = body.substring(operandStart, operandEnd);
			var replacement = "mul(" + operand + ", " + name + ")";
			body = body.substring(0, operandStart) + replacement + body.substring(afterIndex);
			search = operandStart + replacement.length;
		}

		return body;
	}

	@:noCompletion private static function __normalizeMain(body:String):String
	{
		// shaderc requires the literal entry point "void main()"
		return ~/void\s+main\s*\(\s*(void)?\s*\)/g.replace(body, "void main()");
	}

	@:noCompletion private static function __stripDirectives(source:String):String
	{
		source = ~/^\s*#version[^\n]*$/gm.replace(source, "");
		source = ~/^\s*#extension[^\n]*$/gm.replace(source, "");
		source = ~/^\s*precision\s+(?:lowp|mediump|highp)\s+\w+\s*;\s*$/gm.replace(source, "");

		// GL_ES precision blocks from Shader.__buildSourcePrefix / Program3D
		// prefix arrive already interleaved with #ifdef GL_ES — fcpp will see
		// GL_ES undefined and drop the guarded lines, so they can stay.
		return source;
	}
}

@SuppressWarnings("checkstyle:FieldDocComment")
class BGFXTranslatedProgram
{
	/** original GLSL attribute names, in declaration order (= attribute index) **/
	public var attribNames:Array<String> = [];

	/** bgfx canonical names (a_position, a_texcoord0, ...) parallel to attribNames **/
	public var attribCanonicalNames:Array<String> = [];

	/** bgfx Attrib enum values parallel to attribNames **/
	public var attribSemantics:Array<Int> = [];

	/** float component count (1-4) parallel to attribNames **/
	public var attribComponents:Array<Int> = [];

	/** GLSL type string parallel to attribNames (for varying.def) **/
	public var attribDefTypes:Array<String> = [];

	/** sampler names in stage order **/
	public var samplerNames:Array<String> = [];

	/** unique uniform names (both stages) **/
	public var uniformNames:Array<String> = [];

	/** original GLSL type per uniform **/
	public var uniformGLSLTypes:Array<String> = [];

	/** 0 = not an array **/
	public var uniformArrayLengths:Array<Int> = [];

	/** texture stage of openfl_DstSampler for complex blend variants (-1 = none) **/
	public var dstSamplerStage:Int = -1;

	public var vertexSC:String;
	public var fragmentSC:String;
	public var varyingDef:String;

	public var vertexUniformCode:String = "";
	public var fragmentUniformCode:String = "";

	public function new() {}
}
