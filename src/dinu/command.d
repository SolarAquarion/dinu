module dinu.command;

import
	core.sync.mutex,
	std.conv,
	std.array,
	std.string,
	std.path,
	std.process,
	std.parallelism,
	std.algorithm,
	std.array,
	std.stdio,
	std.datetime,
	std.file,
	std.math,
	std.regex,
	ws.context,
	dinu.util,
	dinu.xclient,
	dinu.dinu,
	dinu.commandBuilder,
	dinu.draw;


__gshared:


enum Type {

	none,
	script,
	desktop,
	history,
	file,
	directory,
	output,
	special,
	bashCompletion,
	processInfo

}


class Command {

	string name;
	Type type;
	string color;
	string parameter;

	protected this(){}

	this(string name){
		this.name = name;
		type = Type.file;
		color = options.colorFile;
	}

	string serialize(){
		return name;
	}

	string text(){
		return name;
	}

	string filterText(){
		return name;
	}

	string hint(){
		return "";
	}

	size_t score(){
		return 0;
	}

	abstract void run();

	int draw(DrawingContext dc, int[2] pos, bool selected){
		int origX = pos.x;
		pos.x += dc.text(pos, text, color);
		pos.x += dc.text(pos, ' ' ~ parameter, options.colorInput);
		return pos.x-origX;
	}

	void spawnCommand(string command, string arguments=""){
		options.configPath.execute(type.to!string, serialize.replace("!", "\\!"), command, arguments.replace("!", "\\!"));
	}

}

