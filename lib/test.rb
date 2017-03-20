# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require "printer"

Printer.log $LOAD_PATH.join(" ")
