= EDL

== DESCRIPTION:

Work with EDL files from Ruby
http://en.wikipedia.org/wiki/Edit_decision_list 

== SYNOPSIS:

  list = EDL::Parser.new(fps=25).parse(File.open('OFFLINE.EDL'))
  list.events.each do | evt |
    puts evt.inspect
  end
  
== REQUIREMENTS:

* Timecode gem (sudo gem install timecode)

== INSTALL:

* sudo gem install edl

== LICENSE:

(The MIT License)

Copyright (c) 2008 Julik Tarkhanov <me@julik.nl>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
