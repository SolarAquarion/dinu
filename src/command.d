module dinu.command;

import
	core.sync.mutex,
	std.conv,
	std.string,
	std.path,
	std.process,
	std.parallelism,
	std.algorithm,
	std.array,
	std.stdio,
	std.file,
	dinu.xclient,
	dinu.dinu,
	draw;


__gshared:


enum Type {

	none =         0,
	script =    1<<0,
	desktop =   1<<1,
	history =   1<<2,
	file =      1<<3,
	directory = 1<<4,
	output =    1<<5

}


class Command {
	abstract int draw(int[2] pos);
	abstract string text();
	abstract string filterText();
	//bool lessenScore();
	abstract size_t score();
	abstract void run(string params);
	Type type;
}


class CommandFile: Command {

	string name;
	FontColor color;

	this(string name){
		this.name = name;
		type = Type.file;
		color = colorFile;
	}

	override string text(){
		return name;
	}

	override string filterText(){
		return name;
	}

	override size_t score(){
		return 0;
	}

	override int draw(int[2] pos){
		return pos.x+dc.text(pos, text, color);
	}

	override void run(string params){
		this.spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}

class CommandDir: CommandFile {

	this(string name){
		super(name);
		type = Type.directory;
		color = colorDir;
	}

	override size_t score(){
		return 2;
	}


}

class CommandExec: CommandFile {

	this(string name){
		super(name);
		type = Type.script;
		color = colorExec;
	}

	override size_t score(){
		return 5;
	}

	override void run(string params){
		this.spawnCommand(name, params);
	}

}

class CommandHistory: CommandDesktop {

	size_t idx;
	long result = long.max;
	string params;

	this(string name, string command, string params, size_t idx){
		super(name, command);
		type = Type.history;
		this.idx = idx;
		this.params = params;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(int[2] pos){
		string hint;
		if(result != long.max){
			if(result)
				hint = `%s`.format(result);
			else
				hint = "";
		}else
			hint = "•";
		dc.text(pos, hint, result&&result!=long.max ? colorError : colorHint, 1.4);
		pos.x += dc.text(pos, text, colorExec);
		return dc.text(pos, ' ' ~ params, colorOutput);
	}

}

class CommandOutput: CommandFile {
	
	size_t idx;
	string command;

	this(string command, string output, size_t idx, bool err){
		super(output.dup); // fucking garbage collector doesn't know its place
		type = Type.output;
		this.command = command;
		this.idx = idx;
		if(err)
			color = colorError;
		else
			color = colorOutput;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(int[2] pos){
		//pos[0] -= 7;
		dc.text(pos, command, colorHint, 1.4);
		return super.draw(pos);
	}

	override void run(string params){
		auto command = new CommandExec("echo");
		command.run("'%s' | xsel -ib".format(
			text.strip.replace("'", "'\\''")
		));
	}

}

class CommandDesktop: CommandFile {

	string exec;

	this(string name, string exec){
		super(name);
		type = Type.desktop;
		this.exec = exec;
		color = colorDesktop;
	}

	override int draw(int[2] pos){
		int r = super.draw(pos);
		dc.text([r+5, pos[1]], exec, colorHint);
		return pos[0];
	}


	override size_t score(){
		return 100;
	}

	override string filterText(){
		return exec ~ name;
	}

	override void run(string params){
		this.spawnCommand(exec.replace("%f", params).replace("%F", params).replace("%u", params).replace("%U", params));
	}

}


void spawnCommand(Command caller, string command, string arguments=""){
	auto dg = {
		try{
			command = (command.strip ~ ' ' ~ arguments).strip;
			writeln("running: \"%s\"".format(command));
			auto userdir = options.configPath.expandTilde;
			auto pipes = pipeShell(command);
			auto pid = pipes.pid.processID;
			log("%s exec \"%s\" \"%s\" \"%s\"".format(pid, caller.text, command, arguments));
			auto reader = task({
				foreach(line; pipes.stdout.byLine){
					if(line.length)
						log("%s stdout %s".format(pid, line));
				}
			});
			reader.executeInNewThread;
			foreach(line; pipes.stderr.byLine){
				if(line.length)
					log("%s stderr %s".format(pid, line));
			}
			reader.yieldForce;
			auto res = pipes.pid.wait;
			log("%s exit %s".format(pid, res));
		}catch(Throwable t)
			writeln(t);
	};
	task(dg).executeInNewThread;
}


Mutex logMutex;

shared static this(){
	logMutex = new Mutex;
}

void log(string text){
	synchronized(logMutex){
		auto path = options.configPath ~ ".log";
		if(path.exists)
			path.append(text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
		writeln(text);
	}
}

