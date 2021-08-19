#!/usr/bin/ruby

require 'optparse'
require 'date'
require 'socket'
require 'zlib'

# Defaults
g = nil
log = nil
delm = nil
pos = 0
server = "localhost"
port = "2003"
un = "na"
tree = "test.graph.thing"
zip = nil
test = nil

# Arguements
opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: grep2graphite.rb [options]"
  opts.separator ""
  opts.on("-g", "--grep \"String\"", "What you are grepping for.", String) { |val| g = val }
  opts.on("-l", "--log /path/to/log/file", "Log file to grep.", String) { |val| log = val }
  opts.on("-s", "--server graphite.server.or.ip.tld", "Graphite server or ip. (Default: localhost)", String) { |val| server = val }
  opts.on("-p", "--port 2003", "Graphite server port. (Default: 2003)", String) { |val| port = val }
  opts.on("-t", "--tree test.graph.thing", "The path to your graph.", String) { |val| tree = val }
  opts.on("-d", "--delimiter @", "Change the timestamp delimiter. Default: \" \"", String) { |val| delm = val }
  opts.on("-P", "--postion 0", "Change the postion timestamp delimiter. Default: 0", String) { |val| pos = val }
  opts.on("-u", "--until 2", "If the timestamp spans multiple delimeters use --until.", String) { |val| un = val }
  opts.on("-z", "--zip", "Read a compressed file") do
    zip = "true"
  end
  opts.on("-h", "--help", "Usage options.") do
    puts opts
    exit
  end
  opts.on("-T", "--test", "Test mode just prints output.") do
    test = "true"
  end
  begin opts.parse! ARGV
  rescue => e
      puts e
      puts opts
      exit
  end
  opts.parse!
end

# Grep the log
if zip == "true"
  infile = open(log)
  a = Zlib::GzipReader.new(infile).grep(/#{g}/)
else
  a = File.open(log).grep(/#{g}/)
end

# Put the timestamps in an array.
ts = []
a.each { |x|
  if un == "na"
    ts << DateTime.parse(x.split[pos.to_i]).to_time.to_i
  else
    ts << DateTime.parse(x.split[pos.to_i..un.to_i].join(" ")).to_time.to_i
  end
}

# Count the timestamps
res = Hash[ts.group_by {|x| x}.map {|k,v| [k,v.count]}]

# Send the data to graphite
if test == "true"
        puts "Testing Data Output..."
        res.each { |x|
                data = "#{tree} #{x.reverse}".delete! ",\[\]"
                puts data
        }
else
	socket = TCPSocket.open(server, port.to_i)
	puts "Sending Data to graphite server at #{server} on port #{port}"
	res.each { |x|
		data = "#{tree} #{x.reverse}".delete! ",\[\]"
		puts data
		socket.write data
	}
	socket.close
end
puts "Complete!"
