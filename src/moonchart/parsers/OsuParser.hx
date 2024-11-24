package moonchart.parsers;

import moonchart.formats.OsuMania;
import moonchart.parsers.BasicParser;

using StringTools;

// Dumb hashlink fix
typedef OsuFormat =
{
	?format:String,
	?General:OsuGeneral,
	?Editor:OsuEditor,
	?Metadata:OsuMetadata,
	?Difficulty:OsuDifficulty,
	?Events:Array<Array<Dynamic>>,
	?TimingPoints:Array<Array<Float>>,
	?HitObjects:Array<Array<Int>>,
}

typedef OsuGeneral =
{
	AudioFilename:String,
	AudioLeadIn:Int,
	PreviewTime:Int,
	Countdown:Int,
	SampleSet:String,
	StackLeniency:Float,
	Mode:OsuMode,
	LetterboxInBreaks:Int,
	SpecialStyle:Int,
	WidescreenStoryboard:Int
}

typedef OsuEditor =
{
	Bookmarks:Array<Int>,
	DistanceSpacing:Float,
	BeatDivisor:Int,
	GridSize:Int,
	TimelineZoom:Float
}

typedef OsuMetadata =
{
	Title:String,
	TitleUnicode:String,
	Artist:String,
	ArtistUnicode:String,
	Creator:String,
	Version:String,
	Source:String,
	BeatmapID:Int,
	BeatmapSetID:Int
}

typedef OsuDifficulty =
{
	HPDrainRate:Int,
	CircleSize:Int,
	OverallDifficulty:Int,
	ApproachRate:Int,
	SliderMultiplier:Float,
	SliderTickRate:Int,
}

enum abstract OsuMode(Int) from Int to Int
{
	var OSU = 0;
	var TAIKO = 1;
	var CATCH = 2;
	var MANIA = 3;

	public function isInvalid():Bool
	{
		if (this != MANIA)
		{
			var osuMode:String = switch (this)
			{
				case OSU: "osu!";
				case TAIKO: "osu!taiko";
				case CATCH: "osu!catch";
				case _: "[NOT FOUND]";
			}
			throw 'Osu game mode $osuMode is not supported.';
			return true;
		}
		return false;
	}
}

class OsuParser extends BasicParser<OsuFormat>
{
	var buf:StringBuf;

	public override function stringify(data:OsuFormat):String
	{
		buf = new StringBuf();
		buf.add(OsuMania.OSU_FORMAT_VERSION);

		var fields = sortedFields(data, [
			"General",
			"Editor",
			"Metadata",
			"Difficulty",
			"Events",
			"TimingPoints",
			"HitObjects"
		]);

		for (header in fields)
		{
			buf.add('\n[$header]\n');

			var headerData = Reflect.field(data, header);
			if (headerData is Array)
			{
				osuVar(headerData, '\n'.code);
				buf.addChar('\n'.code);
			}
			else
			{
				for (field in Reflect.fields(headerData))
				{
					buf.add(field);
					buf.add(": ");
					osuVar(Reflect.field(headerData, field), ",".code);
					buf.addChar('\n'.code);
				}
			}
		}

		return buf.toString();
	}

	function osuVar(value:Dynamic, arrSep:Int):Void
	{
		// Average osu var
		if (!(value is Array))
		{
			buf.add(value);
			return;
		}

		// Osu array
		var array:Array<Dynamic> = value;
		var len = array.length;
		var last = len - 1;
		for (i in 0...len)
		{
			osuVar(array[i], ",".code);
			if (i < last)
				buf.addChar(arrSep);
		}
	}

	public override function parse(string:String):OsuFormat
	{
		var lines = splitLines(string);

		var data:OsuFormat = {};
		data.format = lines[0]; // First line is always the osu chart format version

		var i = 1;
		while (i < lines.length)
		{
			final line:String = lines[i++];

			// Found osu variable header
			if (line.startsWith("["))
			{
				// Setting up the variable
				final header:String = line.substr(1, line.length - 3);

				// Fuck shit ass fuck
				if (header == "General" || header == "Editor" || header == "Metadata" || header == "Difficulty")
				{
					var headerData:Dynamic = {};
					Reflect.setField(data, header, headerData);

					while (i < lines.length && !lines[i].startsWith("["))
					{
						var content = lines[i++].split(":");
						Reflect.setField(headerData, content[0], resolveBasic(content[1]));
					}
				}
				else
				{
					var headerArray:Array<Dynamic> = [];
					Reflect.setField(data, header, headerArray);

					while (i < lines.length && !lines[i].startsWith("["))
					{
						var line = lines[i++];
						if (line.startsWith("//"))
							continue;

						headerArray.push(resolveBasic(line.split(":")[0]));
					}
				}
			}
		}

		return data;
	}

	override function resolveBasic(value:String):Dynamic
	{
		// Is an array
		if (value.contains(","))
		{
			var array:Array<Dynamic> = [];
			for (i in value.split(","))
				array.push(resolveBasic(i));

			return array;
		}

		return super.resolveBasic(value);
	}
}
