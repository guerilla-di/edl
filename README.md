Work with EDL files from Ruby
http://en.wikipedia.org/wiki/Edit_decision_list 

The library assists in parsing [EDL files](http://en.wikipedia.org/wiki/Edit_decision_list) in CMX 3600 format.
You can use it to generate capture lists, inspect needed video segments for the assembled program
and display edit timelines.  Together with the depix you could write your own "blind"
conform utility in about 10 minutes, no joke.

## Basic usage

```
require 'rubygems'
require 'edl'

list = EDL::Parser.new(fps=25).parse(File.open('OFFLINE.EDL'))
list.events.each do | evt |
 evt.clip_name #=> Boat_Trip_Take1
 evt.capture_from_tc #=> 01:20:22:10
 evt.capture_to_tc #=> 01:20:26:15, accounts for outgoing transition AND M2 timewarps
end
```

## Requirements

* Timecode gem (sudo gem install timecode)

## Currently unsupportedl EDL features:

There is currently no support for:

* drop-frame TC
* audio
* split edits
* key effects

Some reverse/timewarp combinations can produce source dificiencies of 1 frame

## Installation

Add the following to your project `Gemfile`:

```
gem 'edl'
```

## License

See LICENSE.txt
